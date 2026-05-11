@preconcurrency import Combine
@preconcurrency import FlowKit
import Foundation
import WasmClient

// MARK: - Pending Tasks

extension WasmActor {

    /// Idempotently kick the engine's resume loop for every persisted
    /// descriptor in `defaultCacheDir`. The engine's own auto-resume only
    /// runs at boot for descriptors present at that time; this method
    /// ensures both in-session creates AND descriptors observed after boot
    /// (e.g. when the user opens Profile → Videos for the first time on a
    /// fresh launch) start receiving progress updates. Guarded so concurrent
    /// observers / creates don't fan out duplicate loops.
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

    /// Spawn a background `aiartVideoPoll` for `taskID` if one isn't already
    /// running. The loop calls `aiartVideoStatus` every `interval` seconds
    /// (default 5s, matching the engine's resume cadence). Each tick goes
    /// through `engine.status(task:)`, which rewrites the descriptor on disk
    /// and fires `pendingTasksChanged` — observers (Profile → Videos, the
    /// flow-kit-example PendingTasksView) react to that. The poller is
    /// detached from any `observePendingTasks` subscription, so it keeps
    /// running even when the user navigates away from the screen that
    /// kicked it. The loop exits naturally on `.completed` / `.failed`, or
    /// when `aiartVideoStatus` throws (network / auth) — `clearVideoPoller`
    /// removes the ID from the active set in either case.
    func ensureVideoPoll(taskID: String, interval: TimeInterval = 5) {
        guard !taskID.isEmpty else { return }
        guard !activeVideoPollers.contains(taskID) else { return }
        activeVideoPollers.insert(taskID)
        let log = logger
        Task { [weak self] in
            do {
                _ = try await self?.aiartVideoPoll(
                    videoID: taskID,
                    interval: interval,
                    onUpdate: nil
                )
                log("ensureVideoPoll: \(taskID.prefix(8))… settled")
            } catch is CancellationError {
                log("ensureVideoPoll: \(taskID.prefix(8))… cancelled")
            } catch {
                log("ensureVideoPoll: \(taskID.prefix(8))… exited error=\(error)")
            }
            await self?.clearVideoPoller(taskID)
        }
    }

    func clearVideoPoller(_ taskID: String) {
        activeVideoPollers.remove(taskID)
    }

    /// Convenience used by `observePendingTasks`: walk a snapshot and
    /// `ensureVideoPoll` every in-flight video task. Idempotent — duplicate
    /// calls for an already-active task ID are no-ops.
    func kickVideoPollers(for tasks: [WasmClient.PendingTask]) {
        for task in tasks where task.isVideoTask {
            guard case .processing = task.status else { continue }
            ensureVideoPoll(taskID: task.id)
        }
    }

    /// Snapshot every persisted task descriptor in the engine's default cache.
    /// Backed by `TaskWasmEngine.listPendingTasks` — works even before the
    /// engine has started, since descriptors are read off disk.
    func listPendingTasks() async -> [WasmClient.PendingTask] {
        let summaries = TaskWasmEngine.listPendingTasks(
            cacheDir: TaskWasmEngine.defaultCacheDir
        )
        return summaries.map(Self.mapPendingTask)
    }

    /// Stream descriptor snapshots driven by both the engine's
    /// `pendingTasksChanged` Combine subject AND a periodic re-read.
    /// Mirrors flow-kit-example's `PendingTasksView` which does both
    /// `.onAppear { refresh() }` and `.onReceive(pendingTasksChanged) { refresh() }`.
    ///
    /// The periodic poll (every 2s) is the reliable backstop: even if the
    /// Combine subject misses an emission or the engine doesn't fire it for
    /// in-session creates, the next tick re-reads the descriptor JSON from
    /// disk and yields. Each `aiartVideoStatus` / `resumePendingTasks` round
    /// trip rewrites the descriptor with fresh progress, so the polled
    /// snapshot picks up live progress.
    func observePendingTasks() async -> AsyncStream<[WasmClient.PendingTask]> {
        AsyncStream { continuation in
            let task = Task { [weak self, logger] in
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
                    case .failed(let m): statusLabel = "failed(\(m))"
                    }
                    logger("  [\(idx)] id=\(task.id.prefix(8))… actionID=\(task.actionID ?? "nil") status=\(statusLabel) progress=\(task.progress) hasURL=\(task.resultURL != nil)")
                }
                continuation.yield(initial)
                // Kick a per-task poller for every in-flight video found in
                // the initial snapshot — this is the only place we discover
                // descriptors persisted by a previous session.
                await self?.kickVideoPollers(for: initial)

                let engine = try? await self?.readyEngine()
                let taskEngine = engine as? TaskWasmEngine
                if let taskEngine {
                    let postReady = snapshot()
                    logger("observePendingTasks: post-engine snapshot count=\(postReady.count)")
                    continuation.yield(postReady)
                    await self?.kickVideoPollers(for: postReady)
                    // Kick the engine's resume loop so previously-persisted
                    // descriptors start receiving progress updates instead of
                    // sitting at their last-saved state.
                    await self?.ensurePendingTasksResumeLoop()
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

                // Periodic backstop: re-read the descriptor JSON every 3s.
                // Continuous per-video polling is owned by `ensureVideoPoll`
                // (kicked from the snapshots above + the create site), so
                // this loop only needs to surface descriptor changes the
                // Combine subject might have missed and re-kick any video
                // poller that exited prematurely while the task was still
                // processing.
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(3))
                    if Task.isCancelled { break }
                    let next = snapshot()
                    logger("observePendingTasks: periodic poll count=\(next.count)")
                    continuation.yield(next)
                    await self?.kickVideoPollers(for: next)
                }
                combineTask.cancel()
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
