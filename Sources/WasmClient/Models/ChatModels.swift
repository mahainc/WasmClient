import Foundation

// MARK: - Chat

extension WasmClient {
    public enum ChatRole: String, Sendable {
        case system
        case user
        case assistant
        case tool
    }

    public struct ChatMessage: Sendable, Equatable, Identifiable {
        public let id: UUID
        public let role: ChatRole
        public let content: String
        public let toolCalls: [ToolCall]
        public let toolCallID: String
        public let contentParts: [ContentPart]
        public let annotations: [Annotation]

        public init(
            id: UUID = UUID(),
            role: ChatRole = .user,
            content: String = "",
            toolCalls: [ToolCall] = [],
            toolCallID: String = "",
            contentParts: [ContentPart] = [],
            annotations: [Annotation] = []
        ) {
            self.id = id
            self.role = role
            self.content = content
            self.toolCalls = toolCalls
            self.toolCallID = toolCallID
            self.contentParts = contentParts
            self.annotations = annotations
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

    public struct ChatTool: Sendable, Equatable {
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

    /// Describes a single AI model row returned by the `listModels` action.
    /// `id` disambiguates by provider — different providers may expose the
    /// same `modelId` (e.g. OpenAI default and a relay both expose
    /// `gpt-4o-mini`).
    public struct ChatModelInfo: Sendable, Equatable, Identifiable {
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

    /// Input parameters for `createChatModel`. Only `name`/`title`/
    /// `description`/`greeting` are mandatory strings; `image`, `gender`,
    /// `tone`, `categories`, `traits` are optional and omitted from the
    /// engine call when empty. `visibility` defaults to `"PUBLIC"` and
    /// must be one of `"PUBLIC" | "PRIVATE" | "UNLISTED"`.
    public struct CreateChatModelInput: Sendable, Equatable {
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
    public struct ChatConfig: Sendable, Equatable {
        public let model: String
        public let endpoint: String
        public let apiKey: String
        public let systemPrompt: String
        public let tools: [ChatTool]
        /// Pin chat to a specific provider — pass `ChatModelInfo.providerId`
        /// so the chat (and any provider-side state like a CAI replay
        /// buffer used by `readOutLoud`) lives on the same provider as the
        /// selected model. Empty string falls back to first-match.
        public let providerId: String
        /// OpenAI `tool_choice` — `"auto"` (default), `"required"` (force the
        /// model to call some tool), `"none"`, or a specific function name. Only
        /// emitted into the request body when non-empty AND `tools` is non-empty.
        public let toolChoice: String

        public init(
            model: String = "gpt-4o-mini",
            endpoint: String = "",
            apiKey: String = "",
            systemPrompt: String = "",
            tools: [ChatTool] = [],
            providerId: String = "",
            toolChoice: String = ""
        ) {
            self.model = model
            self.endpoint = endpoint
            self.apiKey = apiKey
            self.systemPrompt = systemPrompt
            self.tools = tools
            self.providerId = providerId
            self.toolChoice = toolChoice
        }
    }
}
