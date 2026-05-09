@preconcurrency import Combine
@preconcurrency import FlowKit
import Foundation
import WasmClient

// MARK: - Pending Tasks

extension WasmActor {

    /// Snapshot every persisted task descriptor in the engine's default cache.
    /// Backed by `TaskWasmEngine.listPendingTasks` — works even before the
    /// engine has started, since descriptors are read off disk.
    func listPendingTasks() async -> [WasmClient.PendingTask] {
        let summaries = TaskWasmEngine.listPendingTasks(
            cacheDir: TaskWasmEngine.defaultCacheDir
        )
        return summaries.map(Self.mapPendingTask)
    }

    /// Bridge `pendingTasksChanged` (Combine `PassthroughSubject<Void, Never>`)
    /// into an `AsyncStream`. Yields the current snapshot synchronously, then
    /// re-reads + yields whenever the engine's auto-resume loop or any caller
    /// mutates a descriptor. Iterating the publisher's `.values` keeps us off
    /// the main actor and inherits `Task` cancellation.
    func observePendingTasks() async -> AsyncStream<[WasmClient.PendingTask]> {
        AsyncStream { continuation in
            let task = Task { [logger] in
                let initial = TaskWasmEngine.listPendingTasks(
                    cacheDir: TaskWasmEngine.defaultCacheDir
                )
                continuation.yield(initial.map(Self.mapPendingTask))

                do {
                    let engine = try await readyEngine()
                    guard let taskEngine = engine as? TaskWasmEngine else {
                        logger("observePendingTasks: engine is not TaskWasmEngine — finishing")
                        continuation.finish()
                        return
                    }

                    for await _ in taskEngine.pendingTasksChanged.values {
                        if Task.isCancelled { break }
                        let snapshot = TaskWasmEngine.listPendingTasks(
                            cacheDir: TaskWasmEngine.defaultCacheDir
                        )
                        continuation.yield(snapshot.map(Self.mapPendingTask))
                    }
                } catch {
                    logger("observePendingTasks: engine start failed — \(error.localizedDescription)")
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Remove a single persisted task descriptor by ID. Pass-through to
    /// `TaskWasmEngine.removePendingDescriptor`.
    func removePendingTask(taskID: String) async {
        TaskWasmEngine.removePendingDescriptor(
            taskID: taskID,
            cacheDir: TaskWasmEngine.defaultCacheDir
        )
    }

    /// Wipe every persisted task descriptor in the default cache. Mirrors
    /// flow-kit-example's "Clear all" pending-tasks toolbar action.
    func clearPendingTasks() async {
        TaskWasmEngine.removeAllPendingDescriptors(
            cacheDir: TaskWasmEngine.defaultCacheDir
        )
    }

    // MARK: - Mapping

    static func mapPendingTask(_ summary: PendingTaskSummary) -> WasmClient.PendingTask {
        let status: WasmClient.TaskStatus
        switch summary.statusString?.uppercased() {
        case "COMPLETED":
            status = .completed
        case "ERRORED", "ERROR", "FAILED":
            let message = summary.metadata["error"] ?? summary.statusString ?? ""
            status = .failed(message)
        default:
            // QUEUED / PROCESSING / nil all surface as in-flight to the UI.
            status = .processing
        }
        return WasmClient.PendingTask(
            id: summary.id,
            provider: summary.provider,
            providerName: summary.providerName,
            actionID: summary.actionID,
            status: status,
            progress: summary.progress,
            resultURL: summary.resultURL,
            cacheDir: summary.cacheDir,
            metadata: summary.metadata,
            createdAt: summary.createdAt,
            updatedAt: summary.updatedAt
        )
    }
}
