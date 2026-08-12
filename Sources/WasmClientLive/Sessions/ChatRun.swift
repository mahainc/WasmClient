import Foundation
import WasmClient

// MARK: - Chat agentic tool-calling loop

/// The pure OpenAI function-calling loop, decoupled from the engine.
///
/// It takes a `send` closure that performs one model round-trip — in production
/// that is `WasmActor.completion`; in tests it is a stub — so the branching /
/// tool-dispatch / round-bounding logic can be exercised without a live engine.
enum ChatToolLoop {

    typealias Send =
        @Sendable (
            WasmClient.Chat.Config, [WasmClient.Chat.Message]
        ) async throws -> WasmClient.Chat.Message

    /// Each round sends the running conversation (plus the tool definitions) to
    /// the model via `send`. A text answer ends the loop; a `toolCalls` answer
    /// runs every handler, appends each output as a `role: .tool` message keyed
    /// by `toolCallID`, and sends again — up to `maxRounds` model round-trips.
    static func run(
        config: WasmClient.Chat.Config,
        messages: [WasmClient.Chat.Message],
        tools: [WasmClient.Chat.ExecutableTool],
        maxRounds: Int,
        onEvent: (@Sendable (WasmClient.Chat.ChatRunEvent) async -> Void)?,
        send: Send
    ) async throws -> WasmClient.Chat.ChatRunResult {
        let handlers = Dictionary(
            tools.map { ($0.tool.functionName, $0.handler) },
            uniquingKeysWith: { first, _ in first }
        )
        let effectiveConfig = merging(config: config, tools: tools.map(\.tool))

        var convo = messages

        // maxRounds bounds the model round-trips; a value < 1 still does one
        // pass so a caller that forgets to set it gets a plain completion.
        let rounds = max(1, maxRounds)
        for round in 0..<rounds {
            await onEvent?(.round(round))

            let assistant = try await send(effectiveConfig, convo)
            convo.append(assistant)
            await onEvent?(.assistantMessage(assistant))

            guard !assistant.toolCalls.isEmpty else {
                await onEvent?(.finished(assistant))
                return WasmClient.Chat.ChatRunResult(message: assistant, transcript: convo)
            }

            for call in assistant.toolCalls {
                await onEvent?(.toolCallStarted(call))
                let output = try await dispatch(call, handlers: handlers)
                convo.append(
                    WasmClient.Chat.Message(
                        role: .tool,
                        content: output,
                        toolCallID: call.id
                    )
                )
                await onEvent?(.toolResult(callID: call.id, content: output))
            }
        }

        // Exhausted maxRounds while still requesting tools: surface the last
        // assistant message so the caller isn't left with nothing.
        let last =
            convo.last(where: { $0.role == .assistant })
            ?? WasmClient.Chat.Message(role: .assistant)
        await onEvent?(.finished(last))
        return WasmClient.Chat.ChatRunResult(message: last, transcript: convo)
    }

    private static func dispatch(
        _ call: WasmClient.Chat.ToolCall,
        handlers: [String: @Sendable (WasmClient.Chat.ToolCall) async throws -> String]
    ) async throws -> String {
        guard let handler = handlers[call.functionName] else {
            return unknownToolJSON(call.functionName)
        }
        return try await handler(call)
    }

    private static func merging(
        config: WasmClient.Chat.Config,
        tools: [WasmClient.Chat.Tool]
    ) -> WasmClient.Chat.Config {
        guard !tools.isEmpty else { return config }
        return WasmClient.Chat.Config(
            model: config.model,
            endpoint: config.endpoint,
            apiKey: config.apiKey,
            systemPrompt: config.systemPrompt,
            tools: config.tools + tools,
            providerID: config.providerID,
            webSearch: config.webSearch,
            modalities: config.modalities
        )
    }

    private static func unknownToolJSON(_ name: String) -> String {
        let escaped = name.replacingOccurrences(of: "\"", with: "\\\"")
        return "{\"error\":\"unknown tool: \(escaped)\"}"
    }
}

// MARK: - Engine binding

extension WasmActor {

    /// Bind `ChatToolLoop` to the live engine via `completion` — the async
    /// `chatSend` path returns `status: processing` on the shipped engine.
    func chatRun(
        config: WasmClient.Chat.Config,
        messages: [WasmClient.Chat.Message],
        tools: [WasmClient.Chat.ExecutableTool],
        maxRounds: Int,
        onEvent: (@Sendable (WasmClient.Chat.ChatRunEvent) async -> Void)?
    ) async throws -> WasmClient.Chat.ChatRunResult {
        try await ChatToolLoop.run(
            config: config,
            messages: messages,
            tools: tools,
            maxRounds: maxRounds,
            onEvent: onEvent,
            send: { [self] cfg, msgs in
                try await completion(config: cfg, messages: msgs)
            }
        )
    }
}
