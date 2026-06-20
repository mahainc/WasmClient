@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Chat

extension WasmActor {

    /// Send a chat message and return the full response.
    func chatSend(
        config: WasmClient.ChatConfig,
        messages: [WasmClient.ChatMessage]
    ) async throws -> WasmClient.ChatMessage {
        await chatStreamGate.prepareForStream(
            recoverEngine: makeRecoverInterruptedChatEngine(),
            log: logger
        )
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.chat.rawValue,
            preferredProvider: config.providerId.isEmpty ? nil : config.providerId,
            logger: logger
        )

        let bodyData = try Self.buildChatBody(config: config, messages: messages, stream: false)
        let bodyString = String(data: bodyData, encoding: .utf8)!

        var args: [String: Google_Protobuf_Value] = [
            "body": Google_Protobuf_Value(stringValue: bodyString),
        ]
        if !config.endpoint.isEmpty {
            args["url"] = Google_Protobuf_Value(stringValue: config.endpoint)
        }
        if !config.apiKey.isEmpty {
            args["api_key"] = Google_Protobuf_Value(stringValue: config.apiKey)
        }

        let task = try await instance.create(action: action, args: args)

        guard task.status == .completed else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
        guard task.hasValue else {
            throw WasmClient.Error.missingValue
        }

        let result = try TypesBytes(unpackingAny: task.value)
        guard case .raw(let data) = result.data else {
            throw WasmClient.Error.unexpectedResponseFormat
        }

        // Try full ChatCompletion parse, fall back to plain text
        var opts = JSONDecodingOptions()
        opts.ignoreUnknownFields = true
        if let completion = try? OpenAIChatCompletion(jsonUTF8Data: data, options: opts),
           let choice = completion.choices.first {
            return Self.mapMessage(choice.message)
        }

        let text = String(data: data, encoding: .utf8) ?? ""
        return WasmClient.ChatMessage(role: .assistant, content: text)
    }

    /// Stream a chat response, yielding content deltas as they arrive via SSE.
    ///
    /// Per-request routing: each call mints a `requestID` and registers a handler
    /// via `AsyncifyWasmInternal.installSSEChunkHandler(for:)`. FlowKit tags every
    /// SSE chunk with its originating requestID on backends that support it.
    ///
    /// Chat streams are also serialized through `ChatStreamGate`: a new call waits
    /// for the previous stream to tear down and for an active quarantine window
    /// (discard handler + real SSE quiet time) so stale WS frames cannot paint
    /// the next consumer after a mid-stream dismiss.
    func chatStream(
        config: WasmClient.ChatConfig,
        messages: [WasmClient.ChatMessage]
    ) async throws -> AsyncThrowingStream<String, Swift.Error> {
        await chatStreamGate.prepareForStream(
            recoverEngine: makeRecoverInterruptedChatEngine(),
            log: logger
        )
        logger("chatStream: acquiring engine...")
        let instance = try await readyEngine()
        guard let engine = instance as? TaskWasmEngine else {
            throw WasmClient.Error.engineNotStarted
        }
        logger("chatStream: resolving chat action...")
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.chat.rawValue,
            preferredProvider: config.providerId.isEmpty ? nil : config.providerId,
            logger: logger
        )
        logger("chatStream: action resolved — provider: \(action.provider)")

        let bodyData = try Self.buildChatBody(config: config, messages: messages, stream: true)
        let bodyString = String(data: bodyData, encoding: .utf8)!
        logger("chatStream: body built (\(bodyData.count) bytes), model: \(config.model)")

        var streamArgs: [String: Google_Protobuf_Value] = [
            "body": Google_Protobuf_Value(stringValue: bodyString),
        ]
        if !config.endpoint.isEmpty {
            streamArgs["url"] = Google_Protobuf_Value(stringValue: config.endpoint)
        }
        if !config.apiKey.isEmpty {
            streamArgs["api_key"] = Google_Protobuf_Value(stringValue: config.apiKey)
        }
        let args = streamArgs
        let log = logger
        let gate = chatStreamGate
        let recoverEngine = makeRecoverInterruptedChatEngine()
        let requestID = UUID().uuidString

        return AsyncThrowingStream { continuation in
            let didReceiveChunks = ChunkFlag()
            let lastChunkAt = LastChunkTime()
            let taskHolder = StreamTaskHolder()

            let teardown: @Sendable () -> Void = {
                taskHolder.cancel()
            }

            AsyncifyWasmInternal.installSSEChunkHandler(for: requestID) { chunk in
                guard let data = chunk.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]] else { return }
                lastChunkAt.touch()
                if let finish = choices.first?["finish_reason"] as? String, finish == "stop" {
                    lastChunkAt.markFinished()
                    return
                }
                guard let delta = choices.first?["delta"] as? [String: Any],
                      let content = delta["content"] as? String,
                      !content.isEmpty else { return }
                didReceiveChunks.set()
                continuation.yield(content)
            }

            let streamTask = Task.detached {
                log("chatStream: Task started (requestID: \(requestID))...")
                defer {
                    gate.clearActive(requestID: requestID)
                }
                do {
                    log("chatStream: calling engine.create(action:args:requestID:)...")
                    let task = try await engine.create(action: action, args: args, requestID: requestID)
                    log("chatStream: task returned — status: \(task.status), hasValue: \(task.hasValue), didReceiveChunks: \(didReceiveChunks.value)")

                    if task.status != .completed {
                        let deadline = Date().addingTimeInterval(60)
                        let quietWindow: TimeInterval = 2.5
                        log("chatStream: entering WS-stream wait (60s deadline, 2.5s quiet window)")
                        while Date() < deadline {
                            try await Task.sleep(nanoseconds: 200_000_000)
                            if lastChunkAt.finished {
                                log("chatStream: saw finish_reason:'stop', exiting wait")
                                break
                            }
                            if !didReceiveChunks.value { continue }
                            if Date().timeIntervalSince(lastChunkAt.value) >= quietWindow {
                                log("chatStream: quiet window elapsed, exiting wait")
                                break
                            }
                        }
                    }

                    if !didReceiveChunks.value,
                       task.status == .completed,
                       task.hasValue,
                       let result = try? TypesBytes(unpackingAny: task.value),
                       case .raw(let data) = result.data
                    {
                        log("chatStream: no SSE chunks, falling back to task result (\(data.count) bytes)")
                        var opts = JSONDecodingOptions()
                        opts.ignoreUnknownFields = true
                        if let completion = try? OpenAIChatCompletion(jsonUTF8Data: data, options: opts),
                           let choice = completion.choices.first,
                           !choice.message.content.isEmpty
                        {
                            continuation.yield(choice.message.content)
                        } else if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                            continuation.yield(text)
                        }
                    }
                    AsyncifyWasmInternal.removeSSEChunkHandler(for: requestID)
                    continuation.finish()
                    log("chatStream: finished successfully")
                } catch is CancellationError {
                    // Handler removal is owned by `ChatStreamGate` quarantine on
                    // the same requestID — stale native frames must not land on
                    // the next consumer's handler.
                    log("chatStream: error — CancellationError()")
                    continuation.finish(throwing: CancellationError())
                } catch {
                    AsyncifyWasmInternal.removeSSEChunkHandler(for: requestID)
                    log("chatStream: error — \(error)")
                    continuation.finish(throwing: error)
                }
            }
            taskHolder.store(streamTask)
            gate.register(requestID: requestID, teardown: teardown, task: streamTask)

            continuation.onTermination = { termination in
                switch termination {
                case .cancelled:
                    gate.streamCancelled(
                        requestID: requestID,
                        cancelTask: teardown,
                        recoverEngine: recoverEngine,
                        log: log
                    )
                case .finished:
                    gate.clearActive(requestID: requestID)
                @unknown default:
                    break
                }
            }
        }
    }

    // MARK: - Interrupted chat recovery

    /// Hard-resets the live `TaskWasmEngine` after a mid-stream dismiss. Swift
    /// cancellation alone does not stop the provider's WS task; stale frames can
    /// keep flowing for minutes (see quarantine timeout logs). FlowKit exposes
    /// `TaskWasmEngine.reset()` for this — distinct from `WasmDelegate.resetEngine()`
    /// which only drops the Swift reference without calling into native.
    private func makeRecoverInterruptedChatEngine() -> @Sendable () async -> Void {
        { await self.recoverEngineAfterInterruptedChat(delegate: self.delegate, log: self.logger) }
    }

    private func recoverEngineAfterInterruptedChat(
        delegate: WasmDelegate,
        log: @escaping @Sendable (String) -> Void
    ) async {
        guard let engine = delegate.engine as? TaskWasmEngine else {
            log("chatStream recover: no TaskWasmEngine instance — skipping")
            return
        }
        do {
            log("chatStream recover: calling TaskWasmEngine.reset()...")
            delegate.prepareForInPlaceReset()
            try await engine.reset()
            try await engine.start()
            log("chatStream recover: TaskWasmEngine reset + start complete")
        } catch {
            log("chatStream recover: reset failed (\(error)) — rebuilding engine")
            delegate.resetEngine()
            do {
                _ = try await readyEngine()
                log("chatStream recover: engine rebuilt via readyEngine()")
            } catch {
                log("chatStream recover: readyEngine() failed — \(error)")
            }
        }
    }

    /// Holds the detached stream task so `teardown` can cancel it before the
    /// task variable is assigned (gate may tear down synchronously on the next
    /// `prepareForStream`).
    private final class StreamTaskHolder: @unchecked Sendable {
        private let lock = NSLock()
        private var task: Task<Void, Never>?

        func store(_ task: Task<Void, Never>) {
            lock.withLock { self.task = task }
        }

        func cancel() {
            lock.withLock {
                task?.cancel()
                task = nil
            }
        }
    }

    /// Thread-safe one-shot flag the SSE handler sets when the first chunk
    /// arrives. The detached Task reads `.value` after `create()` resolves to
    /// decide whether to fall back to the task's full value payload.
    private final class ChunkFlag: @unchecked Sendable {
        private let lock = NSLock()
        private var _value = false
        var value: Bool { lock.withLock { _value } }
        func set() { lock.withLock { _value = true } }
    }

    /// Thread-safe tracker for the last SSE frame timestamp and the
    /// `finish_reason:"stop"` signal. Used by the post-`create()` wait loop
    /// to short-circuit on WS-streaming providers that resolve early.
    private final class LastChunkTime: @unchecked Sendable {
        private let lock = NSLock()
        private var _value: Date = .distantPast
        private var _finished = false
        var value: Date { lock.withLock { _value } }
        var finished: Bool { lock.withLock { _finished } }
        func touch() { lock.withLock { _value = Date() } }
        func markFinished() { lock.withLock { _finished = true } }
    }

    /// Fetch chat models via the standalone `listModels` action with
    /// `offset` / `limit` / optional `keyword` / optional `category`.
    /// Each model row is stamped with its source provider (resolved from
    /// the row's `metadata.provider_id` against the registered chat
    /// providers).
    func chatModels(
        offset: Int,
        limit: Int,
        keyword: String?,
        category: String?
    ) async throws -> (models: [WasmClient.ChatModelInfo], total: Int) {
        let instance = try await readyEngine()

        // Resolve listModels action — standalone, not tied to a chat provider.
        let listAction: WaTAction
        do {
            listAction = try await delegate.resolveAction(
                actionID: WasmClient.ActionID.listModels.rawValue,
                logger: logger
            )
        } catch {
            return ([], 0)
        }

        // Build a map from ciphered chat-provider id → display name so each
        // model row can be stamped with the human-readable provider name.
        var providerNames: [String: String] = [:]
        if let chatActions = try? await delegate.resolveAllActions(
            actionID: WasmClient.ActionID.chat.rawValue,
            logger: logger
        ) {
            for action in chatActions {
                let name = action.metadata.fields["provider_name"]?.stringValue ?? ""
                providerNames[action.provider] = name
            }
        }

        var args: [String: Google_Protobuf_Value] = [
            "offset": Google_Protobuf_Value(numberValue: Double(offset)),
            "limit": Google_Protobuf_Value(numberValue: Double(limit)),
        ]
        if let trimmed = keyword?.trimmingCharacters(in: .whitespaces),
           !trimmed.isEmpty {
            args["keyword"] = Google_Protobuf_Value(stringValue: trimmed)
        }
        if let trimmedCategory = category?.trimmingCharacters(in: .whitespaces),
           !trimmedCategory.isEmpty {
            args["category"] = Google_Protobuf_Value(stringValue: trimmedCategory)
        }

        let task = try await instance.create(action: listAction, args: args)
        guard task.status == .completed else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
        guard task.hasValue else {
            throw WasmClient.Error.missingValue
        }
        // FlowKit returns a typed `TypesListModels` message (data: [TypesModelInfo]),
        // not a generic Struct. Each row's scalar fields are typed; the `metadata`
        // field is a Struct carrying is_pro / vision / voices / etc.
        let list = try TypesListModels(unpackingAny: task.value)

        var models: [WasmClient.ChatModelInfo] = []
        for row in list.data {
            var rowFields: [String: Google_Protobuf_Value] = [
                "id": .init(stringValue: row.id),
                "name": .init(stringValue: row.name),
                "owned_by": .init(stringValue: row.ownedBy),
            ]
            if row.hasMetadata {
                rowFields["metadata"] = .init(structValue: row.metadata)
            }
            guard let model = Self.mapModelRow(rowFields, providerNames: providerNames) else {
                continue
            }
            models.append(model)
        }

        let total = list.total > 0 ? Int(list.total) : models.count
        return (models, total)
    }

    /// Create a custom chat model (persona) on a specific provider.
    /// Returns the provider-assigned model id, used as the `modelId`
    /// for subsequent `chatSend`/`chatStream` calls.
    func createChatModel(
        providerId: String,
        input: WasmClient.CreateChatModelInput
    ) async throws -> String {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.createModel.rawValue,
            preferredProvider: providerId.isEmpty ? nil : providerId,
            logger: logger
        )

        var args: [String: Google_Protobuf_Value] = [
            "name": .init(stringValue: input.name),
            "title": .init(stringValue: input.title),
            "description": .init(stringValue: input.description),
            "greeting": .init(stringValue: input.greeting),
            "visibility": .init(stringValue: input.visibility),
        ]
        if !input.image.isEmpty {
            args["image"] = .init(stringValue: input.image)
        }
        if !input.categories.isEmpty {
            args["category"] = .init(listValue: .init(
                values: input.categories.map { .init(stringValue: $0) }
            ))
        }
        if !input.gender.isEmpty {
            args["gender"] = .init(stringValue: input.gender)
        }
        if !input.tone.isEmpty {
            args["tone"] = .init(stringValue: input.tone)
        }
        if !input.traits.isEmpty {
            args["traits"] = .init(listValue: .init(
                values: input.traits.map { .init(stringValue: $0) }
            ))
        }

        let task = try await instance.create(action: action, args: args)
        guard task.status == .completed else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
        guard task.hasValue else {
            throw WasmClient.Error.missingValue
        }
        guard let payload = try? Google_Protobuf_Struct(unpackingAny: task.value) else {
            throw WasmClient.Error.unexpectedResponseFormat
        }
        if case .stringValue(let id)? = payload.fields["id"]?.kind, !id.isEmpty {
            return id
        }
        throw WasmClient.Error.missingValue
    }

    /// Pre-flight init for chat providers — invokes the `providerInit`
    /// action with `metadata: { name: <userName> }`. CAI uses this to
    /// register the user; default providers no-op. When `providerId` is
    /// empty the call fans out across every provider that exposes
    /// providerInit. Failures per provider are swallowed (best-effort)
    /// so a single unreachable provider can't block downstream work.
    func initializeChatProvider(
        providerId: String,
        userName: String
    ) async throws {
        // Skip work when this specific provider has already been initialized
        // in this engine session — mirrors flow-kit-example's
        // `initializedProviders` short-circuit. Fan-out (`providerId == ""`)
        // intentionally re-checks each resolved provider individually below.
        if !providerId.isEmpty, delegate.isProviderInitialized(providerId) {
            return
        }

        let instance = try await readyEngine()

        // Resolve every provider that exposes providerInit. We deliberately
        // avoid `delegate.resolveAction(preferredProvider:)`'s `actions[0]`
        // fallback here: registering the user on the wrong provider (because
        // the requested one happens not to expose providerInit) silently
        // pollutes the wrong account. flow-kit-example uses exact match.
        let allInitActions = (try? await delegate.resolveAllActions(
            actionID: WasmClient.ActionID.providerInit.rawValue,
            logger: logger
        )) ?? []

        let actions: [WaTAction]
        if providerId.isEmpty {
            actions = allInitActions
        } else if let exact = allInitActions.first(where: { $0.provider == providerId }) {
            actions = [exact]
        } else {
            // Provider doesn't expose providerInit — treat as a no-op success
            // and mark it so future calls (and `readOutLoud` auto-init)
            // short-circuit. Matches flow-kit-example's `else { ...
            // initializedProviders.insert(provider.id); return }` branch.
            delegate.markProviderInitialized(providerId)
            return
        }

        if actions.isEmpty { return }

        let args: [String: Google_Protobuf_Value] = [
            "metadata": .init(structValue: .with {
                $0.fields = [
                    "name": .init(stringValue: userName),
                ]
            }),
        ]

        for action in actions {
            // In fan-out mode, skip providers we've already initialized.
            if providerId.isEmpty, delegate.isProviderInitialized(action.provider) {
                continue
            }
            do {
                _ = try await instance.create(action: action, args: args)
                delegate.markProviderInitialized(action.provider)
            } catch {
                // Best-effort per provider — mark anyway so we don't retry-loop
                // (matches flow-kit-example's catch path that inserts on failure).
                delegate.markProviderInitialized(action.provider)
                continue
            }
        }
    }

    private static func mapModelRow(
        _ fields: [String: Google_Protobuf_Value],
        providerNames: [String: String]
    ) -> WasmClient.ChatModelInfo? {
        guard case .stringValue(let modelId)? = fields["id"]?.kind, !modelId.isEmpty else {
            return nil
        }
        let name: String = {
            if case .stringValue(let n)? = fields["name"]?.kind, !n.isEmpty { return n }
            return modelId
        }()
        let ownedBy: String = {
            if case .stringValue(let s)? = fields["owned_by"]?.kind { return s }
            return ""
        }()
        let meta: [String: Google_Protobuf_Value] = {
            if case .structValue(let s)? = fields["metadata"]?.kind { return s.fields }
            return [:]
        }()
        let isPro: Bool = {
            if case .boolValue(let b)? = meta["is_pro"]?.kind { return b }
            return false
        }()
        let vision: Bool = {
            if case .boolValue(let b)? = meta["vision"]?.kind { return b }
            return false
        }()
        let voices: [String] = {
            guard case .listValue(let l)? = meta["voices"]?.kind else { return [] }
            return l.values.compactMap { v in
                if case .stringValue(let s) = v.kind { return s }
                return nil
            }
        }()
        let greetings: [String] = {
            guard case .listValue(let l)? = meta["greetings"]?.kind else { return [] }
            return l.values.compactMap { v in
                if case .stringValue(let s) = v.kind { return s }
                return nil
            }
        }()
        let image: String = {
            if case .stringValue(let s)? = meta["image"]?.kind { return s }
            return ""
        }()
        let interactions: Int = {
            if case .numberValue(let n)? = meta["interactions"]?.kind { return Int(n) }
            return 0
        }()
        let description: String = {
            if case .stringValue(let s)? = meta["description"]?.kind { return s }
            return ""
        }()
        let tags: [String] = {
            guard case .listValue(let l)? = meta["tags"]?.kind else { return [] }
            return l.values.compactMap {
                if case .stringValue(let s) = $0.kind { return s }
                return nil
            }
        }()
        let providerId: String = {
            if case .stringValue(let s)? = meta["provider_id"]?.kind { return s }
            return ""
        }()
        let providerName = providerNames[providerId] ?? ""

        return WasmClient.ChatModelInfo(
            modelId: modelId,
            name: name,
            ownedBy: ownedBy,
            isPro: isPro,
            vision: vision,
            voices: voices,
            greetings: greetings,
            image: image,
            interactions: interactions,
            description: description,
            tags: tags,
            providerId: providerId,
            providerName: providerName
        )
    }

    // MARK: - Private Chat Helpers

    private static func buildChatBody(
        config: WasmClient.ChatConfig,
        messages: [WasmClient.ChatMessage],
        stream: Bool
    ) throws -> Data {
        var body: [String: Any] = [
            "model": config.model,
            "stream": stream,
        ]

        var allMessages: [[String: Any]] = []

        if !config.systemPrompt.isEmpty {
            allMessages.append(["role": "system", "content": config.systemPrompt])
        }

        for msg in messages {
            var dict: [String: Any] = ["role": msg.role.rawValue]
            if !msg.contentParts.isEmpty {
                dict["content"] = msg.contentParts.map { part -> [String: Any] in
                    var p: [String: Any] = ["type": part.type]
                    if !part.text.isEmpty { p["text"] = part.text }
                    if !part.imageURL.isEmpty {
                        var img: [String: Any] = ["url": part.imageURL]
                        if !part.imageDetail.isEmpty { img["detail"] = part.imageDetail }
                        p["image_url"] = img
                    }
                    return p
                }
            } else {
                dict["content"] = msg.content
            }
            if !msg.toolCalls.isEmpty {
                dict["tool_calls"] = msg.toolCalls.map { tc -> [String: Any] in
                    ["id": tc.id, "type": tc.type, "function": [
                        "name": tc.functionName,
                        "arguments": tc.functionArguments,
                    ]]
                }
            }
            if !msg.toolCallID.isEmpty {
                dict["tool_call_id"] = msg.toolCallID
            }
            allMessages.append(dict)
        }

        body["messages"] = allMessages

        if !config.tools.isEmpty {
            body["tools"] = config.tools.map { tool -> [String: Any] in
                var fn: [String: Any] = ["name": tool.functionName]
                if !tool.functionDescription.isEmpty { fn["description"] = tool.functionDescription }
                if let params = try? JSONSerialization.jsonObject(
                    with: Data(tool.parametersJSON.utf8)
                ) {
                    fn["parameters"] = params
                }
                if tool.strict { fn["strict"] = true }
                return ["type": tool.type, "function": fn]
            }
        }

        return try JSONSerialization.data(withJSONObject: body)
    }

    private static func mapMessage(_ proto: OpenAIChatMessage) -> WasmClient.ChatMessage {
        WasmClient.ChatMessage(
            role: WasmClient.ChatRole(rawValue: proto.role) ?? .assistant,
            content: proto.content,
            toolCalls: proto.toolCalls.map { tc in
                WasmClient.ToolCall(
                    id: tc.id,
                    type: tc.type,
                    functionName: tc.function.name,
                    functionArguments: tc.function.arguments
                )
            },
            toolCallID: proto.toolCallID,
            annotations: proto.annotations.map { ann in
                WasmClient.Annotation(
                    type: ann.type,
                    url: ann.hasURLCitation ? ann.urlCitation.url : "",
                    title: ann.hasURLCitation ? ann.urlCitation.title : "",
                    startIndex: ann.hasURLCitation ? Int(ann.urlCitation.startIndex) : 0,
                    endIndex: ann.hasURLCitation ? Int(ann.urlCitation.endIndex) : 0
                )
            }
        )
    }
}
