import Dependencies
import Foundation

/// Process-singleton actor that owns in-flight chat streams keyed by
/// conversation ID. Streaming Tasks live here, **not** in a consumer's store,
/// so a consumer tear-down (e.g. a `NavigationStack` pop) no longer cancels the
/// underlying WASM work. Re-opening the chat re-subscribes and replays the
/// accumulated text.
///
/// Lifecycle per conversation:
///   `start` → spawn Task that consumes `wasm.chatStream` → broadcast chunks to
///   all subscribers → terminal event on completion / failure / user stop.
///
/// WasmClient stays persistence-agnostic: this session accumulates text in
/// memory and broadcasts events. Consumers own persistence — subscribe to the
/// event stream (or read `snapshot`) and write to their own store.
public actor ChatStreamSession {

    // MARK: - Public surface

    public enum Status: Sendable, Equatable {
        case streaming
        case completed
        case failed(String)
        case stopped
    }

    /// Events emitted on the per-conversation broadcast stream.
    ///
    /// `.replay` is the synthetic snapshot late subscribers receive on attach
    /// and means "set the assistant bubble to this full text"; `.delta` is a
    /// live append. Every event carries `assistantMessageID` so the consumer
    /// can route to the right bubble even if its own streaming flag has been
    /// cleared by something else.
    public enum Event: Sendable, Equatable {
        case replay(assistantMessageID: UUID, text: String)
        case delta(assistantMessageID: UUID, chunk: String)
        case finished(assistantMessageID: UUID, text: String)
        case failed(assistantMessageID: UUID, message: String)
        case stopped(assistantMessageID: UUID, text: String)
    }

    public struct Snapshot: Sendable, Equatable {
        public let assistantMessageID: UUID
        public let accumulatedText: String
        public let status: Status

        public init(
            assistantMessageID: UUID,
            accumulatedText: String,
            status: Status
        ) {
            self.assistantMessageID = assistantMessageID
            self.accumulatedText = accumulatedText
            self.status = status
        }
    }

    // MARK: - State

    private struct ActiveStream {
        var assistantMessageID: UUID
        var accumulatedText: String
        var status: Status
        var task: Task<Void, Never>?
        var subscribers: [UUID: AsyncStream<Event>.Continuation]
    }

    private var streams: [UUID: ActiveStream] = [:]

    /// Subscribers that attached before any `start()` for a given conversation
    /// (e.g. a consumer wires the subscription before the user has sent
    /// anything). Parked here so `start()` can hand them their first events
    /// instead of `register` finishing the continuation prematurely.
    private var pendingSubscribers: [UUID: [UUID: AsyncStream<Event>.Continuation]] = [:]

    @Dependency(\.wasm) private var wasm

    public init() {}

    // MARK: - Public API

    /// Start (or replace) a stream for `conversationID`. If a stream is already
    /// active, its Task is cancelled and subscribers are transferred to the new
    /// one — matches "regenerate" semantics.
    public func start(
        conversationID: UUID,
        assistantMessageID: UUID,
        config: WasmClient.ChatConfig,
        history: [WasmClient.ChatMessage]
    ) {
        // Regenerate / replace: cancel the in-flight Task and transfer the
        // existing subscribers to the new entry so a subscriber that attached
        // before `start` keeps receiving events. We deliberately do NOT
        // broadcast `.stopped` here — that would finish the subscriber's
        // continuation, breaking the regenerate flow. The first `.delta` of
        // the new run is what the consumer uses to overwrite the bubble.
        if let existing = streams[conversationID] {
            existing.task?.cancel()
        }

        let existingSubscribers = streams[conversationID]?.subscribers ?? [:]
        let parked = pendingSubscribers.removeValue(forKey: conversationID) ?? [:]
        let mergedSubscribers = existingSubscribers.merging(parked) { _, parkedContinuation in
            parkedContinuation
        }
        var entry = ActiveStream(
            assistantMessageID: assistantMessageID,
            accumulatedText: "",
            status: .streaming,
            task: nil,
            subscribers: mergedSubscribers
        )
        streams[conversationID] = entry

        let task = Task { [weak self, wasm] in
            do {
                let stream = try await wasm.chatStream(config, history)
                for try await chunk in stream {
                    if Task.isCancelled { break }
                    await self?.appendChunk(conversationID: conversationID, chunk: chunk)
                }
                await self?.finish(conversationID: conversationID)
            } catch is CancellationError {
                // User-initiated stop or replace — `stop()` / `start()` already
                // handled the transition, so nothing to do here.
            } catch {
                await self?.fail(conversationID: conversationID, message: error.localizedDescription)
            }
        }
        entry.task = task
        streams[conversationID] = entry
    }

    /// User-initiated stop. Cancels the Task and emits `.stopped` with the
    /// partial text to every subscriber.
    public func stop(conversationID: UUID) async {
        guard var entry = streams[conversationID] else { return }
        entry.task?.cancel()
        entry.task = nil
        entry.status = .stopped
        let finalText = entry.accumulatedText
        streams[conversationID] = entry
        broadcast(
            .stopped(assistantMessageID: entry.assistantMessageID, text: finalText),
            to: entry.subscribers
        )
        // Keep the entry so a re-opened consumer can read the snapshot once.
    }

    /// Abandon the entry entirely — used when the underlying conversation is
    /// being deleted.
    public func discard(conversationID: UUID) {
        if let entry = streams[conversationID] {
            entry.task?.cancel()
            for (_, continuation) in entry.subscribers {
                continuation.finish()
            }
            streams.removeValue(forKey: conversationID)
        }
        if let parked = pendingSubscribers.removeValue(forKey: conversationID) {
            for (_, continuation) in parked {
                continuation.finish()
            }
        }
    }

    /// Non-blocking peek at the current state — used to backfill the assistant
    /// bubble before the subscription kicks in.
    public func snapshot(conversationID: UUID) -> Snapshot? {
        guard let entry = streams[conversationID] else { return nil }
        return Snapshot(
            assistantMessageID: entry.assistantMessageID,
            accumulatedText: entry.accumulatedText,
            status: entry.status
        )
    }

    /// Subscribe to per-conversation events. Returns a fresh stream that
    /// immediately replays the accumulated text as a single `.replay`, then
    /// forwards future events. If status is already terminal, emits the
    /// terminal event but keeps the continuation open for future runs.
    public func subscribe(conversationID: UUID) -> AsyncStream<Event> {
        AsyncStream<Event> { continuation in
            let subscriberID = UUID()
            Task { [weak self] in
                await self?.register(
                    conversationID: conversationID,
                    subscriberID: subscriberID,
                    continuation: continuation
                )
            }
            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in
                    await self?.unregister(
                        conversationID: conversationID,
                        subscriberID: subscriberID
                    )
                }
            }
        }
    }

    // MARK: - Internal: chunk plumbing

    private func appendChunk(
        conversationID: UUID,
        chunk: String
    ) {
        guard var entry = streams[conversationID] else { return }
        entry.accumulatedText.append(chunk)
        streams[conversationID] = entry

        broadcast(
            .delta(assistantMessageID: entry.assistantMessageID, chunk: chunk),
            to: entry.subscribers
        )
    }

    private func finish(conversationID: UUID) {
        guard var entry = streams[conversationID] else { return }
        entry.status = .completed
        entry.task = nil
        let finalText = entry.accumulatedText
        streams[conversationID] = entry
        broadcast(
            .finished(assistantMessageID: entry.assistantMessageID, text: finalText),
            to: entry.subscribers
        )
    }

    private func fail(
        conversationID: UUID,
        message: String
    ) {
        guard var entry = streams[conversationID] else { return }
        entry.status = .failed(message)
        entry.task = nil
        streams[conversationID] = entry
        broadcast(
            .failed(assistantMessageID: entry.assistantMessageID, message: message),
            to: entry.subscribers
        )
    }

    // MARK: - Internal: subscribers

    private func register(
        conversationID: UUID,
        subscriberID: UUID,
        continuation: AsyncStream<Event>.Continuation
    ) {
        guard var entry = streams[conversationID] else {
            // No stream yet — park the subscriber. The next `start()` will
            // pick it up. This avoids racing with `start()` when both are
            // dispatched together, and lets a consumer wire a subscription
            // before any send.
            var parked = pendingSubscribers[conversationID] ?? [:]
            parked[subscriberID] = continuation
            pendingSubscribers[conversationID] = parked
            return
        }
        entry.subscribers[subscriberID] = continuation
        streams[conversationID] = entry

        if !entry.accumulatedText.isEmpty {
            continuation.yield(
                .replay(assistantMessageID: entry.assistantMessageID, text: entry.accumulatedText)
            )
        }
        // Terminal statuses are surfaced as a single event so the consumer can
        // reconcile state. The continuation stays open so the subscriber keeps
        // receiving events from future `start()` calls in the same conversation
        // (next user turn / regenerate).
        switch entry.status {
            case .streaming:
                break
            case .completed:
                continuation.yield(
                    .finished(assistantMessageID: entry.assistantMessageID, text: entry.accumulatedText)
                )
            case .failed(let message):
                continuation.yield(
                    .failed(assistantMessageID: entry.assistantMessageID, message: message)
                )
            case .stopped:
                continuation.yield(
                    .stopped(assistantMessageID: entry.assistantMessageID, text: entry.accumulatedText)
                )
        }
    }

    private func unregister(
        conversationID: UUID,
        subscriberID: UUID
    ) {
        if var entry = streams[conversationID] {
            entry.subscribers.removeValue(forKey: subscriberID)
            streams[conversationID] = entry
        }
        if var parked = pendingSubscribers[conversationID] {
            parked.removeValue(forKey: subscriberID)
            if parked.isEmpty {
                pendingSubscribers.removeValue(forKey: conversationID)
            } else {
                pendingSubscribers[conversationID] = parked
            }
        }
    }

    private func broadcast(
        _ event: Event,
        to subscribers: [UUID: AsyncStream<Event>.Continuation]
    ) {
        // Terminal events are surfaced as data — the continuation itself stays
        // open so the same subscriber keeps receiving events when the user
        // sends the next message (next `start()` reuses these subscribers).
        for (_, continuation) in subscribers {
            continuation.yield(event)
        }
    }
}

// MARK: - Dependency Registration

extension ChatStreamSession: DependencyKey {
    public static let liveValue = ChatStreamSession()
    public static let testValue = ChatStreamSession()
}

extension DependencyValues {
    public var chatStreamSession: ChatStreamSession {
        get { self[ChatStreamSession.self] }
        set { self[ChatStreamSession.self] = newValue }
    }
}
