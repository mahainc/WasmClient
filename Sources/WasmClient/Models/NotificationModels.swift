import Foundation

extension WasmClient {
    /// Server-side notification preferences for the current device.
    public struct NotificationSettings: Sendable, Equatable {
        public let enabled: Bool
        public let topics: [String]

        public init(enabled: Bool, topics: [String]) {
            self.enabled = enabled
            self.topics = topics
        }
    }
}
