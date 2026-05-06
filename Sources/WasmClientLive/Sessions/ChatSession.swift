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
        let action = try await delegate.resolveAction(actionID: WasmClient.ActionID.chat.rawValue, logger: logger)

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
    func chatStream(
        config: WasmClient.ChatConfig,
        messages: [WasmClient.ChatMessage]
    ) async throws -> AsyncThrowingStream<String, Swift.Error> {
        logger("chatStream: acquiring engine...")
        let instance = try await readyEngine()
        logger("chatStream: resolving chat action...")
        let action = try await delegate.resolveAction(actionID: WasmClient.ActionID.chat.rawValue, logger: logger)
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

        return AsyncThrowingStream { continuation in
            // Use Task.detached to avoid inheriting WasmActor isolation.
            // FlowKit's instance.create() must run on the global executor —
            // running it actor-isolated causes hangs under Xcode's debugger
            // (flow-kit-example avoids this by using a plain class, not an actor).
            Task.detached {
                log("chatStream: Task started, setting SSE callback...")
                var didReceiveChunks = false
                let prev = AsyncifyWasmInternal.onSSEChunk
                AsyncifyWasmInternal.onSSEChunk = { _, chunk in
                    guard let data = chunk.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let choices = json["choices"] as? [[String: Any]],
                          let delta = choices.first?["delta"] as? [String: Any],
                          let content = delta["content"] as? String,
                          !content.isEmpty else { return }
                    didReceiveChunks = true
                    continuation.yield(content)
                }
                defer { AsyncifyWasmInternal.onSSEChunk = prev }
                do {
                    log("chatStream: calling instance.create(action:args:)...")
                    let task = try await instance.create(action: action, args: args)
                    log("chatStream: task completed — status: \(task.status), hasValue: \(task.hasValue), didReceiveChunks: \(didReceiveChunks)")
                    // If no SSE chunks arrived, fall back to the task result
                    if !didReceiveChunks,
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
        }
    }

    /// Fetch chat models via the standalone `listModels` action with
    /// `offset` / `limit` / optional `keyword`. Each model row is stamped
    /// with its source provider (resolved from the row's
    /// `metadata.provider_id` against the registered chat providers).
    func chatModels(
        offset: Int,
        limit: Int,
        keyword: String?
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
