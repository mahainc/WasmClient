import Foundation

// MARK: - Notification

extension WasmClient {
    public enum Notification {}
}

extension WasmClient.Notification {
    public struct LiveActivityAttributesType: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }

    public struct Settings: Sendable, Equatable {
        public let enabled: Bool
        public let topics: [String]

        public init(
            enabled: Bool,
            topics: [String]
        ) {
            self.enabled = enabled
            self.topics = topics
        }
    }
}
