import Dependencies
import Foundation
import WasmClient

public actor ChatStreamSession {

    // MARK: - Public surface

    public enum Status: Sendable, Equatable {
        case streaming
        case completed
        case failed(String)
        case stopped
    }

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

    private var pendingSubscribers: [UUID: [UUID: AsyncStream<Event>.Continuation]] = [:]

    @Dependency(\.wasm) private var wasm

    public init() {}

    // MARK: - Public API

    public func start(
        conversationID: UUID,
        assistantMessageID: UUID,
        config: WasmClient.Chat.Config,
        history: [WasmClient.Chat.Message]
    ) {
        for (otherID, otherEntry) in streams where otherID != conversationID {
            guard otherEntry.status == .streaming else { continue }
            var stopped = otherEntry
            stopped.status = .stopped
            streams[otherID] = stopped
            broadcast(
                .stopped(assistantMessageID: stopped.assistantMessageID, text: stopped.accumulatedText),
                to: stopped.subscribers
            )
        }

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
            } catch {
                await self?.fail(conversationID: conversationID, message: error.localizedDescription)
            }
        }
        entry.task = task
        streams[conversationID] = entry
    }

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
    }

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

    public func snapshot(conversationID: UUID) -> Snapshot? {
        guard let entry = streams[conversationID] else { return nil }
        return Snapshot(
            assistantMessageID: entry.assistantMessageID,
            accumulatedText: entry.accumulatedText,
            status: entry.status
        )
    }

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
            // No stream yet — park the subscriber so the next `start()` picks it
            // up instead of `register` finishing the continuation prematurely.
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
        // Terminal status is surfaced as one event; the continuation stays open
        // so future `start()` calls in the same conversation keep flowing.
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
