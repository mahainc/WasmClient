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
        public let id: String
        public let provider: String
        public let name: String

        public init(id: String, provider: String = "", name: String = "") {
            self.id = id
            self.provider = provider
            self.name = name
        }
    }
}
