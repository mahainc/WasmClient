@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Chat

extension WasmActor {

    func chatSend(
        config: WasmClient.Chat.Config,
        messages: [WasmClient.Chat.Message]
    ) async throws -> WasmClient.Chat.Message {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.chat.rawValue,
            preferredProvider: config.providerID.isEmpty ? nil : config.providerID,
            logger: logger
        )

        let bodyData = try Self.buildChatBody(config: config, messages: messages, stream: false)
        let bodyString = String(data: bodyData, encoding: .utf8)!

        let args = Self.chatArgs(bodyString: bodyString, config: config, includeProvider: false)

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

        return Self.parseChatCompletion(data)
    }

    func chatStream(
        config: WasmClient.Chat.Config,
        messages: [WasmClient.Chat.Message]
    ) async throws -> AsyncThrowingStream<String, Swift.Error> {
        logger("chatStream: acquiring engine...")
        let instance = try await readyEngine()
        guard let engine = instance as? TaskWasmEngine else {
            throw WasmClient.Error.engineNotStarted
        }
        logger("chatStream: resolving chat action...")
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.chat.rawValue,
            preferredProvider: config.providerID.isEmpty ? nil : config.providerID,
            logger: logger
        )
        logger("chatStream: action resolved — provider: \(action.provider)")

        let bodyData = try Self.buildChatBody(config: config, messages: messages, stream: true)
        let bodyString = String(data: bodyData, encoding: .utf8)!
        logger("chatStream: body built (\(bodyData.count) bytes), model: \(config.model)")

        let args = Self.chatArgs(bodyString: bodyString, config: config, includeProvider: false)
        let log = logger
        let requestID = UUID().uuidString

        // Chain onto the previous stream so handler install/drain is serialized.
        let previous = streamGate
        let (stream, continuation) = AsyncThrowingStream<String, Swift.Error>.makeStream()

        let streamTask = Task.detached {
            await previous?.value
            if Task.isCancelled {
                continuation.finish()
                return
            }

            let didReceiveChunks = ChunkFlag()
            let lastChunkAt = LastChunkTime()

            AsyncifyWasmInternal.installSSEChunkHandler(for: requestID) { chunk in
                guard let data = chunk.data(using: .utf8),
                    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let choices = json["choices"] as? [[String: Any]]
                else { return }
                lastChunkAt.touch()
                if let finish = choices.first?["finish_reason"] as? String, finish == "stop" {
                    lastChunkAt.markFinished()
                    return
                }
                guard let delta = choices.first?["delta"] as? [String: Any],
                    let content = delta["content"] as? String,
                    !content.isEmpty
                else { return }
                didReceiveChunks.set()
                continuation.yield(content)
            }
            // Tie handler removal to THIS task so the next stream's
            // `await previous?.value` only returns once our handler is gone.
            defer { AsyncifyWasmInternal.removeSSEChunkHandler(for: requestID) }

            log("chatStream: Task started (requestID: \(requestID))...")
            do {
                log("chatStream: calling engine.create(action:args:requestID:)...")
                let task = try await engine.create(action: action, args: args, requestID: requestID)
                log(
                    "chatStream: task returned — status: \(task.status), hasValue: \(task.hasValue), didReceiveChunks: \(didReceiveChunks.value)"
                )

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

                // If no SSE chunks arrived, fall back to the task result
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
                        !choice.message.content.stringValue.isEmpty
                    {
                        continuation.yield(choice.message.content.stringValue)
                    } else if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                        continuation.yield(text)
                    }
                }
                continuation.finish()
                log("chatStream: finished successfully")
            } catch {
                log("chatStream: error — \(error)")
                continuation.finish(throwing: error)
            }
        }

        streamGate = streamTask

        // Cancelling the consumer's stream cancels the detached task; the
        // `defer` then removes this request's SSE handler.
        continuation.onTermination = { _ in
            streamTask.cancel()
        }
        return stream
    }

    private final class ChunkFlag: @unchecked Sendable {
        private let lock = NSLock()
        private var _value = false
        var value: Bool { lock.withLock { _value } }
        func set() { lock.withLock { _value = true } }
    }

    private final class LastChunkTime: @unchecked Sendable {
        private let lock = NSLock()
        private var _value: Date = .distantPast
        private var _finished = false
        var value: Date { lock.withLock { _value } }
        var finished: Bool { lock.withLock { _finished } }
        func touch() { lock.withLock { _value = Date() } }
        func markFinished() { lock.withLock { _finished = true } }
    }

    func chatModels(
        offset: Int,
        limit: Int,
        keyword: String?,
        category: String?
    ) async throws -> (models: [WasmClient.Chat.ModelInfo], total: Int) {
        let instance = try await readyEngine()

        // Resolve listModels action — standalone, not tied to a chat provider.
        // A failure here means the current engine doesn't expose listModels
        // (provider not loaded / capability absent); that is treated as an empty
        // catalog rather than a hard error so callers can degrade gracefully. The
        // failure is logged so a transient/engine fault isn't silently swallowed.
        let listAction: WaTAction
        do {
            listAction = try await delegate.resolveAction(
                actionID: WasmClient.ActionID.listModels.rawValue,
                logger: logger
            )
        } catch {
            logger("chatModels: listModels action unavailable — \(error); returning empty catalog")
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
            !trimmed.isEmpty
        {
            args["keyword"] = Google_Protobuf_Value(stringValue: trimmed)
        }
        if let trimmedCategory = category?.trimmingCharacters(in: .whitespaces),
            !trimmedCategory.isEmpty
        {
            args["category"] = Google_Protobuf_Value(stringValue: trimmedCategory)
        }

        let task = try await instance.create(action: listAction, args: args)
        guard task.status == .completed else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
        guard task.hasValue else {
            throw WasmClient.Error.missingValue
        }
        guard let payload = try? Google_Protobuf_Struct(unpackingAny: task.value) else {
            throw WasmClient.Error.unexpectedResponseFormat
        }

        var models: [WasmClient.Chat.ModelInfo] = []
        if case .listValue(let list)? = payload.fields["data"]?.kind {
            for value in list.values {
                guard case .structValue(let row)? = value.kind else { continue }
                guard let model = Self.mapModelRow(row.fields, providerNames: providerNames) else {
                    continue
                }
                models.append(model)
            }
        }

        let total: Int = {
            if case .numberValue(let t)? = payload.fields["total"]?.kind {
                return Int(t)
            }
            return models.count
        }()

        return (models, total)
    }

    func createChatModel(
        providerID: String,
        input: WasmClient.Chat.CreateModelInput
    ) async throws -> String {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.createModel.rawValue,
            preferredProvider: providerID.isEmpty ? nil : providerID,
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
            args["category"] = .init(
                listValue: .init(
                    values: input.categories.map { .init(stringValue: $0) }
                )
            )
        }
        if !input.gender.isEmpty {
            args["gender"] = .init(stringValue: input.gender)
        }
        if !input.tone.isEmpty {
            args["tone"] = .init(stringValue: input.tone)
        }
        if !input.traits.isEmpty {
            args["traits"] = .init(
                listValue: .init(
                    values: input.traits.map { .init(stringValue: $0) }
                )
            )
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

    func initializeChatProvider(
        providerID: String,
        userName: String
    ) async throws {
        if !providerID.isEmpty, delegate.isProviderInitialized(providerID) {
            return
        }

        let instance = try await readyEngine()

        let allInitActions =
            (try? await delegate.resolveAllActions(
                actionID: WasmClient.ActionID.providerInit.rawValue,
                logger: logger
            )) ?? []

        let actions: [WaTAction]
        if providerID.isEmpty {
            actions = allInitActions
        } else if let exact = allInitActions.first(where: { $0.provider == providerID }) {
            actions = [exact]
        } else {
            delegate.markProviderInitialized(providerID)
            return
        }

        if actions.isEmpty { return }

        let args: [String: Google_Protobuf_Value] = [
            "metadata": .init(
                structValue: .with {
                    $0.fields = [
                        "name": .init(stringValue: userName)
                    ]
                }
            )
        ]

        for action in actions {
            // In fan-out mode, skip providers we've already initialized.
            if providerID.isEmpty, delegate.isProviderInitialized(action.provider) {
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

    // MARK: - Chat Parity (method-name dispatch)

    func completion(
        config: WasmClient.Chat.Config,
        messages: [WasmClient.Chat.Message]
    ) async throws -> WasmClient.Chat.Message {
        let instance = try await readyEngine()

        let bodyData = try Self.buildChatBody(config: config, messages: messages, stream: false)
        let bodyString = String(data: bodyData, encoding: .utf8) ?? "{}"

        let args = Self.chatArgs(bodyString: bodyString, config: config, includeProvider: true)

        let result: TypesBytes = try await instance.run(
            method: WasmClient.Chat.Method.completion.rawValue,
            args: args
        )
        guard case .raw(let data) = result.data else {
            throw WasmClient.Error.unexpectedResponseFormat
        }

        return Self.parseChatCompletion(data)
    }

    func listProviders() async throws -> [WasmClient.Chat.ProviderInfo] {
        let instance = try await readyEngine()
        let resp: OpenAIListProvidersResponse = try await instance.run(
            method: WasmClient.Chat.Method.listProviders.rawValue,
            args: [:]
        )
        return resp.providers.map { p in
            WasmClient.Chat.ProviderInfo(
                id: p.id,
                name: p.name,
                creatable: p.creatable,
                // WasmClient's OpenAIProviderInfo proto does not carry a
                // `voiceCreatable` flag; default false until the mirror gains it.
                voiceCreatable: false
            )
        }
    }

    func authProvider(providerID: String) async throws -> (providerID: String, cacheDir: String) {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !providerID.isEmpty {
            args["provider_id"] = Google_Protobuf_Value(stringValue: providerID)
        }
        let resp: OpenAIAuthResponse = try await instance.run(
            method: WasmClient.Chat.Method.auth.rawValue,
            args: args
        )
        let fields = resp.hasCredentials ? resp.credentials.fields : [:]
        let resolvedProvider = fields["provider_id"]?.stringValue ?? providerID
        let cacheDir = fields["cache_dir"]?.stringValue ?? ""
        return (resolvedProvider, cacheDir)
    }

    func listVoices(
        providerID: String,
        keyword: String,
        offset: Int,
        limit: Int
    ) async throws -> WasmClient.Chat.VoiceList {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [
            "offset": Google_Protobuf_Value(numberValue: Double(offset)),
            "limit": Google_Protobuf_Value(numberValue: Double(limit)),
        ]
        if !providerID.isEmpty {
            args["provider_id"] = Google_Protobuf_Value(stringValue: providerID)
        }
        if !keyword.isEmpty {
            args["keyword"] = Google_Protobuf_Value(stringValue: keyword)
        }
        let resp: OpenAIListVoicesResponse = try await instance.run(
            method: WasmClient.Chat.Method.listVoices.rawValue,
            args: args
        )
        return WasmClient.Chat.VoiceList(
            voices: resp.voices.map(Self.mapVoice),
            total: Int(resp.total)
        )
    }

    func createVoice(
        providerID: String,
        name: String,
        audio: String,
        gender: WasmClient.Chat.VoiceGender,
        visibility: WasmClient.Chat.VoiceVisibility
    ) async throws -> WasmClient.Chat.VoiceInfo {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !providerID.isEmpty {
            args["provider_id"] = Google_Protobuf_Value(stringValue: providerID)
        }
        if !name.isEmpty {
            args["name"] = Google_Protobuf_Value(stringValue: name)
        }
        if !audio.isEmpty {
            args["audio"] = Google_Protobuf_Value(stringValue: audio)
        }
        if !gender.rawValue.isEmpty {
            args["gender"] = Google_Protobuf_Value(stringValue: gender.rawValue)
        }
        if !visibility.rawValue.isEmpty {
            args["visibility"] = Google_Protobuf_Value(stringValue: visibility.rawValue)
        }
        let resp: OpenAICreateVoiceResponse = try await instance.run(
            method: WasmClient.Chat.Method.createVoice.rawValue,
            args: args
        )
        return Self.mapVoice(resp.voice)
    }

    func deleteVoice(
        providerID: String,
        voiceID: String
    ) async throws {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [
            "id": Google_Protobuf_Value(stringValue: voiceID)
        ]
        if !providerID.isEmpty {
            args["provider_id"] = Google_Protobuf_Value(stringValue: providerID)
        }
        let _: OpenAIDeleteVoiceResponse = try await instance.run(
            method: WasmClient.Chat.Method.deleteVoice.rawValue,
            args: args
        )
    }

    private static func mapModelRow(
        _ fields: [String: Google_Protobuf_Value],
        providerNames: [String: String]
    ) -> WasmClient.Chat.ModelInfo? {
        guard case .stringValue(let modelID)? = fields["id"]?.kind, !modelID.isEmpty else {
            return nil
        }
        let rawName = fields.string("name")
        let name = rawName.isEmpty ? modelID : rawName
        let ownedBy = fields.string("owned_by")
        let meta = fields.fields("metadata")
        let providerID = meta.string("provider_id")

        return WasmClient.Chat.ModelInfo(
            modelID: modelID,
            name: name,
            ownedBy: ownedBy,
            isPro: meta.bool("is_pro"),
            vision: meta.bool("vision"),
            voices: meta.stringList("voices"),
            greetings: meta.stringList("greetings"),
            image: meta.string("image"),
            interactions: meta.int("interactions"),
            description: meta.string("description"),
            tags: meta.stringList("tags"),
            providerID: providerID,
            providerName: providerNames[providerID] ?? ""
        )
    }

    // MARK: - Private Chat Helpers

    private static func buildChatBody(
        config: WasmClient.Chat.Config,
        messages: [WasmClient.Chat.Message],
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
                    [
                        "id": tc.id, "type": tc.type,
                        "function": [
                            "name": tc.functionName,
                            "arguments": tc.functionArguments,
                        ],
                    ]
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

    private static func mapVoice(_ proto: OpenAIVoiceInfo) -> WasmClient.Chat.VoiceInfo {
        let gender: WasmClient.Chat.VoiceGender
        switch proto.gender {
            case .male: gender = .male
            case .female: gender = .female
            case .neutral: gender = .neutral
            case .unspecified, .UNRECOGNIZED: gender = .unspecified
        }
        let visibility: WasmClient.Chat.VoiceVisibility
        switch proto.visibility {
            case .public: visibility = .publicVisibility
            case .private: visibility = .privateVisibility
            case .unspecified, .UNRECOGNIZED: visibility = .unspecified
        }
        return WasmClient.Chat.VoiceInfo(
            id: proto.id,
            name: proto.name,
            gender: gender,
            visibility: visibility,
            previewAudioURL: proto.hasPreviewAudioURL ? proto.previewAudioURL : "",
            previewText: proto.previewText,
            providerID: proto.providerID,
            creatorID: proto.creatorID
        )
    }

    private static func mapMessage(_ proto: OpenAIChatMessage) -> WasmClient.Chat.Message {
        WasmClient.Chat.Message(
            role: WasmClient.Chat.Role(rawValue: proto.role) ?? .assistant,
            content: proto.content.stringValue,
            toolCalls: proto.toolCalls.map { tc in
                WasmClient.Chat.ToolCall(
                    id: tc.id,
                    type: tc.type,
                    functionName: tc.function.name,
                    functionArguments: tc.function.arguments
                )
            },
            toolCallID: proto.toolCallID,
            annotations: proto.annotations.map { ann in
                WasmClient.Chat.Annotation(
                    type: ann.type,
                    url: ann.hasURLCitation ? ann.urlCitation.url : "",
                    title: ann.hasURLCitation ? ann.urlCitation.title : "",
                    startIndex: ann.hasURLCitation ? Int(ann.urlCitation.startIndex) : 0,
                    endIndex: ann.hasURLCitation ? Int(ann.urlCitation.endIndex) : 0
                )
            },
            refusal: proto.hasRefusal ? proto.refusal : ""
        )
    }

    /// Builds the shared chat request args (`body`, plus optional `url`/`api_key`
    /// and — for method-name dispatch — `provider_id`). Single source for the three
    /// call sites that previously repeated this shape (`chatSend`, `chatStream`,
    /// `completion`).
    private static func chatArgs(
        bodyString: String,
        config: WasmClient.Chat.Config,
        includeProvider: Bool
    ) -> [String: Google_Protobuf_Value] {
        var args: [String: Google_Protobuf_Value] = [
            "body": Google_Protobuf_Value(stringValue: bodyString)
        ]
        if !config.endpoint.isEmpty {
            args["url"] = Google_Protobuf_Value(stringValue: config.endpoint)
        }
        if !config.apiKey.isEmpty {
            args["api_key"] = Google_Protobuf_Value(stringValue: config.apiKey)
        }
        if includeProvider, !config.providerID.isEmpty {
            args["provider_id"] = Google_Protobuf_Value(stringValue: config.providerID)
        }
        return args
    }

    /// Parses a chat response: a full `OpenAIChatCompletion` when decodable,
    /// otherwise the raw payload as assistant text. Single source for the tail
    /// shared by `chatSend` and `completion`.
    private static func parseChatCompletion(_ data: Data) -> WasmClient.Chat.Message {
        var opts = JSONDecodingOptions()
        opts.ignoreUnknownFields = true
        if let completion = try? OpenAIChatCompletion(jsonUTF8Data: data, options: opts),
            let choice = completion.choices.first
        {
            return mapMessage(choice.message)
        }
        let text = String(data: data, encoding: .utf8) ?? ""
        return WasmClient.Chat.Message(role: .assistant, content: text)
    }
}

// MARK: - Protobuf field accessors

/// Typed reads over a `[String: Google_Protobuf_Value]` field bag. These replace the
/// ~13 immediately-invoked `{ if case .X(let y)? = fields[k]?.kind … }` closures that
/// `mapModelRow` previously repeated inline (G5).
extension [String: Google_Protobuf_Value] {
    fileprivate func string(
        _ key: String,
        default fallback: String = ""
    ) -> String {
        if case .stringValue(let value)? = self[key]?.kind { return value }
        return fallback
    }

    fileprivate func bool(
        _ key: String,
        default fallback: Bool = false
    ) -> Bool {
        if case .boolValue(let value)? = self[key]?.kind { return value }
        return fallback
    }

    fileprivate func int(
        _ key: String,
        default fallback: Int = 0
    ) -> Int {
        if case .numberValue(let value)? = self[key]?.kind { return Int(value) }
        return fallback
    }

    fileprivate func stringList(_ key: String) -> [String] {
        guard case .listValue(let list)? = self[key]?.kind else { return [] }
        return list.values.compactMap { element in
            if case .stringValue(let value) = element.kind { return value }
            return nil
        }
    }

    fileprivate func fields(_ key: String) -> [String: Google_Protobuf_Value] {
        if case .structValue(let structValue)? = self[key]?.kind { return structValue.fields }
        return [:]
    }
}
