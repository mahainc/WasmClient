import Foundation

// MARK: - Notification

extension WasmClient {
    public enum Notification {}
}

extension WasmClient.Notification {
    // FlowKit UserService RPC method name (mirrors user.fk.pb.swift). Only the
    // method-name-dispatched operations live here; the UUID-action notification
    // operations route through `ActionID` instead.
    public struct ServiceMethod: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }

        public static let deleteUser = ServiceMethod(rawValue: "asyncify.user.UserService/DeleteUser")
    }

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
