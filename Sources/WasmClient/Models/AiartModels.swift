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

    /// Result of an AI art video generation request. Returned in two phases:
    /// `aiartVideoCreate` returns the initial state with `.processing` status
    /// and the `videoID` to poll. `aiartVideoStatus(videoID:)` returns the
    /// latest snapshot until `.completed` (with `videoURL`) or `.failed`.
    public struct AiartVideoResult: Sendable, Equatable {
        public let status: TaskStatus
        public let videoID: String
        public let videoURL: String
        public let styledImageURL: String
        public let audioURL: String
        public let prompt: String
        public let artStyle: String
        /// Generation progress 0.0–1.0 (updated during `.processing`).
        public let progress: Double
        public let metadata: [String: String]

        public init(
            status: TaskStatus = .completed,
            videoID: String = "",
            videoURL: String = "",
            styledImageURL: String = "",
            audioURL: String = "",
            prompt: String = "",
            artStyle: String = "",
            progress: Double = 0,
            metadata: [String: String] = [:]
        ) {
            self.status = status
            self.videoID = videoID
            self.videoURL = videoURL
            self.styledImageURL = styledImageURL
            self.audioURL = audioURL
            self.prompt = prompt
            self.artStyle = artStyle
            self.progress = progress
            self.metadata = metadata
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

    /// One entry from an aiart action's `metadata.model_infos` list — a
    /// provider-specific image-generation model surfaced by the plugin. The
    /// `id` is the value sent back as the `model` arg on `aiartGenerate`.
    public struct AiartModelInfo: Sendable, Equatable, Identifiable {
        public var id: String { modelID }
        public let modelID: String
        public let name: String
        public let ownedBy: String
        public let vision: Bool
        public let isPro: Bool

        public init(
            modelID: String,
            name: String = "",
            ownedBy: String = "",
            vision: Bool = false,
            isPro: Bool = false
        ) {
            self.modelID = modelID
            self.name = name.isEmpty ? modelID : name
            self.ownedBy = ownedBy
            self.vision = vision
            self.isPro = isPro
        }
    }

    /// The model catalog for an aiart action: the list parsed from
    /// `metadata.model_infos` plus the plugin's `metadata.default_model`.
    /// `models` is empty when the provider exposes a single fixed model — the
    /// caller should hide the model picker in that case (mirrors
    /// flow-kit-example's `availableModels` / `defaultModelId`).
    public struct AiartModelCatalog: Sendable, Equatable {
        public let models: [AiartModelInfo]
        public let defaultModelID: String?

        public init(models: [AiartModelInfo] = [], defaultModelID: String? = nil) {
            self.models = models
            self.defaultModelID = defaultModelID
        }
    }
}
