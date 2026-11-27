import CoreGraphics
import Foundation

// MARK: - Inpaint Namespace

extension WasmClient {
    public enum Inpaint {}
}

// MARK: - Method

extension WasmClient.Inpaint {
    public struct Method: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static let autoSuggestion = Self(rawValue: "asyncify.inpaint.InpaintService/AutoSuggestion")
        public static let enhance = Self(rawValue: "asyncify.inpaint.InpaintService/Enhance")
        public static let removeBg = Self(rawValue: "asyncify.inpaint.InpaintService/RemoveBg")
        public static let erase = Self(rawValue: "asyncify.inpaint.InpaintService/Erase")
        public static let skinBeauty = Self(rawValue: "asyncify.inpaint.InpaintService/SkinBeauty")
        public static let sky = Self(rawValue: "asyncify.inpaint.InpaintService/Sky")
        public static let tryOn = Self(rawValue: "asyncify.inpaint.InpaintService/TryOn")
        public static let clothes = Self(rawValue: "asyncify.inpaint.InpaintService/Clothes")
    }
}

// MARK: - Result Types

extension WasmClient.Inpaint {
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

    public struct Segment: Sendable, Equatable, Identifiable {
        public let id: UUID
        /// The engine's own object id (the mask's `TypesImage.id`). This is the token
        /// `erase` expects in its comma-joined `maskObjects` list; empty when the engine
        /// did not tag the segment, in which case the caller substitutes its index.
        public let objectID: String
        public let bbox: CGRect
        public let maskURL: String
        public let metadata: [String: String]

        public init(
            id: UUID = UUID(),
            objectID: String = "",
            bbox: CGRect = .zero,
            maskURL: String = "",
            metadata: [String: String] = [:]
        ) {
            self.id = id
            self.objectID = objectID
            self.bbox = bbox
            self.maskURL = maskURL
            self.metadata = metadata
        }
    }

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
