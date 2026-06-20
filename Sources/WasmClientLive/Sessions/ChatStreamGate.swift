@preconcurrency import FlowKit
import Foundation

/// Serializes in-flight chat SSE streams on the shared WASM runtime.
///
/// When a consumer cancels mid-stream, the native engine keeps emitting WS
/// frames tagged with the **cancelled stream's `requestID`**. A discard handler
/// on a synthetic ID never sees them; the next stream's handler then receives
/// the stale tail. This gate swaps the live handler to discard-only on the
/// same `requestID`, waits for a real quiet window, removes it, then allows
/// the next `chatStream` to register.
///
/// Livescore / other SSE domains use their own handlers and are unaffected.
final class ChatStreamGate: @unchecked Sendable {
    private let lock = NSLock()
    private var activeRequestID: String?
    private var activeTeardown: (@Sendable () -> Void)?
    private var activeTask: Task<Void, Never>?
    private var quarantineTask: Task<Void, Never>?
    private var quarantineGeneration: UInt64 = 0
    private var quarantineRequestID: String?
    private let activity = QuarantineActivity()

    /// Matches `chatStream`'s WS quiet window.
    private let quietWindowSeconds: TimeInterval = 2.5
    /// Safety cap so a hung provider cannot block chat forever.
    private let maxQuarantineSeconds: TimeInterval = 60

    /// Called before a new chat stream (or chat send) touches the engine. Tears
    /// down any previous stream and waits for quarantine to finish.
    func prepareForStream(
        recoverEngine: (@Sendable () async -> Void)? = nil,
        log: @escaping @Sendable (String) -> Void
    ) async {
        let previous: ((@Sendable () -> Void)?, Task<Void, Never>?, String?) = lock.withLock {
            let teardown = activeTeardown
            let task = activeTask
            let id = activeRequestID
            activeTeardown = nil
            activeTask = nil
            activeRequestID = nil
            return (teardown, task, id)
        }

        if let teardown = previous.0, let requestID = previous.2 {
            let idPrefix = String(requestID.prefix(8))
            log("chatStream gate: tearing down previous stream requestID=\(idPrefix)")
            teardown()
            if let task = previous.1 {
                await task.value
            }
            beginQuarantine(
                requestID: requestID,
                assumeStale: true,
                recoverEngine: recoverEngine,
                log: log,
                reason: "previous stream torn down"
            )
        }

        await awaitQuarantine(log: log)
    }

    /// Registers the in-flight stream so the next `prepareForStream` can cancel it.
    func register(
        requestID: String,
        teardown: @escaping @Sendable () -> Void,
        task: Task<Void, Never>
    ) {
        lock.withLock {
            activeRequestID = requestID
            activeTeardown = teardown
            activeTask = task
        }
    }

    /// Clears the active slot after a stream finishes or is cancelled.
    func clearActive(requestID: String) {
        lock.withLock {
            guard activeRequestID == requestID else { return }
            activeRequestID = nil
            activeTeardown = nil
            activeTask = nil
        }
    }

    /// Cancels the Swift stream task and quarantines stale SSE on the same
    /// `requestID` the native engine is still emitting on.
    func streamCancelled(
        requestID: String,
        cancelTask: @escaping @Sendable () -> Void,
        recoverEngine: (@Sendable () async -> Void)?,
        log: @escaping @Sendable (String) -> Void
    ) {
        cancelTask()
        clearActive(requestID: requestID)
        beginQuarantine(
            requestID: requestID,
            assumeStale: true,
            recoverEngine: recoverEngine,
            log: log,
            reason: "stream cancelled"
        )
    }

    private func beginQuarantine(
        requestID: String,
        assumeStale: Bool,
        recoverEngine: (@Sendable () async -> Void)?,
        log: @escaping @Sendable (String) -> Void,
        reason: String
    ) {
        let shouldLog: Bool = lock.withLock {
            if let existing = quarantineTask, !existing.isCancelled,
                quarantineRequestID == requestID
            {
                return false
            }

            quarantineGeneration &+= 1
            let generation = quarantineGeneration
            quarantineRequestID = requestID
            activity.reset()

            // Replace the live yield handler with a discard handler on the
            // **same** requestID so native stale frames stay routed here.
            AsyncifyWasmInternal.removeSSEChunkHandler(for: requestID)
            AsyncifyWasmInternal.installSSEChunkHandler(for: requestID) { [activity] chunk in
                activity.noteChunk(chunk)
            }

            quarantineTask = Task { [weak self] in
                guard let self else { return }
                defer { self.finishQuarantine(generation: generation, requestID: requestID) }

                let idPrefix = String(requestID.prefix(8))

                if let recoverEngine {
                    log("chatStream gate: recovering TaskWasmEngine requestID=\(idPrefix)")
                    await recoverEngine()
                }

                let start = Date()
                let deadline = start.addingTimeInterval(self.maxQuarantineSeconds)

                while Date() < deadline {
                    if Task.isCancelled { break }
                    try? await Task.sleep(nanoseconds: 200_000_000)

                    if self.activity.finished {
                        log(
                            "chatStream gate: quarantine finished on stop "
                                + "requestID=\(idPrefix) "
                                + "(discarded \(self.activity.chunkCount) stale frame(s))"
                        )
                        break
                    }

                    let idle = Date().timeIntervalSince(self.activity.lastEvent)
                    if self.activity.sawChunks, idle >= self.quietWindowSeconds {
                        log(
                            "chatStream gate: quarantine quiet after stale SSE "
                                + "requestID=\(idPrefix) "
                                + "(discarded \(self.activity.chunkCount) frame(s), idle "
                                + "\(Int(idle * 1000))ms)"
                        )
                        break
                    }

                    if !assumeStale, Date().timeIntervalSince(start) >= self.quietWindowSeconds {
                        log(
                            "chatStream gate: quarantine quiet requestID=\(idPrefix) "
                                + "(no stale SSE observed)"
                        )
                        break
                    }
                }

                if Date() >= deadline {
                    log(
                        "chatStream gate: quarantine timed out after "
                            + "\(Int(self.maxQuarantineSeconds))s requestID=\(idPrefix) "
                            + "(discarded \(self.activity.chunkCount) frame(s))"
                    )
                }
            }
            return true
        }

        if shouldLog {
            let idPrefix = String(requestID.prefix(8))
            log("chatStream gate: quarantine started requestID=\(idPrefix) (\(reason))")
        }
    }

    private func finishQuarantine(generation: UInt64, requestID: String) {
        lock.withLock {
            guard quarantineGeneration == generation else { return }
            AsyncifyWasmInternal.removeSSEChunkHandler(for: requestID)
            quarantineRequestID = nil
            quarantineTask = nil
        }
    }

    private func awaitQuarantine(log: @escaping @Sendable (String) -> Void) async {
        let task: Task<Void, Never>? = lock.withLock { quarantineTask }
        guard let task else { return }
        log("chatStream gate: waiting for quarantine to finish")
        await task.value
    }
}

// MARK: - Quarantine activity tracker

private final class QuarantineActivity: @unchecked Sendable {
    private let lock = NSLock()
    private var _lastEvent: Date = .distantPast
    private var _finished = false
    private var _chunkCount = 0

    var lastEvent: Date { lock.withLock { _lastEvent } }
    var finished: Bool { lock.withLock { _finished } }
    var sawChunks: Bool { lock.withLock { _chunkCount > 0 } }
    var chunkCount: Int { lock.withLock { _chunkCount } }

    func reset() {
        lock.withLock {
            _lastEvent = Date()
            _finished = false
            _chunkCount = 0
        }
    }

    func noteChunk(_ chunk: String) {
        lock.withLock {
            _lastEvent = Date()
            _chunkCount &+= 1
            guard let data = chunk.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let finish = choices.first?["finish_reason"] as? String,
                  finish == "stop"
            else { return }
            _finished = true
        }
    }
}
