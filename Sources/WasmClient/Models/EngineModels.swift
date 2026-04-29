import Foundation

extension WasmClient {
    /// FlowKit release shipped with the app (keep in sync with
    /// `flowKitVersion` in `Package.swift`). Feed this into
    /// `setExpectedVersionProvider` so the engine evicts stale wasm caches
    /// whenever the app upgrades to a new FlowKit bundle.
    public static let bundledFlowKitVersion: String = "1.2.16-26.1.1"

    /// Engine lifecycle state.
    public enum EngineState: Sendable, Equatable {
        case stopped
        case starting
        /// Engine is downloading a fresh wasm bundle. Associated value is the
        /// download progress in [0.0, 1.0]. Treated like `.starting` for UI
        /// purposes; surfaced separately so callers can show download progress.
        case updating(Double)
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
