import Foundation

// MARK: - AI Art

extension WasmClient {
    /// Result of an AI art generation request.
    public struct AiartResult: Sendable, Equatable {
        public let images: [AiartImage]
        public let prompt: String
        public let style: String
        public let aspectRatio: String
        public let width: Int
        public let height: Int
        public let providerTaskID: String

        public init(
            images: [AiartImage] = [],
            prompt: String = "",
            style: String = "",
            aspectRatio: String = "",
            width: Int = 0,
            height: Int = 0,
            providerTaskID: String = ""
        ) {
            self.images = images
            self.prompt = prompt
            self.style = style
            self.aspectRatio = aspectRatio
            self.width = width
            self.height = height
            self.providerTaskID = providerTaskID
        }
    }

    /// A single generated image from AI art.
    public struct AiartImage: Sendable, Equatable, Identifiable {
        public let id: UUID
        public let url: String

        public init(id: UUID = UUID(), url: String = "") {
            self.id = id
            self.url = url
        }
    }
}
