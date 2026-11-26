import Foundation
import WasmClient
import XCTest

@testable import WasmClientLive

final class ChatRunTests: XCTestCase {

    // MARK: - Helpers

    private typealias Msg = WasmClient.Chat.Message
    private typealias Call = WasmClient.Chat.ToolCall

    /// A scripted `send`: returns the pre-canned turn for each round index and
    /// records the messages it was handed, so a test can assert what the loop
    /// fed back to the model.
    private final class ScriptedSend: @unchecked Sendable {
        private let lock = NSLock()
        private let turns: [Msg]
        private(set) var callCount = 0
        private(set) var lastMessages: [Msg] = []

        init(turns: [Msg]) { self.turns = turns }

        var send: ChatToolLoop.Send {
            { [self] _, msgs in
                lock.withLock {
                    lastMessages = msgs
                    let index = min(callCount, turns.count - 1)
                    callCount += 1
                    return turns[index]
                }
            }
        }
    }

    // MARK: - (a) One tool round then a text answer

    func testRunsToolThenReturnsFinalText() async throws {
        let call = Call(id: "call_1", functionName: "get_time", functionArguments: "{}")
        let scripted = ScriptedSend(turns: [
            Msg(role: .assistant, toolCalls: [call]),
            Msg(role: .assistant, content: "It is noon."),
        ])

        let ran = LockedBox<[String]>([])
        let tool = WasmClient.Chat.ExecutableTool(functionName: "get_time") { c in
            ran.mutate { $0.append(c.id) }
            return "12:00"
        }

        let result = try await ChatToolLoop.run(
            config: .init(model: "m"),
            messages: [Msg(role: .user, content: "time?")],
            tools: [tool],
            maxRounds: 5,
            onEvent: nil,
            send: scripted.send
        )

        XCTAssertEqual(result.message.content, "It is noon.")
        XCTAssertEqual(ran.value, ["call_1"], "the handler should run exactly once")
        XCTAssertEqual(scripted.callCount, 2, "one tool round + one final round")

        // The second round must include the tool result, keyed to the call id.
        let toolMsg = scripted.lastMessages.first { $0.role == .tool }
        XCTAssertEqual(toolMsg?.toolCallID, "call_1")
        XCTAssertEqual(toolMsg?.content, "12:00")

        // Transcript ends on the final assistant text.
        XCTAssertEqual(result.transcript.last?.content, "It is noon.")
    }

    // MARK: - (b) maxRounds bounds a model that keeps asking for tools

    func testMaxRoundsBoundsTheLoop() async throws {
        let call = Call(id: "loop", functionName: "spin", functionArguments: "{}")
        // Every turn asks for a tool again — would loop forever if unbounded.
        let scripted = ScriptedSend(turns: [Msg(role: .assistant, toolCalls: [call])])
        let tool = WasmClient.Chat.ExecutableTool(functionName: "spin") { _ in "ok" }

        let result = try await ChatToolLoop.run(
            config: .init(model: "m"),
            messages: [],
            tools: [tool],
            maxRounds: 3,
            onEvent: nil,
            send: scripted.send
        )

        XCTAssertEqual(scripted.callCount, 3, "must stop after exactly maxRounds sends")
        XCTAssertFalse(result.message.toolCalls.isEmpty, "last turn still had a pending tool call")
    }

    // MARK: - (c) Unknown tool name yields a structured error, not a crash

    func testUnknownToolProducesErrorResult() async throws {
        let call = Call(id: "x", functionName: "does_not_exist", functionArguments: "{}")
        let scripted = ScriptedSend(turns: [
            Msg(role: .assistant, toolCalls: [call]),
            Msg(role: .assistant, content: "done"),
        ])

        let result = try await ChatToolLoop.run(
            config: .init(model: "m"),
            messages: [],
            tools: [],
            maxRounds: 5,
            onEvent: nil,
            send: scripted.send
        )

        let toolMsg = scripted.lastMessages.first { $0.role == .tool }
        XCTAssertEqual(toolMsg?.toolCallID, "x")
        XCTAssertTrue(toolMsg?.content.contains("unknown tool") ?? false)
        XCTAssertEqual(result.message.content, "done")
    }

    // MARK: - (d) web-search flag toggles the request body (protects old behavior)

    func testWebSearchFlagTogglesBody() throws {
        let off = try WasmActor.buildChatBody(
            config: .init(model: "m"),
            messages: [Msg(role: .user, content: "hi")],
            stream: false
        )
        let offJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: off) as? [String: Any]
        )
        XCTAssertNil(offJSON["web_search_options"], "default body must omit web_search_options")

        let on = try WasmActor.buildChatBody(
            config: .init(model: "m", webSearch: true),
            messages: [Msg(role: .user, content: "hi")],
            stream: false
        )
        let onJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: on) as? [String: Any]
        )
        XCTAssertNotNil(onJSON["web_search_options"], "webSearch=true must attach web_search_options")
    }
}

// MARK: - Test utilities

private final class LockedBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Value
    init(_ value: Value) { _value = value }
    var value: Value { lock.withLock { _value } }
    func mutate(_ transform: (inout Value) -> Void) {
        lock.withLock { transform(&_value) }
    }
}
