import Foundation

// MARK: - Home Decor

extension WasmClient {
    /// Result of a home decor design generation.
    public struct HomedecorResult: Sendable, Equatable {
        public let status: TaskStatus
        public let imageURL: String
        public let inputImageURL: String
        public let taskID: String
        public let metadata: [String: String]

        public init(
            status: TaskStatus = .completed,
            imageURL: String = "",
            inputImageURL: String = "",
            taskID: String = "",
            metadata: [String: String] = [:]
        ) {
            self.status = status
            self.imageURL = imageURL
            self.inputImageURL = inputImageURL
            self.taskID = taskID
            self.metadata = metadata
        }
    }
}
