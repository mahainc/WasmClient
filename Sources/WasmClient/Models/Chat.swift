import Foundation

// MARK: - Chat Namespace

extension WasmClient {
    public enum Chat {}
}

// MARK: - Method

extension WasmClient.Chat {
    public struct Method: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static let providerInit = Self(rawValue: "asyncify.openai.OpenAIService/Init")
        public static let chat = Self(rawValue: "asyncify.openai.OpenAIService/Chat")
        public static let completion = Self(rawValue: "asyncify.openai.OpenAIService/Completion")
        public static let suggest = Self(rawValue: "asyncify.openai.OpenAIService/Suggest")
        public static let listModels = Self(rawValue: "asyncify.openai.OpenAIService/ListModels")
        public static let listProviders = Self(rawValue: "asyncify.openai.OpenAIService/ListProviders")
        public static let createModel = Self(rawValue: "asyncify.openai.OpenAIService/CreateModel")
        public static let tts = Self(rawValue: "asyncify.openai.OpenAIService/Tts")
        public static let auth = Self(rawValue: "asyncify.openai.OpenAIService/Auth")
        public static let createVoice = Self(rawValue: "asyncify.openai.OpenAIService/CreateVoice")
        public static let deleteVoice = Self(rawValue: "asyncify.openai.OpenAIService/DeleteVoice")
        public static let listVoices = Self(rawValue: "asyncify.openai.OpenAIService/ListVoices")
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
    public struct ModelInfo: Sendable, Equatable, Identifiable {
        public var id: String { "\(providerID)::\(modelID)" }
        public let modelID: String
        public let name: String
        public let ownedBy: String
        public let isPro: Bool
        public let vision: Bool
        public let voices: [String]
        public let greetings: [String]
        public let image: String
        public let interactions: Int
        public let description: String
        public let tags: [String]
        public let providerID: String
        public let providerName: String

        public init(
            modelID: String,
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
            providerID: String = "",
            providerName: String = ""
        ) {
            self.modelID = modelID
            self.name = name.isEmpty ? modelID : name
            self.ownedBy = ownedBy
            self.isPro = isPro
            self.vision = vision
            self.voices = voices
            self.greetings = greetings
            self.image = image
            self.interactions = interactions
            self.description = description
            self.tags = tags
            self.providerID = providerID
            self.providerName = providerName
        }
    }

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

    public struct Config: Sendable, Equatable {
        public let model: String
        public let endpoint: String
        public let apiKey: String
        public let systemPrompt: String
        public let tools: [Tool]
        public let providerID: String

        public init(
            model: String = "gpt-4o-mini",
            endpoint: String = "",
            apiKey: String = "",
            systemPrompt: String = "",
            tools: [Tool] = [],
            providerID: String = ""
        ) {
            self.model = model
            self.endpoint = endpoint
            self.apiKey = apiKey
            self.systemPrompt = systemPrompt
            self.tools = tools
            self.providerID = providerID
        }
    }
}

// MARK: - Voice Catalogue

extension WasmClient.Chat {
    public struct VoiceGender: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }

        public static let unspecified = VoiceGender(rawValue: "")
        public static let male = VoiceGender(rawValue: "MALE")
        public static let female = VoiceGender(rawValue: "FEMALE")
        public static let neutral = VoiceGender(rawValue: "NEUTRAL")
    }

    public struct VoiceVisibility: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }

        public static let unspecified = VoiceVisibility(rawValue: "")
        public static let publicVisibility = VoiceVisibility(rawValue: "PUBLIC")
        public static let privateVisibility = VoiceVisibility(rawValue: "PRIVATE")
        public static let unlisted = VoiceVisibility(rawValue: "UNLISTED")
    }

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
