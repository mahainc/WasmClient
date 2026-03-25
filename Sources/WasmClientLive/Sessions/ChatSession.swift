@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Chat

extension WasmActor {

    /// Send a chat message and return the full response.
    /// Uses FlowKit's built-in OpenAIChatSession for API communication.
    func chatSend(
        config: WasmClient.ChatConfig,
        messages: [WasmClient.ChatMessage]
    ) async throws -> WasmClient.ChatMessage {
        let session = try await buildChatSession(config: config, messages: messages)

        // Send the last message (or nil if no user message at the end)
        let lastMsg = messages.last
        let response: OpenAIChatMessage
        if let last = lastMsg, last.role == .user {
            if !last.contentParts.isEmpty,
               let textPart = last.contentParts.first(where: { $0.type == "text" }),
               let imagePart = last.contentParts.first(where: { $0.type == "image_url" }) {
                response = try await session.send(
                    text: textPart.text,
                    imageURL: imagePart.imageURL,
                    detail: imagePart.imageDetail.isEmpty ? nil : imagePart.imageDetail
                )
            } else {
                response = try await session.send(last.content)
            }
        } else {
            response = try await session.send(nil)
        }

        return mapChatMessage(response)
    }

    /// Stream a chat response, yielding content deltas as they arrive via SSE.
    /// Uses FlowKit's built-in OpenAIChatSession.stream() which returns
    /// AsyncThrowingStream<OpenAIChatChunkChoice, Error>.
    func chatStream(
        config: WasmClient.ChatConfig,
        messages: [WasmClient.ChatMessage]
    ) async throws -> AsyncThrowingStream<String, Swift.Error> {
        let session = try await buildChatSession(config: config, messages: messages)

        // Stream the last message
        let lastContent: String? = {
            guard let last = messages.last, last.role == .user else { return nil }
            return last.content
        }()
        let chunkStream = session.stream(lastContent)

        // Map OpenAIChatChunkChoice -> String content deltas
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await chunk in chunkStream {
                        if chunk.hasDelta && chunk.delta.hasContent && !chunk.delta.content.isEmpty {
                            continuation.yield(chunk.delta.content)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Chat Helpers

    /// Build an OpenAIChatSession, populating history from the messages array.
    /// The last user message is NOT added — it's passed to send()/stream().
    private func buildChatSession(
        config: WasmClient.ChatConfig,
        messages: [WasmClient.ChatMessage]
    ) async throws -> OpenAIChatSession {
        let instance = try await readyEngine()
        let session = OpenAIChatSession(
            engine: instance,
            endpoint: config.endpoint,
            apiKey: config.apiKey,
            model: config.model
        )

        // Set system prompt
        if !config.systemPrompt.isEmpty {
            session.setSystem(config.systemPrompt)
        }

        // Add history messages (all except last user message which goes to send/stream)
        let history = messages.last?.role == .user ? messages.dropLast() : messages[...]
        for msg in history {
            switch msg.role {
            case .user:
                _ = try await session.send(msg.content)
            case .tool:
                session.addToolResult(callId: msg.toolCallID, content: msg.content)
            case .assistant:
                // Assistant messages are added by send() responses, skip
                break
            case .system:
                // System prompt already set above
                break
            }
        }

        return session
    }

    private func mapChatMessage(_ proto: OpenAIChatMessage) -> WasmClient.ChatMessage {
        let role: WasmClient.ChatRole
        switch proto.role {
        case "system": role = .system
        case "assistant": role = .assistant
        case "tool": role = .tool
        default: role = .user
        }

        let toolCalls = proto.toolCalls.map { tc in
            WasmClient.ToolCall(
                id: tc.id,
                type: tc.type,
                functionName: tc.function.name,
                functionArguments: tc.function.arguments
            )
        }

        // OpenAIAnnotation has a urlCitation sub-message
        let annotations = proto.annotations.map { ann in
            WasmClient.Annotation(
                type: ann.type,
                url: ann.hasURLCitation ? ann.urlCitation.url : "",
                title: ann.hasURLCitation ? ann.urlCitation.title : "",
                startIndex: ann.hasURLCitation ? Int(ann.urlCitation.startIndex) : 0,
                endIndex: ann.hasURLCitation ? Int(ann.urlCitation.endIndex) : 0
            )
        }

        let contentParts = proto.contentParts.map { part in
            WasmClient.ContentPart(
                type: part.type,
                text: part.text,
                imageURL: part.hasImageURL ? part.imageURL.url : "",
                imageDetail: part.hasImageURL ? part.imageURL.detail : ""
            )
        }

        return WasmClient.ChatMessage(
            role: role,
            content: proto.content,
            toolCalls: toolCalls,
            toolCallID: proto.toolCallID,
            contentParts: contentParts,
            annotations: annotations
        )
    }
}
