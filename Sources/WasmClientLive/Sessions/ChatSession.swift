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
                AsyncifyWasmInternal.onSSEChunk = { chunk in
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

    /// Available chat models parsed from the chat action's metadata.
    /// Tries each provider for the chat action until one with model metadata is found.
    func chatModels() async throws -> (models: [WasmClient.ChatModelInfo], defaultEnumId: Int) {
        _ = try await readyEngine()
        let actions = try await delegate.resolveAllActions(actionID: WasmClient.ActionID.chat.rawValue, logger: logger)

        for action in actions {
            // Try both "model_infos" (legacy) and "models" (current) metadata keys.
            let list = action.metadata.fields["model_infos"]?.listValue
                ?? action.metadata.fields["models"]?.listValue
            guard let list, !list.values.isEmpty else { continue }

            let models: [WasmClient.ChatModelInfo] = list.values.enumerated().compactMap { idx, val in
                // Case 1: Value is a struct with field keys (legacy format).
                let fields = val.structValue.fields
                if !fields.isEmpty {
                    let stringId = fields["string_id"]?.stringValue
                        ?? fields["model"]?.stringValue
                        ?? fields["id"]?.stringValue
                    guard let stringId, !stringId.isEmpty else { return nil }
                    return WasmClient.ChatModelInfo(
                        id: stringId,
                        name: fields["name"]?.stringValue ?? stringId,
                        isPro: fields["is_pro"]?.boolValue ?? false,
                        imageSupport: fields["image_support"]?.boolValue ?? true,
                        enumId: Int(fields["id"]?.numberValue ?? 0)
                    )
                }
                // Case 2: Value is a plain string (just the model ID).
                let str = val.stringValue
                if !str.isEmpty {
                    return WasmClient.ChatModelInfo(
                        id: str, name: str, isPro: false, imageSupport: true, enumId: idx
                    )
                }
                return nil
            }
            if !models.isEmpty {
                let defaultEnumId = Int(action.metadata.fields["default_model"]?.numberValue ?? 0)
                return (models, defaultEnumId)
            }
        }

        return ([], 0)
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
