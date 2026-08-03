@preconcurrency import Combine
@preconcurrency import FlowKit
import Foundation
import WasmClient

final class SeenIDsBox: @unchecked Sendable {
    private let lock = NSLock()
    private var ids: Set<String>

    init(initial: [String]) { self.ids = Set(initial) }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return ids.count
    }

    func insert(_ id: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return ids.insert(id).inserted
    }
}

// MARK: - Pending Tasks

extension WasmActor {

    func ensurePendingTasksResumeLoop() async {
        guard !isResumingPendingTasks else { return }
        guard let engine = try? await readyEngine() as? TaskWasmEngine else { return }
        isResumingPendingTasks = true
        let log = logger
        Task { [weak self] in
            let resumed = await engine.resumePendingTasks(
                cacheDir: nil,
                interval: 5,
                timeout: 60 * 30,
                onUpdate: nil
            )
            log("resumePendingTasks finished — \(resumed.count) tasks settled")
            await self?.clearPendingTasksResumeFlag()
        }
    }

    func clearPendingTasksResumeFlag() {
        isResumingPendingTasks = false
    }

    func listPendingTasks() async -> [WasmClient.PendingTask] {
        let summaries = TaskWasmEngine.listPendingTasks(
            cacheDir: TaskWasmEngine.defaultCacheDir
        )
        return summaries.map(Self.mapPendingTask)
    }

    func observePendingTasks() async -> AsyncStream<[WasmClient.PendingTask]> {
        AsyncStream { continuation in
            let task = Task { [logger] in
                let snapshot: @Sendable () -> [WasmClient.PendingTask] = {
                    TaskWasmEngine.listPendingTasks(
                        cacheDir: TaskWasmEngine.defaultCacheDir
                    ).map(Self.mapPendingTask)
                }

                logger("observePendingTasks: defaultCacheDir=\(TaskWasmEngine.defaultCacheDir)")

                let initial = snapshot()
                logger("observePendingTasks: initial snapshot count=\(initial.count)")
                for (idx, task) in initial.enumerated() {
                    let statusLabel: String
                    switch task.status {
                        case .processing: statusLabel = "processing"
                        case .completed: statusLabel = "completed"
                        case .failed(let message): statusLabel = "failed(\(message))"
                    }
                    logger(
                        "  [\(idx)] id=\(task.id.prefix(8))… actionID=\(task.actionID ?? "nil") status=\(statusLabel) progress=\(task.progress) hasURL=\(task.resultURL != nil)"
                    )
                }
                continuation.yield(initial)

                let engine = try? await readyEngine()
                let taskEngine = engine as? TaskWasmEngine
                if taskEngine != nil {
                    let postReady = snapshot()
                    logger("observePendingTasks: post-engine snapshot count=\(postReady.count)")
                    continuation.yield(postReady)
                    await ensurePendingTasksResumeLoop()
                } else {
                    logger("observePendingTasks: engine unavailable — falling back to polling only")
                }

                // Hot subscription to descriptor change notifications.
                let combineTask = Task { [taskEngine, logger] in
                    guard let taskEngine else { return }
                    for await _ in taskEngine.pendingTasksChanged.values {
                        if Task.isCancelled { break }
                        let next = snapshot()
                        logger("observePendingTasks: change emission count=\(next.count)")
                        continuation.yield(next)
                    }
                }

                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(3))
                    if Task.isCancelled { break }
                    let next = snapshot()
                    logger("observePendingTasks: periodic poll count=\(next.count)")
                    continuation.yield(next)

                    let videoIDs = next.compactMap { task -> String? in
                        guard task.isVideoTask, case .processing = task.status else { return nil }
                        return task.id
                    }
                    for videoID in videoIDs {
                        Task { [weak self] in
                            _ = try? await self?.getAIArtVideoStatus(videoID: videoID)
                        }
                    }
                }
                combineTask.cancel()
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func observeTaskCreated() async -> AsyncStream<WasmClient.PendingTask> {
        AsyncStream { continuation in
            let task = Task { [logger] in
                let snapshot: @Sendable () -> [WasmClient.PendingTask] = {
                    TaskWasmEngine.listPendingTasks(
                        cacheDir: TaskWasmEngine.defaultCacheDir
                    ).map(Self.mapPendingTask)
                }

                let seenBox = SeenIDsBox(initial: snapshot().map(\.id))
                logger("observeTaskCreated: seeded with \(seenBox.count) existing IDs")

                let engine = try? await readyEngine()
                let taskEngine = engine as? TaskWasmEngine
                if taskEngine != nil {
                    await ensurePendingTasksResumeLoop()
                }

                let emitNew: @Sendable () -> Void = {
                    let next = snapshot()
                    for task in next where seenBox.insert(task.id) {
                        logger("observeTaskCreated: emitting new id=\(task.id.prefix(8))…")
                        continuation.yield(task)
                    }
                }

                emitNew()

                let combineTask = Task { [taskEngine] in
                    guard let taskEngine else { return }
                    for await _ in taskEngine.pendingTasksChanged.values {
                        if Task.isCancelled { break }
                        emitNew()
                    }
                }

                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(3))
                    if Task.isCancelled { break }
                    emitNew()
                }
                combineTask.cancel()
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func removePendingTask(taskID: String) async {
        TaskWasmEngine.removePendingDescriptor(
            taskID: taskID,
            cacheDir: TaskWasmEngine.defaultCacheDir
        )
    }

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
