import Foundation

// MARK: - Survey

extension WasmClient {
    public enum Survey {}
}

extension WasmClient.Survey {
    public enum QuestionType: String, Sendable, Equatable, Codable {
        case text
        case single
        case multiple
        case rating
        case boolean
    }

    public struct Question: Sendable, Equatable, Identifiable {
        public let id: String
        public let text: String
        public let type: QuestionType
        public let options: [String]?

        public init(
            id: String,
            text: String,
            type: QuestionType,
            options: [String]? = nil
        ) {
            self.id = id
            self.text = text
            self.type = type
            self.options = options
        }
    }
}
