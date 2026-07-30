import CoreGraphics
import Foundation

// MARK: - Inpaint Namespace

extension WasmClient {
    /// Namespace for all inpaint types: auto-suggestion object segments, a
    /// single detected segment, and erase/inpaint results. Access via
    /// `WasmClient.Inpaint.ObjectSegments`, etc.
    ///
    /// Note: task processing status is the cross-domain `WasmClient.TaskStatus`
    /// (declared in `CommonModels.swift`, shared with AIArt / HomeDecor /
    /// pending tasks), NOT an inpaint-scoped type.
    public enum Inpaint {}
}

// MARK: - Method

extension WasmClient.Inpaint {
    /// FlowKit InpaintService rpc method names. The wasm dispatcher can route
    /// by method name (selecting the provider via the persisted
    /// `provider_strategy`). Mirrors flow-kit-example's `InpaintMethod`
    /// (`inpaint.fk.pb.swift`). Reference/forward-compatibility: the live
    /// `InpaintSession` currently dispatches via UUID `ActionID` — this enum
    /// documents the method-name routes without changing that path.
    public enum Method: String, CaseIterable, Sendable {
        case autoSuggestion = "asyncify.inpaint.InpaintService/AutoSuggestion"
        case enhance = "asyncify.inpaint.InpaintService/Enhance"
        case removeBg = "asyncify.inpaint.InpaintService/RemoveBg"
        case erase = "asyncify.inpaint.InpaintService/Erase"
        case skinBeauty = "asyncify.inpaint.InpaintService/SkinBeauty"
        case sky = "asyncify.inpaint.InpaintService/Sky"
        case tryOn = "asyncify.inpaint.InpaintService/TryOn"
        case clothes = "asyncify.inpaint.InpaintService/Clothes"
    }
}

// MARK: - Result Types

extension WasmClient.Inpaint {
    /// Detected object segments from auto-suggestion.
    public struct ObjectSegments: Sendable, Equatable {
        public let sessionID: String
        public let segments: [Segment]
        public let suggestMask: String
        public let suggestObjectIds: String
        public let metadata: [String: String]

        public init(
            sessionID: String = "",
            segments: [Segment] = [],
            suggestMask: String = "",
            suggestObjectIds: String = "",
            metadata: [String: String] = [:]
        ) {
            self.sessionID = sessionID
            self.segments = segments
            self.suggestMask = suggestMask
            self.suggestObjectIds = suggestObjectIds
            self.metadata = metadata
        }
    }

    /// A single detected segment with bounding box and mask.
    public struct Segment: Sendable, Equatable, Identifiable {
        public let id: UUID
        public let bbox: CGRect
        public let maskURL: String
        public let metadata: [String: String]

        public init(
            id: UUID = UUID(),
            bbox: CGRect = .zero,
            maskURL: String = "",
            metadata: [String: String] = [:]
        ) {
            self.id = id
            self.bbox = bbox
            self.maskURL = maskURL
            self.metadata = metadata
        }
    }

    /// Result of an erase/inpaint operation.
    public struct EraseResult: Sendable, Equatable {
        public let sessionID: String
        public let imageURL: String
        public let maskURL: String
        public let metadata: [String: String]

        public init(
            sessionID: String = "",
            imageURL: String = "",
            maskURL: String = "",
            metadata: [String: String] = [:]
        ) {
            self.sessionID = sessionID
            self.imageURL = imageURL
            self.maskURL = maskURL
            self.metadata = metadata
        }
    }
}
