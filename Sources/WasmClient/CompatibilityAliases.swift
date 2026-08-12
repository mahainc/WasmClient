import Foundation

// MARK: - Flat-name aliases (1.2.x → 3.x)

/// Temporary aliases so apps still on the pre-namespace Chat API compile
/// against WasmClient 3.x while migrating. Prefer `WasmClient.Chat.*` in new code.
extension WasmClient {
    public typealias ChatConfig = Chat.Config
    public typealias ChatMessage = Chat.Message
    public typealias ChatModelInfo = Chat.ModelInfo
    public typealias ContentPart = Chat.ContentPart
    public typealias Photo = Visual.Photo
    public typealias ObjectSegments = Inpaint.ObjectSegments
    public typealias Segment = Inpaint.Segment
}

extension WasmClient.Chat.ModelInfo {
    /// Legacy camelCase alias for `modelID`.
    public var modelId: String { modelID }
    /// Legacy camelCase alias for `providerID`.
    public var providerId: String { providerID }
}

extension WasmClient.Chat.Config {
    /// Legacy labeled init (`providerId:`) matching WasmClient 1.2.x call sites.
    public init(
        model: String = "gpt-4o-mini",
        endpoint: String = "",
        apiKey: String = "",
        systemPrompt: String = "",
        tools: [WasmClient.Chat.Tool] = [],
        providerId: String
    ) {
        self.init(
            model: model,
            endpoint: endpoint,
            apiKey: apiKey,
            systemPrompt: systemPrompt,
            tools: tools,
            providerID: providerId
        )
    }
}
