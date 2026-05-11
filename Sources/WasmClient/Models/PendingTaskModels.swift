import Foundation

extension WasmClient {
    /// Snapshot of a task descriptor persisted by the engine. Mirrors
    /// FlowKit's `PendingTaskSummary` but keeps the interface target free of
    /// FlowKit/SwiftProtobuf types. Used by `listPendingTasks` /
    /// `observePendingTasks` to surface in-flight + recently completed work
    /// (e.g. video generations) so UI can render progress out-of-band of the
    /// originating screen.
    public struct PendingTask: Sendable, Equatable, Hashable, Identifiable {
        public let id: String
        public let provider: String
        public let providerName: String?
        public let actionID: String?
        public let status: TaskStatus
        /// Progress in [0.0, 1.0] reported by the engine. 0 when unknown.
        public let progress: Double
        /// Final result URL once the task reaches `.completed`. May be a
        /// remote URL or a local file path depending on the action.
        public let resultURL: String?
        /// Cache directory the descriptor lives in. Pass back to
        /// `removePendingTask` if the engine writes outside the default dir.
        public let cacheDir: String?
        public let metadata: [String: String]
        public let createdAt: Date?
        public let updatedAt: Date?

        public init(
            id: String,
            provider: String = "",
            providerName: String? = nil,
            actionID: String? = nil,
            status: TaskStatus = .processing,
            progress: Double = 0,
            resultURL: String? = nil,
            cacheDir: String? = nil,
            metadata: [String: String] = [:],
            createdAt: Date? = nil,
            updatedAt: Date? = nil
        ) {
            self.id = id
            self.provider = provider
            self.providerName = providerName
            self.actionID = actionID
            self.status = status
            self.progress = progress
            self.resultURL = resultURL
            self.cacheDir = cacheDir
            self.metadata = metadata
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }

        /// Convenience predicate for filtering Avatar FX video tasks.
        /// Exact match against the umbrella `aiartVideo` UUID — the
        /// sibling sub-action IDs (`-574001` aiartStamp, `-574002`
        /// aiartNormal, `-574003`) are *image* generation, not video, and
        /// `aiartVideoStatus` rejects them with `status="unspecified"`.
        public var isVideoTask: Bool {
            actionID == ActionID.aiartVideo.rawValue
        }
    }
}
