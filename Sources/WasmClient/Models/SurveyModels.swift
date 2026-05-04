import Foundation

// MARK: - Survey

extension WasmClient {
    /// Question interaction style for UI rendering.
    public enum SurveyQuestionType: String, Sendable, Equatable, Codable {
        case text
        case single
        case multiple
        case rating
        case boolean
    }

    /// A single survey question.
    public struct SurveyQuestion: Sendable, Equatable, Identifiable {
        public let id: String
        public let text: String
        public let type: SurveyQuestionType
        public let options: [String]?

        public init(id: String, text: String, type: SurveyQuestionType, options: [String]? = nil) {
            self.id = id
            self.text = text
            self.type = type
            self.options = options
        }
    }
}
