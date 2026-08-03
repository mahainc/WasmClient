import Foundation

extension WasmClient {
    public struct PendingTask: Sendable, Equatable, Hashable, Identifiable {
        public let id: String
        public let provider: String
        public let providerName: String?
        public let actionID: String?
        public let status: TaskStatus
        public let progress: Double
        public let resultURL: String?
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

        public var isVideoTask: Bool {
            actionID == ActionID.aiartVideo.rawValue
        }
    }
}
