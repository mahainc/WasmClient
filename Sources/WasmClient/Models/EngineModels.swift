import Foundation

extension WasmClient {
    /// Engine lifecycle state.
    public enum EngineState: Sendable, Equatable {
        case stopped
        case starting
        case running
        case failed(String)
    }

    /// Lightweight action descriptor (no FlowKit types in interface).
    public struct ActionInfo: Sendable, Equatable, Identifiable {
        /// The action ID (shared across providers for the same action).
        public let actionID: String
        public let provider: String
        /// Unique identifier for `Identifiable` — combines actionID + provider.
        public var id: String { "\(actionID):\(provider)" }
        public let name: String
        public let providerName: String
        public let args: [ActionArg]
        public let sortedArgKeys: [String]

        public init(
            actionID: String, provider: String = "", name: String = "",
            providerName: String = "", args: [ActionArg] = [], sortedArgKeys: [String] = []
        ) {
            self.actionID = actionID
            self.provider = provider
            self.name = name
            self.providerName = providerName
            self.args = args
            self.sortedArgKeys = sortedArgKeys
        }
    }

    /// Describes a single argument of an action.
    public struct ActionArg: Sendable, Equatable, Identifiable {
        public var id: String { key }
        public let key: String
        public let name: String
        public let isRequired: Bool
        public let kind: ArgKind

        public init(key: String, name: String = "", isRequired: Bool = false, kind: ArgKind = .text(defaultValue: "")) {
            self.key = key
            self.name = name
            self.isRequired = isRequired
            self.kind = kind
        }

        public enum ArgKind: Sendable, Equatable {
            /// String arg with regex-extracted picker values and optional default.
            case picker(values: [String], defaultValue: String)
            /// Free-text string arg with optional default.
            case text(defaultValue: String)
            /// Media arg (file, mask, ref_image, image_url, mask_url).
            case media
        }
    }
}
