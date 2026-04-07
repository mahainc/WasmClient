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

    /// Describes a single AI model available from a chat provider.
    /// Parsed from the WASM action's `model_infos` metadata.
    public struct ChatModelInfo: Sendable, Equatable, Identifiable {
        public let id: String
        public let name: String
        public let isPro: Bool
        public let imageSupport: Bool
        public let enumId: Int

        public init(
            id: String,
            name: String = "",
            isPro: Bool = false,
            imageSupport: Bool = true,
            enumId: Int = 0
        ) {
            self.id = id
            self.name = name.isEmpty ? id : name
            self.isPro = isPro
            self.imageSupport = imageSupport
            self.enumId = enumId
        }
    }

    /// Configuration for creating a chat session.
    public struct ChatConfig: Sendable, Equatable {
        public let model: String
        public let endpoint: String
        public let apiKey: String
        public let systemPrompt: String
        public let tools: [ChatTool]

        public init(
            model: String = "gpt-4o-mini",
            endpoint: String = "",
            apiKey: String = "",
            systemPrompt: String = "",
            tools: [ChatTool] = []
        ) {
            self.model = model
            self.endpoint = endpoint
            self.apiKey = apiKey
            self.systemPrompt = systemPrompt
            self.tools = tools
        }
    }
}
