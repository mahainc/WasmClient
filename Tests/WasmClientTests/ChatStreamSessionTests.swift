import Dependencies
import Foundation
import XCTest

@testable import WasmClient

final class ChatStreamSessionTests: XCTestCase {

    // MARK: - Helpers

    /// A stub `chatStream` that yields the given chunks then finishes.
    private func stubStream(_ chunks: [String])
        -> @Sendable (
            WasmClient.ChatConfig, [WasmClient.ChatMessage]
        ) async throws -> AsyncThrowingStream<String, Error>
    {
        { _, _ in
            AsyncThrowingStream { continuation in
                for chunk in chunks {
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
        }
    }

    /// Collect events from a subscription, breaking once `stopWhen` matches.
    /// Bounded by a deadline so a logic bug fails the test instead of hanging.
    private func collect(
        _ stream: AsyncStream<ChatStreamSession.Event>,
        timeout: Duration = .seconds(2),
        stopWhen: @escaping @Sendable (ChatStreamSession.Event) -> Bool
    ) async -> [ChatStreamSession.Event] {
        await withTaskGroup(of: [ChatStreamSession.Event]?.self) { group in
            group.addTask {
                var out: [ChatStreamSession.Event] = []
                for await event in stream {
                    out.append(event)
                    if stopWhen(event) { break }
                }
                return out
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first ?? []
        }
    }

    private func waitForStatus(
        _ session: ChatStreamSession,
        conversationID: UUID,
        status: ChatStreamSession.Status,
        timeout: Duration = .seconds(2)
    ) async {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            if await session.snapshot(conversationID: conversationID)?.status == status { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    // MARK: - (a) Accumulate across deltas

    func testAccumulatesDeltasAndFinishes() async {
        let cid = UUID()
        let assistantID = UUID()

        await withDependencies {
            $0.wasm = .noop
            $0.wasm.chatStream = stubStream(["Hel", "lo", " there"])
        } operation: {
            let session = ChatStreamSession()
            let stream = await session.subscribe(conversationID: cid)
            // Give the parked subscription a beat to register before start.
            try? await Task.sleep(for: .milliseconds(20))

            await session.start(
                conversationID: cid,
                assistantMessageID: assistantID,
                config: .init(model: "m"),
                history: []
            )

            let events = await collect(stream) {
                if case .finished = $0 { return true }
                return false
            }

            let deltas = events.compactMap { event -> String? in
                if case .delta(_, let chunk) = event { return chunk }
                return nil
            }
            XCTAssertEqual(deltas, ["Hel", "lo", " there"])

            guard case .finished(let id, let text) = events.last else {
                return XCTFail("expected .finished, got \(String(describing: events.last))")
            }
            XCTAssertEqual(id, assistantID)
            XCTAssertEqual(text, "Hello there")
        }
    }

    // MARK: - (b) Late subscriber gets a replay

    func testLateSubscriberReceivesReplay() async {
        let cid = UUID()
        let assistantID = UUID()

        await withDependencies {
            $0.wasm = .noop
            $0.wasm.chatStream = stubStream(["Done."])
        } operation: {
            let session = ChatStreamSession()
            await session.start(
                conversationID: cid,
                assistantMessageID: assistantID,
                config: .init(model: "m"),
                history: []
            )
            // Let the stream run to completion before anyone subscribes.
            await waitForStatus(session, conversationID: cid, status: .completed)

            let stream = await session.subscribe(conversationID: cid)
            let events = await collect(stream) {
                if case .finished = $0 { return true }
                return false
            }

            guard case .replay(let id, let text) = events.first else {
                return XCTFail("expected leading .replay, got \(String(describing: events.first))")
            }
            XCTAssertEqual(id, assistantID)
            XCTAssertEqual(text, "Done.")
            guard case .finished = events.last else {
                return XCTFail("expected trailing .finished")
            }
        }
    }

    // MARK: - (c) Subscriber survives a regenerate (start-replace)

    // The regenerate test needs one continuous actor instance across two runs,
    // so it runs as a single scope with the stub swapped between starts.
    func testRegenerateDeliversSecondRunToSameSubscriber() async {
        let cid = UUID()
        let assistantID = UUID()
        let firstStub = stubStream(["A"])
        let secondStub = stubStream(["B"])

        await withDependencies {
            $0.wasm = .noop
            $0.wasm.chatStream = firstStub
        } operation: {
            let session = ChatStreamSession()
            let stream = await session.subscribe(conversationID: cid)
            try? await Task.sleep(for: .milliseconds(20))

            // Run 1.
            await session.start(
                conversationID: cid,
                assistantMessageID: assistantID,
                config: .init(model: "m"),
                history: []
            )
            let firstEvents = await collect(stream) {
                if case .finished = $0 { return true }
                return false
            }
            XCTAssertTrue(firstEvents.contains { if case .delta(_, "A") = $0 { return true } else { return false } })

            // Run 2 (regenerate) — swap the stub, reuse the same subscriber.
            await withDependencies {
                $0.wasm.chatStream = secondStub
            } operation: {
                await session.start(
                    conversationID: cid,
                    assistantMessageID: assistantID,
                    config: .init(model: "m"),
                    history: []
                )
                let secondEvents = await collect(stream) {
                    if case .finished = $0 { return true }
                    return false
                }
                XCTAssertTrue(
                    secondEvents.contains { if case .delta(_, "B") = $0 { return true } else { return false } },
                    "same subscriber should receive the regenerated run's delta"
                )
            }
        }
    }

    // MARK: - (d) Stop cancels and emits .stopped with partial text

    func testStopEmitsStoppedWithPartialText() async {
        let cid = UUID()
        let assistantID = UUID()

        await withDependencies {
            $0.wasm = .noop
            // Yields one chunk then stays open until the task is cancelled.
            $0.wasm.chatStream = { _, _ in
                AsyncThrowingStream { continuation in
                    continuation.yield("partial")
                    // Intentionally never finishes.
                }
            }
        } operation: {
            let session = ChatStreamSession()
            let stream = await session.subscribe(conversationID: cid)
            try? await Task.sleep(for: .milliseconds(20))

            await session.start(
                conversationID: cid,
                assistantMessageID: assistantID,
                config: .init(model: "m"),
                history: []
            )

            // Wait until the partial chunk has been accumulated.
            await waitForStatus(session, conversationID: cid, status: .streaming)
            var partialSeen = false
            let deadline = ContinuousClock.now.advanced(by: .seconds(2))
            while ContinuousClock.now < deadline {
                if await session.snapshot(conversationID: cid)?.accumulatedText == "partial" {
                    partialSeen = true
                    break
                }
                try? await Task.sleep(for: .milliseconds(5))
            }
            XCTAssertTrue(partialSeen, "partial chunk should have accumulated")

            await session.stop(conversationID: cid)

            let events = await collect(stream) {
                if case .stopped = $0 { return true }
                return false
            }
            guard case .stopped(let id, let text) = events.last else {
                return XCTFail("expected .stopped, got \(String(describing: events.last))")
            }
            XCTAssertEqual(id, assistantID)
            XCTAssertEqual(text, "partial")
        }
    }

    // MARK: - (e) Parked subscriber (subscribe before start) receives events

    func testParkedSubscriberReceivesEventsAfterStart() async {
        let cid = UUID()
        let assistantID = UUID()

        await withDependencies {
            $0.wasm = .noop
            $0.wasm.chatStream = stubStream(["Hi"])
        } operation: {
            let session = ChatStreamSession()
            // Subscribe BEFORE any start → parked, no stream entry exists yet.
            let stream = await session.subscribe(conversationID: cid)
            let preStartSnapshot = await session.snapshot(conversationID: cid)
            XCTAssertNil(preStartSnapshot)
            try? await Task.sleep(for: .milliseconds(20))

            await session.start(
                conversationID: cid,
                assistantMessageID: assistantID,
                config: .init(model: "m"),
                history: []
            )

            let events = await collect(stream) {
                if case .finished = $0 { return true }
                return false
            }
            XCTAssertTrue(
                events.contains { if case .delta(_, "Hi") = $0 { return true } else { return false } },
                "parked subscriber should receive deltas once start runs"
            )
            guard case .finished(_, let text) = events.last else {
                return XCTFail("expected .finished")
            }
            XCTAssertEqual(text, "Hi")
        }
    }
}
