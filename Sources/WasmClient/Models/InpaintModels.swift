import CoreGraphics
import Foundation

// MARK: - Inpaint

extension WasmClient {
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

    /// Result of a try-on operation (may be processing).
    public struct TryOnResult: Sendable, Equatable {
        public let status: TaskStatus
        public let imageURL: String
        public let progress: Double

        public init(status: TaskStatus = .completed, imageURL: String = "", progress: Double = 1.0) {
            self.status = status
            self.imageURL = imageURL
            self.progress = progress
        }
    }

    /// Task processing status.
    public enum TaskStatus: Sendable, Equatable {
        case processing
        case completed
        case failed(String)
    }
}
