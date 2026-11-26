import Foundation

// MARK: - AI Art Namespace

extension WasmClient {
    public enum AIArt {}
}

// MARK: - Mode

extension WasmClient.AIArt {
    public struct Mode: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static let normal = Mode(rawValue: "NORMAL")
        public static let stamps = Mode(rawValue: "STAMPS")
        public static let modCar = Mode(rawValue: "MOD_CAR")
        public static let video = Mode(rawValue: "VIDEO")
    }
}

// MARK: - Style

extension WasmClient.AIArt {
    public struct Style: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static let unspecified = Style(rawValue: "")
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

// MARK: - Service Method

extension WasmClient.AIArt {
    public struct ServiceMethod: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static let listModels = ServiceMethod(
            rawValue: "asyncify.aiart.AiartService/ListModels"
        )
    }
}

// MARK: - Requests

extension WasmClient.AIArt {
    public protocol WireRequest: Sendable {
        var extraArgs: [String: String] { get set }
        func toWireArgs() -> [String: String]
    }

    public enum ImageReference: Sendable, Equatable, Hashable {
        case url(String)
        case path(String)
    }

    public struct ImageRequest: Sendable, Equatable, WireRequest {
        public var kind: Kind
        public var prompt: String
        public var style: Style
        public var image: ImageReference?
        public var model: Model?
        public var aspectRatio: String?
        public var numberOfImages: Int?
        public var extraArgs: [String: String]

        public init(
            kind: Kind = .normal,
            prompt: String,
            style: Style = .unspecified,
            image: ImageReference? = nil,
            model: Model? = nil,
            aspectRatio: String? = nil,
            numberOfImages: Int? = nil,
            extraArgs: [String: String] = [:]
        ) {
            self.kind = kind
            self.prompt = prompt
            self.style = style
            self.image = image
            self.model = model
            self.aspectRatio = aspectRatio
            self.numberOfImages = numberOfImages
            self.extraArgs = extraArgs
        }

        public func toWireArgs() -> [String: String] {
            var args: [String: String] = [:]
            if !prompt.isEmpty { args["prompt"] = prompt }
            if !style.rawValue.isEmpty { args["style"] = style.rawValue }
            switch image {
                case .url(let url) where !url.isEmpty:
                    args["image_url"] = url
                case .path(let path) where !path.isEmpty:
                    args["image_path"] = path
                default:
                    break
            }
            if let model, !model.id.isEmpty { args["model"] = model.id }
            if let aspectRatio, !aspectRatio.isEmpty { args["aspect_ratio"] = aspectRatio }
            if let numberOfImages, numberOfImages > 0 { args["num_images"] = String(numberOfImages) }
            for (key, value) in extraArgs where !value.isEmpty {
                args[key] = value
            }
            return args
        }
    }

    public struct VideoRequest: Sendable, Equatable, WireRequest {
        public var imagePath: String
        public var artStyle: String
        public var audioPath: String?
        public var extraArgs: [String: String]

        public init(
            imagePath: String,
            artStyle: String,
            audioPath: String? = nil,
            extraArgs: [String: String] = [:]
        ) {
            self.imagePath = imagePath
            self.artStyle = artStyle
            self.audioPath = audioPath
            self.extraArgs = extraArgs
        }

        public func toWireArgs() -> [String: String] {
            var args: [String: String] = [:]
            if !imagePath.isEmpty { args["image_path"] = imagePath }
            if !artStyle.isEmpty { args["art_style"] = artStyle }
            if let audioPath, !audioPath.isEmpty { args["audio_path"] = audioPath }
            for (key, value) in extraArgs where !value.isEmpty {
                args[key] = value
            }
            return args
        }
    }
}

extension WasmClient.AIArt.ImageRequest {
    public struct Kind: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static let normal = Kind(rawValue: "NORMAL")
        public static let stamp = Kind(rawValue: "STAMPS")
        public static let modCar = Kind(rawValue: "MOD_CAR")
    }
}

// MARK: - Results

extension WasmClient.AIArt {
    public struct ImageResult: Sendable, Equatable {
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
            style: Style = .unspecified,
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

    public struct VideoTaskSnapshot: Sendable, Equatable {
        public let status: WasmClient.TaskStatus
        public let videoID: String
        public let videoURL: String
        public let styledImageURL: String
        public let audioURL: String
        public let prompt: String
        public let artStyle: String
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
    public struct Model: Sendable, Equatable, Identifiable, Hashable {
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

    public struct ModelCatalog: Sendable, Equatable {
        public let models: [Model]
        public let defaultModelID: String

        public var defaultModel: Model? {
            models.first { $0.id == defaultModelID }
        }

        public init(
            models: [Model] = [],
            defaultModelID: String = ""
        ) {
            self.models = models
            self.defaultModelID = defaultModelID
        }
    }
}
