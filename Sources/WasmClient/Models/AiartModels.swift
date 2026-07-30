import Foundation

// MARK: - AI Art Namespace

extension WasmClient {
    /// Namespace for all AI-art types: generation modes, styles, image and
    /// video results, and per-mode model discovery. Access via
    /// `WasmClient.AIArt.Result`, `WasmClient.AIArt.Mode.modCar`, etc.
    public enum AIArt {}
}

// MARK: - Mode

extension WasmClient.AIArt {
    /// AI-art generation mode. `rawValue` IS the wire string sent as the
    /// `mode` arg to the `ListModels` rpc. A struct (not an enum) so an
    /// unrecognized value from a newer backend round-trips losslessly
    /// without an `.UNRECOGNIZED` case, and callers can extend it.
    public struct Mode: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// General image generation/editing models.
        public static let normal = Mode(rawValue: "NORMAL")
        /// Stamp / postage-style image generation.
        public static let stamps = Mode(rawValue: "STAMPS")
        /// Car redesign image editing (aka "Mod Car").
        public static let modCar = Mode(rawValue: "MOD_CAR")
        /// Video generation models.
        public static let video = Mode(rawValue: "VIDEO")
    }
}

// MARK: - Style

extension WasmClient.AIArt {
    /// Visual style preset. `rawValue` is the wire string (matches the
    /// `AiartStyle` proto name and the values surfaced by `aiartStyles`).
    /// A struct (not an enum) so a style the backend adds later round-trips
    /// losslessly and callers can define their own.
    public struct Style: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static let anime = Style(rawValue: "ANIME")
        public static let cyberpunk = Style(rawValue: "CYBERPUNK")
        public static let watercolor = Style(rawValue: "WATERCOLOR")
        public static let pixelArt = Style(rawValue: "PIXEL_ART")
        public static let threeDCartoon = Style(rawValue: "THREE_D_CARTOON")
        public static let fantasy = Style(rawValue: "FANTASY")
        public static let oilPainting = Style(rawValue: "OIL_PAINTING")
        public static let lineArt = Style(rawValue: "LINE_ART")
        public static let minimal = Style(rawValue: "MINIMAL")
        public static let photoreal = Style(rawValue: "PHOTOREAL")
        public static let postage = Style(rawValue: "POSTAGE")
        public static let vintagePostage = Style(rawValue: "VINTAGE_POSTAGE")
        public static let waxSeal = Style(rawValue: "WAX_SEAL")
        public static let rubberStamp = Style(rawValue: "RUBBER_STAMP")
        public static let engraved = Style(rawValue: "ENGRAVED")
        public static let botanicalPostage = Style(rawValue: "BOTANICAL_POSTAGE")
    }
}

// MARK: - Method

extension WasmClient.AIArt {
    /// FlowKit AiartService rpc method name. The wasm dispatcher routes by
    /// method name (selecting the provider via the persisted
    /// `provider_strategy`), so no per-action UUID discovery is needed.
    /// Mirrors flow-kit-example's `AiartMethod`. A struct (not an enum) for
    /// the same forward-compatibility reason as `Mode` / `Style`.
    public struct Method: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// Per-mode model discovery (`AiartService/ListModels`).
        public static let listModels = Method(rawValue: "asyncify.aiart.AiartService/ListModels")
    }
}

// MARK: - Result

extension WasmClient.AIArt {
    /// Result of an AI art image generation request.
    public struct Result: Sendable, Equatable {
        public let images: [Image]
        public let prompt: String
        public let style: Style
        public let aspectRatio: String
        public let width: Int
        public let height: Int
        public let providerTaskID: String

        public init(
            images: [Image] = [],
            prompt: String = "",
            style: Style = Style(rawValue: ""),
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
    public struct VideoResult: Sendable, Equatable {
        public let status: WasmClient.TaskStatus
        public let videoID: String
        public let videoURL: String
        public let styledImageURL: String
        public let audioURL: String
        public let prompt: String
        /// Display name of the applied art style (free-form, e.g. "Ghibli").
        public let artStyle: String
        /// Generation progress 0.0–1.0 (updated during `.processing`).
        public let progress: Double
        public let metadata: [String: String]

        public init(
            status: WasmClient.TaskStatus = .completed,
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
    public struct Image: Sendable, Equatable, Identifiable {
        public let id: UUID
        public let url: String

        public init(
            id: UUID = UUID(),
            url: String = ""
        ) {
            self.id = id
            self.url = url
        }
    }
}

// MARK: - Model Discovery

extension WasmClient.AIArt {
    /// A single model row returned by per-mode model discovery
    /// (`aiartListModels`). `providerID` pins the follow-up generate call to
    /// the model's owning plugin; `aspectRatios` are the ratios the model
    /// actually accepts, so the UI can filter its ratio picker.
    public struct Model: Sendable, Equatable, Identifiable {
        public let id: String
        public let name: String
        public let providerID: String
        public let aspectRatios: [String]

        public init(
            id: String,
            name: String = "",
            providerID: String = "",
            aspectRatios: [String] = []
        ) {
            self.id = id
            self.name = name.isEmpty ? id : name
            self.providerID = providerID
            self.aspectRatios = aspectRatios
        }
    }

    /// The per-mode model catalogue plus the suggested default model id, so a
    /// picker can pre-select without an extra call. Mirrors the
    /// `AiartService/ListModels` response.
    public struct ModelList: Sendable, Equatable {
        public let models: [Model]
        public let defaultModelID: String

        public init(
            models: [Model] = [],
            defaultModelID: String = ""
        ) {
            self.models = models
            self.defaultModelID = defaultModelID
        }
    }
}
