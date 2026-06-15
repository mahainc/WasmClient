//
//  OpenAIChatSession.swift
//  TaskWasm
//

import Foundation
#if canImport(FlowKit)
import FlowKit
#else
import TaskWasm
import WasmSwiftProtobuf
#endif
import SwiftProtobuf

/// A multi-turn conversation manager for OpenAI-compatible chat APIs.
///
/// Maintains the message history across calls so each `send()` includes
/// the full conversation context.  Supports tool calling: set `tools`,
/// check the returned message for `toolCalls`, then call `sendToolResults`.
public enum OpenAIChatSessionError: Error, LocalizedError {
    case taskNotCompleted(status: String)
    case missingValue
    case unexpectedResponseFormat
    case actionNotFound(String)
    case httpError(statusCode: Int, body: String = "")

    public var errorDescription: String? {
        switch self {
        case .taskNotCompleted(let status):
            return "Task did not complete (status: \(status))"
        case .missingValue:
            return "Task completed without a value"
        case .unexpectedResponseFormat:
            return "Unexpected response data format"
        case .actionNotFound(let id):
            return "\(id) action not found"
        case .httpError(let statusCode, let body):
            return "HTTP request failed (status: \(statusCode))\(body.isEmpty ? "" : " \(body)")"
        }
    }
}

public enum OpenAIChatRole: String {
    case system
    case user
    case assistant
    case tool
}

/// Thread-safe content accumulator used by `stream()` to mirror the
/// content deltas it forwards to the caller — so we can synthesize a
/// completed assistant message if the underlying task resolution races
/// the SSE drain on the FFI backend.
private final class ContentBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = ""
    var value: String { lock.lock(); defer { lock.unlock() }; return _value }
    func append(_ s: String) { lock.lock(); _value += s; lock.unlock() }
}

/// Captures `tool_calls` extracted from Rust's synthetic terminator
/// chunk so the post-stream code path can surface them on the assistant
/// message instead of polling `task.value` (which doesn't resolve in
/// time on the FFI backend for tool-call turns).
private final class PendingToolCallsBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: [[String: Any]] = []
    var value: [[String: Any]] { lock.lock(); defer { lock.unlock() }; return _value }
    func set(_ calls: [[String: Any]]) { lock.lock(); _value = calls; lock.unlock() }
}

/// Tracks both the most recent SSE chunk timestamp (for the quiet-window
/// timeout heuristic) and an explicit "finished" latch (set when Rust
/// emits the synthetic `finish_reason: "stop"` terminator). Mirrors
/// `LastChunkTime` from the original ChatView implementation.
private final class LastChunkActivity: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = Date()
    private var _finished = false
    var value: Date { lock.lock(); defer { lock.unlock() }; return _value }
    var finished: Bool { lock.lock(); defer { lock.unlock() }; return _finished }
    func touch() { lock.lock(); _value = Date(); lock.unlock() }
    func markFinished() { lock.lock(); _finished = true; lock.unlock() }
}

public final class OpenAIChatSession: @unchecked Sendable {
    public let engine: TaskWasmProtocol
    public let endpoint: String
    public let apiKey: String
    public let model: String
    public private(set) var messages: [OpenAIChatMessage] = []
    public var tools: [OpenAITool] = []
    /// Optional OpenAI-spec `tool_choice` payload. `"auto"`, `"required"`,
    /// `"none"`, or a `{type:"function", function:{name:"…"}}` dictionary.
    /// Set per-turn to force the model to call a specific tool when the
    /// prompt clearly needs fresh data (e.g. time queries).
    public var toolChoice: Any?

    private static let actionID = "5e1ab91a-ac32-4269-9e20-4d864df4112d"

    private enum ArgKey: String {
        case url
        case apiKey = "api_key"
        case body
    }
    private var cachedAction: WaTAction?

    /// Override the auto-resolved chat action with a specific
    /// provider's action. Useful when the engine surfaces multiple
    /// providers sharing the same action ID and the caller wants to
    /// pin this session to one (e.g. selecting OpenAI vs OneAI vs VTN).
    public func setAction(_ action: WaTAction) {
        cachedAction = action
    }

    /// Full init with explicit endpoint/apiKey
    public init(engine: TaskWasmProtocol, endpoint: String, apiKey: String, model: String) {
        self.engine = engine
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.model = model
    }

    /// Minimal init — endpoint/apiKey defaults handled by wasm plugins
    public init(engine: TaskWasmProtocol, model: String = "gpt-4o-mini") {
        self.engine = engine
        self.endpoint = ""
        self.apiKey = ""
        self.model = model
    }

    /// Add a system prompt. Call before the first `send()`.
    public func setSystem(_ content: String) {
        var msg = OpenAIChatMessage()
        msg.role = OpenAIChatRole.system.rawValue
        msg.content = content
        messages.insert(msg, at: 0)
    }

    /// Reset conversation history.
    public func reset() {
        messages.removeAll()
        cachedAction = nil
    }

    /// Send a user message and return the assistant's reply.
    ///
    /// - Parameter tools: optional registry of Swift-defined tools. When
    ///   non-empty, their proto definitions are pushed onto `self.tools`
    ///   for this call; pass an empty array (default) to leave the
    ///   existing `self.tools` setting alone.
    public func send(
        _ content: String? = nil,
        tools: [any OpenAIChatTool] = []
    ) async throws -> OpenAIChatMessage {
        if !tools.isEmpty {
            self.tools = tools.map { $0.definition }
        }
        if let content = content {
            var userMsg = OpenAIChatMessage()
            userMsg.role = OpenAIChatRole.user.rawValue
            userMsg.content = content
            messages.append(userMsg)
        }
        return try await callAPI()
    }

    /// Send a message with text and image URL (multimodal).
    public func send(
        text: String,
        imageURL: String,
        detail: String? = nil,
        tools: [any OpenAIChatTool] = []
    ) async throws -> OpenAIChatMessage {
        try await send(text: text, imageURLs: [imageURL], detail: detail, tools: tools)
    }

    /// Send a message with text + multiple image URLs.
    public func send(
        text: String,
        imageURLs: [String],
        detail: String? = nil,
        tools: [any OpenAIChatTool] = []
    ) async throws -> OpenAIChatMessage {
        if !tools.isEmpty {
            self.tools = tools.map { $0.definition }
        }
        appendUserMessage(text: text, imageURLs: imageURLs, detail: detail)
        return try await callAPI()
    }

    /// Append a user message to `messages` without calling the API. The
    /// stream(_:imageURLs:tools:) variant uses this so the message lands
    /// in history before the streaming task starts.
    private func appendUserMessage(text: String, imageURLs: [String], detail: String?) {
        var userMsg = OpenAIChatMessage()
        userMsg.role = OpenAIChatRole.user.rawValue
        if imageURLs.isEmpty {
            userMsg.content = text
        } else {
            var parts: [OpenAIContentPart] = []
            var textPart = OpenAIContentPart()
            textPart.type = "text"
            textPart.text = text
            parts.append(textPart)
            for url in imageURLs {
                var imagePart = OpenAIContentPart()
                imagePart.type = "image_url"
                var img = OpenAIImageURL()
                img.url = url
                if let detail { img.detail = detail }
                imagePart.imageURL = img
                parts.append(imagePart)
            }
            userMsg.contentParts = parts
        }
        messages.append(userMsg)
    }

    /// Add tool execution results to the conversation, then resume to
    /// get the assistant's response.
    public func sendToolResults(
        _ results: [(callId: String, content: String)]
    ) async throws -> OpenAIChatMessage {
        for result in results {
            addToolResult(callId: result.callId, content: result.content)
        }
        return try await callAPI()
    }

    /// Add a tool result message to history without calling the API.
    public func addToolResult(callId: String, content: String) {
        var msg = OpenAIChatMessage()
        msg.role = OpenAIChatRole.tool.rawValue
        msg.toolCallID = callId
        msg.content = content
        messages.append(msg)
    }

    /// Stream the assistant's reply, yielding each content delta as it arrives.
    ///
    /// Routes through the WASM engine — Rust normalizes all provider SSE formats
    /// to OpenAI protocol and pushes parsed content via `sse_chunk` host import.
    /// After the stream finishes, the full assembled message is appended to
    /// `messages` (the caller can read it as `session.messages.last`).
    ///
    /// **Tool calls.** When `tools:` is non-empty and the model decides to
    /// invoke one, the stream yields no content deltas (tool-call chunks
    /// carry no text), terminates, and the assistant message appended to
    /// `messages` will have non-empty `toolCalls`. The caller is expected
    /// to dispatch each tool, push the outputs back via `addToolResult` /
    /// `sendToolResults`, and re-call `stream()` to get the model's
    /// natural-language follow-up:
    ///
    ///     for try await delta in session.stream("what time now?",
    ///                                           tools: [OpenAIChatSession.TimeTool()]) {
    ///         print(delta, terminator: "")
    ///     }
    ///     if let last = session.messages.last, !last.toolCalls.isEmpty {
    ///         var outputs: [(callId: String, content: String)] = []
    ///         for tc in last.toolCalls {
    ///             let args = (try? JSONSerialization.jsonObject(
    ///                 with: tc.function.arguments.data(using: .utf8) ?? Data())) as? [String: Any] ?? [:]
    ///             // Look up tool by tc.function.name in your registry and run it.
    ///             let out = try await runHandler(named: tc.function.name, args: args)
    ///             outputs.append((tc.id, out))
    ///         }
    ///         for try await delta in session.stream() {
    ///             print(delta, terminator: "")
    ///         }
    ///         _ = try await session.sendToolResults(outputs) // or: addToolResult then stream()
    ///     }
    public func stream(
        _ content: String? = nil,
        imageURLs: [String] = [],
        detail: String? = nil,
        tools: [any OpenAIChatTool] = []
    ) -> AsyncThrowingStream<String, Error> {
        if !tools.isEmpty {
            self.tools = tools.map { $0.definition }
        }
        if let content = content {
            appendUserMessage(text: content, imageURLs: imageURLs, detail: detail)
        }

        return AsyncThrowingStream { continuation in
            Task { [weak self] in
                guard let self else { continuation.finish(); return }
                do {
                    try await self.runStreaming(continuation: continuation)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Drive a streaming RunAction call exactly the way the original
    /// ChatView did before this was refactored — per-`requestID` SSE chunk
    /// handler, `finish_reason: "stop"` terminator OR 2.5s quiet window as
    /// the authoritative "done" signal, and the streamed content treated as
    /// the source of truth (task.value is only the fallback when nothing
    /// streamed). This shape is what works on the FFI backend where the
    /// `WaTTask` resolves mid-stream and `engine.status()` never flips.
    private func runStreaming(
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        let action = try await resolveAction()

        let bodyData = try buildRequestBody()
        let bodyString = String(data: bodyData, encoding: .utf8)!
        var args: [String: Google_Protobuf_Value] = [
            ArgKey.body.rawValue: Google_Protobuf_Value(stringValue: bodyString),
        ]
        if !endpoint.isEmpty {
            args[ArgKey.url.rawValue] = Google_Protobuf_Value(stringValue: endpoint)
        }
        if !apiKey.isEmpty {
            args[ArgKey.apiKey.rawValue] = Google_Protobuf_Value(stringValue: apiKey)
        }

        let requestID = UUID().uuidString
        let accumulated = ContentBox()
        let pendingToolCalls = PendingToolCallsBox()
        let activity = LastChunkActivity()

        AsyncifyWasmInternal.installSSEChunkHandler(for: requestID) { chunk in
            NSLog("[SessionTest] RAWCHUNK: %@", chunk)
            guard let data = chunk.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]] else { return }
            activity.touch()
            // Rust pushes a synthetic terminator chunk on `evt.done`; when
            // the model picked tools instead of streaming text, the
            // terminator carries `delta.tool_calls[]`. Capture them before
            // short-circuiting on finish_reason so the caller can read them
            // off `session.messages.last?.toolCalls`.
            if let finish = choices.first?["finish_reason"] as? String,
               finish == "stop" || finish == "tool_calls" {
                if let delta = choices.first?["delta"] as? [String: Any],
                   let calls = delta["tool_calls"] as? [[String: Any]],
                   !calls.isEmpty {
                    pendingToolCalls.set(calls)
                }
                activity.markFinished()
                return
            }
            guard let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String,
                  !content.isEmpty else { return }
            accumulated.append(content)
            continuation.yield(content)
        }
        defer { AsyncifyWasmInternal.removeSSEChunkHandler(for: requestID) }

        // Fire create() with the same requestID so chunks route back here.
        // Cast to TaskWasmEngine for the `requestID:`-threaded overload —
        // protocol-level `engine.create` doesn't expose it.
        let task: WaTTask
        if let typed = engine as? TaskWasmEngine {
            task = try await typed.create(action: action, args: args, requestID: requestID)
        } else {
            task = try await engine.create(action: action, args: args)
        }

        // The chunk handler signals "done streaming" via:
        //   - `finish_reason: "stop"` / `"tool_calls"` terminator chunk
        //     (synthesized by Rust on `evt.done` — works on both backends), OR
        //   - 2.5s of no new chunks (quiet window — provider hung up
        //     without a terminator), OR
        //   - 60s overall deadline (safety net).
        //
        // We do NOT call engine.status(task:) here — the chat consumer's
        // GetStatus path requires the original `body` arg and would always
        // throw on a re-call.
        if task.status != .completed {
            let deadline = Date().addingTimeInterval(60)
            let quietWindow: TimeInterval = 2.5
            while Date() < deadline {
                try await Task.sleep(nanoseconds: 200_000_000)
                if activity.finished { break }
                if accumulated.value.isEmpty {
                    if task.hasValue { break }
                    continue
                }
                if Date().timeIntervalSince(activity.value) >= quietWindow { break }
            }
        }

        // Decide what the assistant turn contains.
        //   - Tool calls captured from the terminator chunk are
        //     authoritative — they encode the model's chosen branch.
        //   - Streamed content lands in `.content` for text-only turns.
        //   - The task.value envelope is a last-resort fallback for the
        //     wasmkit backend where the synthetic terminator chunk wasn't
        //     observed but the final `ChatCompletion` proto IS in
        //     `task.value` (covers offline / mocked engines).
        var assistantMsg = OpenAIChatMessage()
        assistantMsg.role = OpenAIChatRole.assistant.rawValue

        let toolCallDicts = pendingToolCalls.value
        let streamed = accumulated.value
        if !toolCallDicts.isEmpty {
            assistantMsg.toolCalls = toolCallDicts.compactMap { toolCallFromDict($0) }
            if !streamed.isEmpty { assistantMsg.content = streamed }
            messages.append(assistantMsg)
            continuation.finish()
            return
        }

        if !streamed.isEmpty {
            assistantMsg.content = streamed
            messages.append(assistantMsg)
            continuation.finish()
            return
        }

        if task.hasValue,
           let result = try? task.unpack() as TypesBytes,
           case .raw(let data) = result.data,
           !data.isEmpty {
            var decodeOpts = JSONDecodingOptions()
            decodeOpts.ignoreUnknownFields = true
            if let completion = try? OpenAIChatCompletion(jsonUTF8Data: data, options: decodeOpts),
               let choice = completion.choices.first {
                messages.append(choice.message)
                continuation.finish()
                return
            }
            let raw = String(data: data, encoding: .utf8) ?? ""
            assistantMsg.content = raw
            messages.append(assistantMsg)
            continuation.finish()
            return
        }

        // Nothing streamed AND no usable task value.
        messages.append(assistantMsg)
        continuation.finish(throwing: OpenAIChatSessionError.taskNotCompleted(status: "\(task.status)"))
    }

    /// Convert a raw tool_call dictionary from Rust's terminator chunk
    /// into a proto `OpenAIToolCall`. Returns nil when the dictionary
    /// is malformed (missing id / function name).
    private func toolCallFromDict(_ dict: [String: Any]) -> OpenAIToolCall? {
        guard let id = dict["id"] as? String,
              let function = dict["function"] as? [String: Any],
              let name = function["name"] as? String,
              !name.isEmpty else {
            return nil
        }
        var tc = OpenAIToolCall()
        tc.id = id
        tc.type = (dict["type"] as? String) ?? "function"
        var fn = OpenAIToolCallFunction()
        fn.name = name
        fn.arguments = (function["arguments"] as? String) ?? ""
        tc.function = fn
        return tc
    }

    // MARK: - Private

    private func buildRequestBody() throws -> Data {
        var body: [String: Any] = [
            "model": model,
            "stream": true,
        ]
        // Serialize messages, handling multimodal content_parts
        body["messages"] = messages.map { msg -> [String: Any] in
            var dict: [String: Any] = ["role": msg.role]
            if !msg.contentParts.isEmpty {
                // Multimodal: serialize as "content": [...]
                dict["content"] = msg.contentParts.map { part -> [String: Any] in
                    var p: [String: Any] = ["type": part.type]
                    if part.hasText { p["text"] = part.text }
                    if part.hasImageURL {
                        var img: [String: Any] = ["url": part.imageURL.url]
                        if part.hasImageURL && part.imageURL.hasDetail {
                            img["detail"] = part.imageURL.detail
                        }
                        p["image_url"] = img
                    }
                    return p
                }
            } else if msg.hasContent {
                dict["content"] = msg.content
            }
            if !msg.toolCalls.isEmpty {
                dict["tool_calls"] = msg.toolCalls.map { tc -> [String: Any] in
                    ["id": tc.id, "type": tc.type, "function": [
                        "name": tc.function.name,
                        "arguments": tc.function.arguments
                    ]]
                }
            }
            if msg.hasToolCallID {
                dict["tool_call_id"] = msg.toolCallID
            }
            return dict
        }
        if !tools.isEmpty {
            let toolObjs = try tools.map {
                try JSONSerialization.jsonObject(with: $0.jsonUTF8Data())
            }
            body["tools"] = toolObjs
            if let choice = toolChoice {
                body["tool_choice"] = choice
            }
            // Log tools + tool_choice SEPARATELY so they aren't cut off by NSLog's
            // ~1KB limit (the messages block pushes them past it).
            if let td = try? JSONSerialization.data(withJSONObject: toolObjs) {
                NSLog("[SessionTest] TOOLS: %@", String(data: td, encoding: .utf8) ?? "<nil>")
            }
            NSLog("[SessionTest] TOOL_CHOICE: %@", "\(toolChoice ?? "nil")")
        }
        return try JSONSerialization.data(withJSONObject: body)
    }

    private func callAPI(requestID: String? = nil) async throws -> OpenAIChatMessage {
        let action = try await resolveAction()

        let bodyData = try buildRequestBody()
        let bodyString = String(data: bodyData, encoding: .utf8)!

        var args: [String: Google_Protobuf_Value] = [
            ArgKey.body.rawValue: Google_Protobuf_Value(stringValue: bodyString),
        ]
        if !endpoint.isEmpty {
            args[ArgKey.url.rawValue] = Google_Protobuf_Value(stringValue: endpoint)
        }
        if !apiKey.isEmpty {
            args[ArgKey.apiKey.rawValue] = Google_Protobuf_Value(stringValue: apiKey)
        }

        // Use the requestID-threaded create() overload when available so
        // `stream()` can install a per-stream SSE chunk handler that won't
        // collide with concurrent sends from other sessions.
        var task: WaTTask
        if let requestID, let typed = engine as? TaskWasmEngine {
            task = try await typed.create(action: action, args: args, requestID: requestID)
        } else {
            task = try await engine.create(action: action, args: args)
        }

        // The wasmtime (MOBILE_FFI) backend resolves create() before the SSE
        // delegate drains, returning `.processing`; wasmkit usually returns
        // `.completed` because it processes SSE synchronously. Poll status()
        // briefly to give the FFI backend a chance to flip to `.completed`.
        // Bounded short (≤6s) so the streaming UI doesn't stall — `stream()`
        // catches the `.taskNotCompleted` throw and synthesizes a message
        // from the buffered deltas if the poll never resolves.
        if task.status != .completed && task.status != .error {
            let deadline = Date().addingTimeInterval(6)
            while Date() < deadline {
                try await Task.sleep(nanoseconds: 200_000_000)
                task = try await engine.status(task: task)
                if task.status == .completed || task.status == .error { break }
            }
        }

        guard task.status == .completed else {
            throw OpenAIChatSessionError.taskNotCompleted(status: "\(task.status)")
        }
        guard task.hasValue else {
            throw OpenAIChatSessionError.missingValue
        }

        let result: TypesBytes = try task.unpack()
        guard case .raw(let data) = result.data else {
            throw OpenAIChatSessionError.unexpectedResponseFormat
        }

        // Try to parse as a full ChatCompletion (may contain tool_calls)
        var decodeOpts = JSONDecodingOptions()
        decodeOpts.ignoreUnknownFields = true
        if let completion = try? OpenAIChatCompletion(jsonUTF8Data: data, options: decodeOpts),
           let choice = completion.choices.first {
            let assistantMsg = choice.message
            messages.append(assistantMsg)
            return assistantMsg
        }

        // Fall back to plain text (SSE accumulated content)
        let responseText = String(data: data, encoding: .utf8) ?? ""
        var assistantMsg = OpenAIChatMessage()
        assistantMsg.role = OpenAIChatRole.assistant.rawValue
        assistantMsg.content = responseText
        messages.append(assistantMsg)
        return assistantMsg
    }

    private func resolveAction() async throws -> WaTAction {
        if let cached = cachedAction { return cached }
        let all = try await engine.actions()
        guard let action = all.actions.first(where: { $0.id == Self.actionID }) else {
            throw OpenAIChatSessionError.actionNotFound(Self.actionID)
        }
        cachedAction = action
        return action
    }
}

// MARK: - Tool dispatch

/// Conform a Swift type to expose it as an OpenAI function tool.
public protocol OpenAIChatTool: Sendable {
    /// Function name — must match `definition.function.name`.
    var name: String { get }
    /// `OpenAITool` proto envelope sent on every request.
    var definition: OpenAITool { get }
    /// Run the tool. Return a string (typically JSON) that becomes the
    /// `tool` role message fed back into the conversation.
    func call(args: [String: Any]) async throws -> String
}

extension OpenAIChatTool {
    /// Build a `function`-typed tool proto from a name, description, and
    /// JSON-schema string (the body of `function.parameters`).
    public static func makeDefinition(
        name: String,
        description: String,
        parametersJSON: String
    ) -> OpenAITool {
        var fn = OpenAIToolFunction()
        fn.name = name
        fn.description_p = description
        if let schema = try? Google_Protobuf_Struct(jsonString: parametersJSON) {
            fn.parameters = schema
        }
        var tool = OpenAITool()
        tool.type = "function"
        tool.function = fn
        return tool
    }
}

extension OpenAIChatSession {
    /// `get_current_weather(city)` — sample tool. Stub body; swap for a
    /// real CoreLocation / weather API call in production.
    public struct WeatherTool: OpenAIChatTool {
        public let name = "get_current_weather"
        public var definition: OpenAITool {
            Self.makeDefinition(
                name: name,
                description: "Get the current weather for a given city.",
                parametersJSON: #"""
                    {
                      "type": "object",
                      "properties": {
                        "city": { "type": "string", "description": "City name, e.g. Tokyo" }
                      },
                      "required": ["city"]
                    }
                """#
            )
        }
        public init() {}
        public func call(args: [String: Any]) async throws -> String {
            let city = args["city"] as? String ?? "Unknown"
            return #"{"city":"\#(city)","temp_c":22,"condition":"sunny"}"#
        }
    }

    /// `get_current_time()` — sample tool returning an ISO-8601 timestamp.
    public struct TimeTool: OpenAIChatTool {
        public let name = "get_current_time"
        public var definition: OpenAITool {
            Self.makeDefinition(
                name: name,
                description: "Return the current time in ISO-8601.",
                parametersJSON: #"{ "type": "object", "properties": {} }"#
            )
        }
        public init() {}
        public func call(args: [String: Any]) async throws -> String {
            ISO8601DateFormatter().string(from: Date())
        }
    }

}

/// Adapter that exposes a precomputed `OpenAITool` definition as an
/// `OpenAIChatTool`. Used by `chatToolCallViaSession` to test arbitrary tool
/// schemas without defining a Swift type per tool. `call` is unused (the test
/// path only inspects the returned tool_calls, never dispatches).
struct ProxyTool: OpenAIChatTool {
    let name: String
    let definition: OpenAITool
    func call(args: [String: Any]) async throws -> String { "{}" }
}
