import Foundation

extension WasmClient {
    public static let bundledFlowKitVersion: String = "1.2.65-26.1.1-ffi"

    public struct EngineHandle: @unchecked Sendable {
        public let rawValue: Any

        public init(_ rawValue: Any) {
            self.rawValue = rawValue
        }

        public func value<T>(as type: T.Type = T.self) -> T? {
            rawValue as? T
        }
    }

    public enum EngineState: Sendable, Equatable {
        case stopped
        case starting
        case updating(Double)
        case running
        case failed(String)
    }

    public struct ActionInfo: Sendable, Equatable, Identifiable {
        public let actionID: String
        public let provider: String
        public var id: String { "\(actionID):\(provider)" }
        public let name: String
        public let providerName: String
        public let args: [ActionArg]
        public let sortedArgKeys: [String]

        public init(
            actionID: String,
            provider: String = "",
            name: String = "",
            providerName: String = "",
            args: [ActionArg] = [],
            sortedArgKeys: [String] = []
        ) {
            self.actionID = actionID
            self.provider = provider
            self.name = name
            self.providerName = providerName
            self.args = args
            self.sortedArgKeys = sortedArgKeys
        }
    }

    public struct ActionArg: Sendable, Equatable, Identifiable {
        public var id: String { key }
        public let key: String
        public let name: String
        public let isRequired: Bool
        public let kind: ArgKind

        public init(
            key: String,
            name: String = "",
            isRequired: Bool = false,
            kind: ArgKind = .text(defaultValue: "")
        ) {
            self.key = key
            self.name = name
            self.isRequired = isRequired
            self.kind = kind
        }

        public enum ArgKind: Sendable, Equatable {
            case picker(values: [String], defaultValue: String)
            case text(defaultValue: String)
            case media
        }
    }
}
