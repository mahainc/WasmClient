import Foundation

// MARK: - Chat Namespace

extension WasmClient {
    /// Namespace for all chat (OpenAI-compatible) types: roles, messages and
    /// their parts, tools, model/provider info, voice catalogue, and the
    /// service method table. Access via `WasmClient.Chat.Message`,
    /// `WasmClient.Chat.Config`, etc.
    public enum Chat {}
}

// MARK: - Method

extension WasmClient.Chat {
    /// FlowKit OpenAIService rpc method names. The wasm dispatcher routes by
    /// method name, selecting the provider via the persisted
    /// `provider_strategy`. Mirrors flow-kit-example's `OpenAIMethod`
    /// (`openai.fk.pb.swift`).
    public enum Method: String, CaseIterable, Sendable {
        case providerInit = "asyncify.openai.OpenAIService/Init"
        case chat = "asyncify.openai.OpenAIService/Chat"
        case completion = "asyncify.openai.OpenAIService/Completion"
        case suggest = "asyncify.openai.OpenAIService/Suggest"
        case listModels = "asyncify.openai.OpenAIService/ListModels"
        case listProviders = "asyncify.openai.OpenAIService/ListProviders"
        case createModel = "asyncify.openai.OpenAIService/CreateModel"
        case tts = "asyncify.openai.OpenAIService/Tts"
        case auth = "asyncify.openai.OpenAIService/Auth"
        case createVoice = "asyncify.openai.OpenAIService/CreateVoice"
        case deleteVoice = "asyncify.openai.OpenAIService/DeleteVoice"
        case listVoices = "asyncify.openai.OpenAIService/ListVoices"
    }
}

// MARK: - Messages

extension WasmClient.Chat {
    public enum Role: String, Sendable {
        case system
        case user
        case assistant
        case tool
    }

    public struct Message: Sendable, Equatable, Identifiable {
        public let id: UUID
        public let role: Role
        public let content: String
        public let toolCalls: [ToolCall]
        public let toolCallID: String
        public let contentParts: [ContentPart]
        public let annotations: [Annotation]
        /// Model refusal message (OpenAI `refusal` field), empty when absent.
        public let refusal: String

        public init(
            id: UUID = UUID(),
            role: Role = .user,
            content: String = "",
            toolCalls: [ToolCall] = [],
            toolCallID: String = "",
            contentParts: [ContentPart] = [],
            annotations: [Annotation] = [],
            refusal: String = ""
        ) {
            self.id = id
            self.role = role
            self.content = content
            self.toolCalls = toolCalls
            self.toolCallID = toolCallID
            self.contentParts = contentParts
            self.annotations = annotations
            self.refusal = refusal
        }
    }

    public struct ContentPart: Sendable, Equatable {
        public let type: String
        public let text: String
        public let imageURL: String
        public let imageDetail: String

        public init(
            type: String = "text",
            text: String = "",
            imageURL: String = "",
            imageDetail: String = ""
        ) {
            self.type = type
            self.text = text
            self.imageURL = imageURL
            self.imageDetail = imageDetail
        }
    }

    public struct ToolCall: Sendable, Equatable, Identifiable {
        public let id: String
        public let type: String
        public let functionName: String
        public let functionArguments: String

        public init(
            id: String = "",
            type: String = "function",
            functionName: String = "",
            functionArguments: String = ""
        ) {
            self.id = id
            self.type = type
            self.functionName = functionName
            self.functionArguments = functionArguments
        }
    }

    public struct Tool: Sendable, Equatable {
        public let type: String
        public let functionName: String
        public let functionDescription: String
        public let parametersJSON: String
        public let strict: Bool

        public init(
            type: String = "function",
            functionName: String,
            functionDescription: String = "",
            parametersJSON: String = "{}",
            strict: Bool = false
        ) {
            self.type = type
            self.functionName = functionName
            self.functionDescription = functionDescription
            self.parametersJSON = parametersJSON
            self.strict = strict
        }
    }

    public struct Annotation: Sendable, Equatable {
        public let type: String
        public let url: String
        public let title: String
        public let startIndex: Int
        public let endIndex: Int

        public init(
            type: String = "",
            url: String = "",
            title: String = "",
            startIndex: Int = 0,
            endIndex: Int = 0
        ) {
            self.type = type
            self.url = url
            self.title = title
            self.startIndex = startIndex
            self.endIndex = endIndex
        }
    }
}

// MARK: - Model & Provider Info

extension WasmClient.Chat {
    /// Describes a single AI model row returned by the `listModels` action.
    /// `id` disambiguates by provider — different providers may expose the
    /// same `modelId` (e.g. OpenAI default and a relay both expose
    /// `gpt-4o-mini`).
    public struct ModelInfo: Sendable, Equatable, Identifiable {
        public var id: String { "\(providerId)::\(modelId)" }
        public let modelId: String
        public let name: String
        public let ownedBy: String
        public let isPro: Bool
        public let vision: Bool
        public let voices: [String]
        public let greetings: [String]
        public let image: String
        public let interactions: Int
        public let description: String
        /// Backend-supplied category tags. Drives the category-chip filter
        /// in consumer UIs without rebuilding the list locally.
        public let tags: [String]
        public let providerId: String
        public let providerName: String

        public init(
            modelId: String,
            name: String = "",
            ownedBy: String = "",
            isPro: Bool = false,
            vision: Bool = false,
            voices: [String] = [],
            greetings: [String] = [],
            image: String = "",
            interactions: Int = 0,
            description: String = "",
            tags: [String] = [],
            providerId: String = "",
            providerName: String = ""
        ) {
            self.modelId = modelId
            self.name = name.isEmpty ? modelId : name
            self.ownedBy = ownedBy
            self.isPro = isPro
            self.vision = vision
            self.voices = voices
            self.greetings = greetings
            self.image = image
            self.interactions = interactions
            self.description = description
            self.tags = tags
            self.providerId = providerId
            self.providerName = providerName
        }
    }

    /// A chat provider row returned by `listProviders`. `voiceCreatable`
    /// gates the voice-creation UI; `creatable` gates custom-model creation.
    public struct ProviderInfo: Sendable, Equatable, Identifiable {
        public let id: String
        public let name: String
        public let creatable: Bool
        public let voiceCreatable: Bool

        public init(
            id: String,
            name: String = "",
            creatable: Bool = false,
            voiceCreatable: Bool = false
        ) {
            self.id = id
            self.name = name.isEmpty ? id : name
            self.creatable = creatable
            self.voiceCreatable = voiceCreatable
        }
    }

    /// Input parameters for `createModel` (custom chat model). Only
    /// `name`/`title`/`description`/`greeting` are mandatory strings;
    /// `image`, `gender`, `tone`, `categories`, `traits` are optional and
    /// omitted from the engine call when empty. `visibility` defaults to
    /// `"PUBLIC"` and must be one of `"PUBLIC" | "PRIVATE" | "UNLISTED"`.
    public struct CreateModelInput: Sendable, Equatable {
        public let name: String
        public let title: String
        public let description: String
        public let greeting: String
        public let visibility: String
        public let image: String
        public let categories: [String]
        public let gender: String
        public let tone: String
        public let traits: [String]

        public init(
            name: String,
            title: String,
            description: String,
            greeting: String,
            visibility: String = "PUBLIC",
            image: String = "",
            categories: [String] = [],
            gender: String = "",
            tone: String = "",
            traits: [String] = []
        ) {
            self.name = name
            self.title = title
            self.description = description
            self.greeting = greeting
            self.visibility = visibility
            self.image = image
            self.categories = categories
            self.gender = gender
            self.tone = tone
            self.traits = traits
        }
    }

    /// Configuration for creating a chat session.
    public struct Config: Sendable, Equatable {
        public let model: String
        public let endpoint: String
        public let apiKey: String
        public let systemPrompt: String
        public let tools: [Tool]
        /// Pin chat to a specific provider — pass `ModelInfo.providerId`
        /// so the chat (and any provider-side state like a CAI replay
        /// buffer used by `readOutLoud`) lives on the same provider as the
        /// selected model. Empty string falls back to first-match.
        public let providerId: String

        public init(
            model: String = "gpt-4o-mini",
            endpoint: String = "",
            apiKey: String = "",
            systemPrompt: String = "",
            tools: [Tool] = [],
            providerId: String = ""
        ) {
            self.model = model
            self.endpoint = endpoint
            self.apiKey = apiKey
            self.systemPrompt = systemPrompt
            self.tools = tools
            self.providerId = providerId
        }
    }
}

// MARK: - Voice Catalogue

extension WasmClient.Chat {
    /// Voice gender tag. `rawValue` IS the wire string; a struct (not enum)
    /// so an unrecognized backend value round-trips losslessly.
    public struct VoiceGender: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }

        public static let unspecified = VoiceGender(rawValue: "")
        public static let male = VoiceGender(rawValue: "MALE")
        public static let female = VoiceGender(rawValue: "FEMALE")
        public static let neutral = VoiceGender(rawValue: "NEUTRAL")
    }

    /// Voice visibility. `rawValue` IS the wire string; struct for the same
    /// forward-compatibility reason as `VoiceGender`.
    public struct VoiceVisibility: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }

        public static let unspecified = VoiceVisibility(rawValue: "")
        public static let publicVisibility = VoiceVisibility(rawValue: "PUBLIC")
        public static let privateVisibility = VoiceVisibility(rawValue: "PRIVATE")
        public static let unlisted = VoiceVisibility(rawValue: "UNLISTED")
    }

    /// A voice preset returned by `listVoices` (paginated voice catalogue).
    public struct VoiceInfo: Sendable, Equatable, Identifiable {
        public let id: String
        public let name: String
        public let gender: VoiceGender
        public let visibility: VoiceVisibility
        public let previewAudioURL: String
        public let previewText: String
        public let providerID: String
        public let creatorID: String

        public init(
            id: String,
            name: String = "",
            gender: VoiceGender = .unspecified,
            visibility: VoiceVisibility = .unspecified,
            previewAudioURL: String = "",
            previewText: String = "",
            providerID: String = "",
            creatorID: String = ""
        ) {
            self.id = id
            self.name = name.isEmpty ? id : name
            self.gender = gender
            self.visibility = visibility
            self.previewAudioURL = previewAudioURL
            self.previewText = previewText
            self.providerID = providerID
            self.creatorID = creatorID
        }
    }

    /// A page of voices from `listVoices`, plus the backend-reported `total`
    /// (drives "load more"). Mirrors `OpenAIListVoicesResponse`.
    public struct VoiceList: Sendable, Equatable {
        public let voices: [VoiceInfo]
        public let total: Int

        public init(
            voices: [VoiceInfo] = [],
            total: Int = 0
        ) {
            self.voices = voices
            self.total = total
        }
    }
}
