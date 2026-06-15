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
    /// SSE chunk with its originating requestID, so multiple concurrent streams
    /// (e.g. different chats) never bleed into each other's continuations.
    func chatStream(
        config: WasmClient.ChatConfig,
        messages: [WasmClient.ChatMessage]
    ) async throws -> AsyncThrowingStream<String, Swift.Error> {
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
        let requestID = UUID().uuidString

        return AsyncThrowingStream { continuation in
            // Tracks whether any chunk reached the consumer. Read in the
            // detached task after `create()` returns to decide whether to fall
            // back to the task value (some providers ship the full response
            // as the WaTTask result instead of as SSE frames).
            let didReceiveChunks = ChunkFlag()
            // Tracks the timestamp of the last SSE frame plus an explicit
            // `finish_reason:"stop"` signal. Used by the post-`create()` wait
            // loop to short-circuit on WS-streaming providers (CAI) that
            // resolve `create()` early and keep emitting frames.
            let lastChunkAt = LastChunkTime()

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

            // Use Task.detached to avoid inheriting WasmActor isolation.
            // FlowKit's instance.create() must run on the global executor —
            // running it actor-isolated causes hangs under Xcode's debugger
            // (flow-kit-example avoids this by using a plain class, not an actor).
            let streamTask = Task.detached {
                log("chatStream: Task started (requestID: \(requestID))...")
                do {
                    log("chatStream: calling engine.create(action:args:requestID:)...")
                    let task = try await engine.create(action: action, args: args, requestID: requestID)
                    log("chatStream: task returned — status: \(task.status), hasValue: \(task.hasValue), didReceiveChunks: \(didReceiveChunks.value)")

                    // For WS-streaming providers (CAI), `engine.create()` resolves
                    // on the first partial Task while frames keep arriving via the
                    // SSE handler. Wait for an explicit `finish_reason:"stop"` or a
                    // quiet window of no chunks before treating the response as
                    // complete. Mirrors flow-kit-example's `sendViaWasm` poll loop.
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
                           !choice.message.content.isEmpty
                        {
                            continuation.yield(choice.message.content)
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

            // Termination handler runs when the consumer cancels the stream OR
            // when `continuation.finish(...)` is called above. Cancels the
            // underlying detached task (so the WASM-side work stops too) and
            // removes the per-request SSE handler.
            continuation.onTermination = { _ in
                streamTask.cancel()
                AsyncifyWasmInternal.removeSSEChunkHandler(for: requestID)
            }
        }
    }

    /// Single-shot tool/function calling over the streaming transport.
    ///
    /// Drives the same `RunAction` + `installSSEChunkHandler` path as `chatStream`,
    /// but instead of forwarding text deltas it accumulates the reply and captures
    /// `delta.tool_calls[]` from the SSE terminator (and mid-stream deltas), returning
    /// a `ChatMessage` with `.toolCalls` populated when the model picked a tool. Pass
    /// `config.tools` to advertise them and `config.toolChoice` to force one.
    ///
    /// One round only — it does NOT loop tool results back to the model.
    ///
    /// ⚠️ KNOWN BACKEND LIMITATION (verified on-device 2026-06): this gateway only
    /// supports tools as a NO-ARGUMENT signal (like the FlowKit example's
    /// `get_current_time`, whose params are `{}` and whose arguments are never
    /// read). When a tool has real parameters, the engine returns the tool call
    /// with an empty `function.name` and a TRUNCATED/garbled `arguments` string
    /// (JSON cut at the front, fields missing) — i.e. unusable for carrying data.
    /// So do NOT use this to extract structured data from the model; read data
    /// from `chatStream` content as JSON instead. This method is correct and kept
    /// ready for if/when the engine's tool_call assembly is fixed upstream.
    /// `chatStream` / `chatSend` are untouched.
    func chatToolCall(
        config: WasmClient.ChatConfig,
        messages: [WasmClient.ChatMessage]
    ) async throws -> WasmClient.ChatMessage {
        let instance = try await readyEngine()
        guard let engine = instance as? TaskWasmEngine else {
            throw WasmClient.Error.engineNotStarted
        }
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.chat.rawValue,
            preferredProvider: config.providerId.isEmpty ? nil : config.providerId,
            logger: logger
        )

        let bodyData = try Self.buildChatBody(config: config, messages: messages, stream: true)
        let bodyString = String(data: bodyData, encoding: .utf8)!

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
        let requestID = UUID().uuidString

        let accumulated = ContentAccumulator()
        let pendingToolCalls = ToolCallsBox()
        let lastChunkAt = LastChunkTime()
        let didReceiveChunks = ChunkFlag()

        // ── DEBUG: the exact request body sent to the engine ──
        log("[chatToolCall] body: \(bodyString)")

        // NOTE: this SSE handler is written to MIRROR the FlowKit example's
        // OpenAIChatSession.runStreaming exactly (capture tool_calls from the
        // terminator chunk with `set`, no incremental merge) so it can be
        // compared 1:1. If the engine ever streams tool_calls across multiple
        // chunks, switch back to a merge-by-index accumulator.
        AsyncifyWasmInternal.installSSEChunkHandler(for: requestID) { chunk in
            // ── DEBUG: every raw SSE chunk the engine emits ──
            log("[chatToolCall] rawChunk: \(chunk)")
            guard let data = chunk.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]] else { return }
            lastChunkAt.touch()
            // Terminator chunk: Rust sets finish_reason "stop" or "tool_calls";
            // when the model picked a tool, it carries delta.tool_calls[].
            if let finish = choices.first?["finish_reason"] as? String,
               finish == "stop" || finish == "tool_calls" {
                if let delta = choices.first?["delta"] as? [String: Any],
                   let calls = delta["tool_calls"] as? [[String: Any]],
                   !calls.isEmpty {
                    pendingToolCalls.set(calls)
                    log("[chatToolCall] terminator finish=\(finish) CAPTURED tool_calls=\(calls.count)")
                } else {
                    let keys = (choices.first?["delta"] as? [String: Any])?.keys.map { String($0) } ?? []
                    log("[chatToolCall] terminator finish=\(finish) NO tool_calls. deltaKeys=\(keys)")
                }
                lastChunkAt.markFinished()
                return
            }
            guard let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String,
                  !content.isEmpty else { return }
            didReceiveChunks.set()
            accumulated.append(content)
        }
        defer { AsyncifyWasmInternal.removeSSEChunkHandler(for: requestID) }

        // Run create() + the wait loop OFF the actor — exactly like chatStream.
        // FlowKit's instance.create() must run on the global executor; calling it
        // actor-isolated hangs and emits NO SSE chunks (the bug that made tool
        // calls always come back empty). The detached task returns the final
        // task once the terminator / quiet window settles.
        let task = try await Task.detached { () -> WaTTask in
            let created = try await engine.create(action: action, args: args, requestID: requestID)
            log("[chatToolCall] create returned status=\(created.status) hasValue=\(created.hasValue)")
            if created.status != .completed {
                let deadline = Date().addingTimeInterval(60)
                let quietWindow: TimeInterval = 2.5
                while Date() < deadline {
                    try await Task.sleep(nanoseconds: 200_000_000)
                    if lastChunkAt.finished { break }
                    if !didReceiveChunks.value, !pendingToolCalls.value.isEmpty { break }
                    if !didReceiveChunks.value {
                        if created.hasValue { break }
                        continue
                    }
                    if Date().timeIntervalSince(lastChunkAt.value) >= quietWindow { break }
                }
            }
            return created
        }.value

        // Build the assistant message. Tool calls from the terminator are
        // authoritative; streamed text lands in content.
        let toolCallDicts = pendingToolCalls.value
        // ── DEBUG: assembled tool_calls + how many mapped to a valid ToolCall ──
        let mapped = toolCallDicts.compactMap(Self.toolCall(from:))
        log("[chatToolCall] assembled dicts=\(toolCallDicts.count) mapped=\(mapped.count) rawDicts=\(toolCallDicts)")
        if !toolCallDicts.isEmpty {
            return WasmClient.ChatMessage(
                role: .assistant,
                content: accumulated.value,
                toolCalls: mapped
            )
        }
        if !accumulated.value.isEmpty {
            return WasmClient.ChatMessage(role: .assistant, content: accumulated.value)
        }
        // Fallback: full ChatCompletion proto in the task value (offline/mocked).
        if task.hasValue,
           let result = try? TypesBytes(unpackingAny: task.value),
           case .raw(let data) = result.data {
            // ── DEBUG: when no SSE chunk arrived, what (if anything) is in task.value ──
            log("[chatToolCall] task.value raw (\(data.count)b): \(String(data: data.prefix(800), encoding: .utf8) ?? "<binary>")")
            var opts = JSONDecodingOptions()
            opts.ignoreUnknownFields = true
            if let completion = try? OpenAIChatCompletion(jsonUTF8Data: data, options: opts),
               let choice = completion.choices.first {
                return Self.mapMessage(choice.message)
            }
        } else {
            log("[chatToolCall] no SSE chunks AND no task.value — engine returned nothing")
        }
        return WasmClient.ChatMessage(role: .assistant, content: "")
    }

    /// TEST PATH: run a one-shot tool call through the example's own
    /// `OpenAIChatSession` (copied verbatim from the FlowKit example, which works
    /// there). This bypasses `WasmActor`/`chatToolCall` entirely and serializes
    /// tools via the proto `OpenAITool.jsonUTF8Data()` exactly like the example —
    /// to confirm whether the difference vs our hand-built body matters.
    /// Logs with `[SessionTest]`. Returns the assistant message (read .toolCalls).
    func chatToolCallViaSession(
        config: WasmClient.ChatConfig,
        userText: String
    ) async throws -> WasmClient.ChatMessage {
        let engine = try await readyEngine()
        let session = OpenAIChatSession(engine: engine, model: config.model)

        // Pin to the same provider the rest of the app uses, via the resolved action.
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.chat.rawValue,
            preferredProvider: config.providerId.isEmpty ? nil : config.providerId,
            logger: logger
        )
        session.setAction(action)

        if !config.systemPrompt.isEmpty { session.setSystem(config.systemPrompt) }

        // Build OpenAIChatTool wrappers from config.tools (proto-serialized inside).
        let tools: [any OpenAIChatTool] = config.tools.map { t in
            ProxyTool(
                name: t.functionName,
                definition: ProxyTool.makeDefinition(
                    name: t.functionName,
                    description: t.functionDescription,
                    parametersJSON: t.parametersJSON
                )
            )
        }
        if let first = config.tools.first {
            // Force the tool, same `{type:function,function:{name}}` form as the example.
            session.toolChoice =
                ["type": "function", "function": ["name": first.functionName]] as [String: Any]
        }

        logger("[SessionTest] streaming via OpenAIChatSession, tools=\(tools.count)")
        var streamed = ""
        for try await delta in session.stream(userText, tools: tools) {
            streamed += delta
        }
        let last = session.messages.last
        let calls = last?.toolCalls ?? []
        logger("[SessionTest] done streamedLen=\(streamed.count) toolCalls=\(calls.count)")
        for (i, tc) in calls.enumerated() {
            logger("[SessionTest]   call[\(i)] name=\"\(tc.function.name)\" args=\(tc.function.arguments)")
        }
        return WasmClient.ChatMessage(
            role: .assistant,
            content: last?.content ?? streamed,
            toolCalls: calls.map {
                WasmClient.ToolCall(
                    id: $0.id,
                    type: $0.type,
                    functionName: $0.function.name,
                    functionArguments: $0.function.arguments
                )
            }
        )
    }

    /// Convert a raw tool_call dictionary (from the SSE terminator) into a
    /// `ChatMessage.ToolCall`. Returns nil when malformed.
    private static func toolCall(from dict: [String: Any]) -> WasmClient.ToolCall? {
        // `id` is optional — this gateway's streamed terminator omits it; only the
        // function name + arguments matter for the caller. Requiring `id` here was
        // silently dropping every tool call.
        guard let function = dict["function"] as? [String: Any],
              let name = function["name"] as? String,
              !name.isEmpty else { return nil }
        return WasmClient.ToolCall(
            id: (dict["id"] as? String) ?? "",
            type: (dict["type"] as? String) ?? "function",
            functionName: name,
            functionArguments: (function["arguments"] as? String) ?? ""
        )
    }

    /// Thread-safe text accumulator for `chatToolCall`'s streamed content.
    private final class ContentAccumulator: @unchecked Sendable {
        private let lock = NSLock()
        private var _value = ""
        var value: String { lock.withLock { _value } }
        func append(_ s: String) { lock.withLock { _value += s } }
    }

    /// Thread-safe holder for tool_calls. Handles both shapes: a terminator that
    /// carries the fully-assembled array (`set`), and OpenAI's incremental stream
    /// where each delta contributes a fragment keyed by `index` — id/name arrive
    /// first, then `arguments` is appended piece by piece (`merge`).
    private final class ToolCallsBox: @unchecked Sendable {
        private let lock = NSLock()
        private var byIndex: [Int: [String: Any]] = [:]
        private var explicit: [[String: Any]] = []

        var value: [[String: Any]] {
            lock.withLock {
                if !explicit.isEmpty { return explicit }
                return byIndex.sorted { $0.key < $1.key }.map { $0.value }
            }
        }

        func set(_ v: [[String: Any]]) { lock.withLock { explicit = v } }

        func merge(_ fragments: [[String: Any]]) {
            lock.withLock {
                for frag in fragments {
                    let idx = (frag["index"] as? Int) ?? 0
                    var entry = byIndex[idx] ?? [:]
                    if let id = frag["id"] as? String, !id.isEmpty { entry["id"] = id }
                    if let type = frag["type"] as? String, !type.isEmpty { entry["type"] = type }
                    if let fn = frag["function"] as? [String: Any] {
                        var merged = entry["function"] as? [String: Any] ?? [:]
                        if let name = fn["name"] as? String, !name.isEmpty { merged["name"] = name }
                        if let args = fn["arguments"] as? String {
                            merged["arguments"] = ((merged["arguments"] as? String) ?? "") + args
                        }
                        entry["function"] = merged
                    }
                    byIndex[idx] = entry
                }
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
        guard let payload = try? Google_Protobuf_Struct(unpackingAny: task.value) else {
            throw WasmClient.Error.unexpectedResponseFormat
        }

        var models: [WasmClient.ChatModelInfo] = []
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
            // `tool_choice` — "auto"/"required"/"none" or a specific function name.
            // A bare name becomes the OpenAI `{type:function,function:{name}}` form.
            if !config.toolChoice.isEmpty {
                switch config.toolChoice {
                case "auto", "required", "none":
                    body["tool_choice"] = config.toolChoice
                default:
                    body["tool_choice"] = [
                        "type": "function",
                        "function": ["name": config.toolChoice],
                    ]
                }
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
