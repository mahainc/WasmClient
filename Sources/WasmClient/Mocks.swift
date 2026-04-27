import Dependencies
import Foundation

// MARK: - Dependency Registration

extension DependencyValues {
    public var wasm: WasmClient {
        get { self[WasmClient.self] }
        set { self[WasmClient.self] = newValue }
    }
}

// MARK: - Test Dependency Key

extension WasmClient: TestDependencyKey {
    public static let previewValue = Self.happy
    public static let testValue = Self()
}

// MARK: - Mock Constants

private enum MockConstants {
    static let warmUpDelay: UInt64 = 200_000_000
    static let shortDelay: UInt64 = 300_000_000
    static let mediumDelay: UInt64 = 500_000_000
    static let longDelay: UInt64 = 1_500_000_000
}

// MARK: - Mock Implementations

extension WasmClient {
    public static let happy = Self(
        start: {
            try? await Task.sleep(nanoseconds: MockConstants.warmUpDelay)
        },
        observeEngineState: {
            AsyncStream { continuation in
                continuation.yield(.starting)
                Task {
                    try? await Task.sleep(nanoseconds: MockConstants.warmUpDelay)
                    continuation.yield(.running)
                }
            }
        },
        reset: { },
        restart: {
            try? await Task.sleep(nanoseconds: MockConstants.warmUpDelay)
        },
        engineVersion: { "mock-1.2.3" },
        resetDownloads: { },
        setExpectedVersionProvider: { _ in },
        warmUp: {
            try? await Task.sleep(nanoseconds: MockConstants.warmUpDelay)
        },
        availableActions: {
            [
                ActionInfo(actionID: ActionID.chat.rawValue, provider: "openai", name: "Chat"),
                ActionInfo(actionID: ActionID.scan.rawValue, provider: "vision", name: "Scan"),
                ActionInfo(actionID: ActionID.livescore.rawValue, provider: "football", name: "Livescore"),
            ]
        },
        refreshActions: { },
        scan: { _, _, _ in
            try await Task.sleep(nanoseconds: MockConstants.longDelay)
            return ScanResult(
                title: "Mock Object",
                description: "A mock scan result for preview purposes.",
                categoryType: "object",
                characteristics: ["Color": "Blue", "Material": "Metal"],
                suggestedQuestions: ["What is this?", "Where can I buy it?"],
                price: PriceInfo(averageFairMarketPrice: "$29.99")
            )
        },
        describe: { _, _, _, _ in
            try await Task.sleep(nanoseconds: MockConstants.longDelay)
            return ScanResult(
                title: "Mock Object",
                description: "An enriched description with full details.",
                categoryType: "electronics",
                characteristics: ["Color": "Blue", "Material": "Metal", "Weight": "150g"],
                suggestedQuestions: ["What is this?", "Where can I buy it?"],
                price: PriceInfo(averageFairMarketPrice: "$29.99"),
                aiCommentary: AICommentary(
                    aiAssistantSays: "This appears to be a high-quality item.",
                    interestingFacts: "This type of product has been popular since 2020."
                )
            )
        },
        visualSearch: { _, _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return [
                ShoppingProduct(title: "Similar Item", price: "$19.99", url: "https://example.com/product"),
            ]
        },
        shopping: { _, _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return [
                ShoppingProduct(title: "Mock Product", price: "$24.99", url: "https://example.com/shop"),
            ]
        },
        uploadImage: { _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return "https://example.com/mock-image.jpg"
        },
        uploadFile: { _, _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return "https://example.com/mock-file.jpg"
        },
        chatModels: {
            (
                models: [
                    ChatModelInfo(id: "gpt-4o-mini", name: "GPT-4o mini", enumId: 1),
                    ChatModelInfo(id: "gpt-4o", name: "GPT-4o", isPro: true, enumId: 2),
                    ChatModelInfo(id: "gpt-4.1", name: "GPT-4.1", isPro: true, enumId: 3),
                ],
                defaultEnumId: 1
            )
        },
        chatSend: { _, _ in
            try await Task.sleep(nanoseconds: MockConstants.longDelay)
            return ChatMessage(role: .assistant, content: "Hello! How can I help you today?")
        },
        chatStream: { _, _ in
            AsyncThrowingStream { continuation in
                Task {
                    for word in ["Hello", "!", " How", " can", " I", " help", "?"] {
                        try await Task.sleep(nanoseconds: 50_000_000)
                        continuation.yield(word)
                    }
                    continuation.finish()
                }
            }
        },
        musicDiscover: { _, _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return MusicTrackList(items: [
                MusicTrackItem(id: "track-1", title: "Mock Song", kind: "song", authorName: "Mock Artist"),
            ])
        },
        musicDetails: { _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return MusicTrackDetail(
                id: "track-1", title: "Mock Song", description: "A great mock song",
                authorName: "Mock Artist", duration: 240, views: 1_000_000,
                formats: [MusicFormat(id: "f1", url: "https://example.com/audio.mp3", quality: "high", mimeType: "audio/mpeg")]
            )
        },
        musicTracks: { _, _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return MusicTrackList(items: [
                MusicTrackItem(id: "track-1", title: "Track One", kind: "song", authorName: "Artist A"),
                MusicTrackItem(id: "track-2", title: "Track Two", kind: "song", authorName: "Artist B"),
            ])
        },
        musicSearch: { _, _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return MusicTrackList(items: [
                MusicTrackItem(id: "track-1", title: "Search Result", kind: "song", authorName: "Mock Artist"),
            ])
        },
        musicLyrics: { _ in
            try await Task.sleep(nanoseconds: MockConstants.shortDelay)
            return [
                MusicLyricSegment(text: "Hello, world", offset: 0, duration: 3000),
                MusicLyricSegment(text: "This is a mock song", offset: 3000, duration: 4000),
            ]
        },
        musicRelated: { _, _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return MusicTrackList(items: [
                MusicTrackItem(id: "track-3", title: "Related Track", kind: "song", authorName: "Related Artist"),
            ])
        },
        musicSuggestions: { _ in
            try await Task.sleep(nanoseconds: MockConstants.shortDelay)
            return ["pop music", "rock classics", "jazz vibes"]
        },
        suggest: { _, _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return ["Tell me about this", "What can you help with?", "Explain this image", "Suggest improvements"]
        },
        aiartGenerate: { _, _ in
            try await Task.sleep(nanoseconds: MockConstants.longDelay)
            return AiartResult(
                images: [AiartImage(url: "https://example.com/aiart.png")],
                prompt: "A beautiful sunset",
                style: "watercolor",
                aspectRatio: "1:1",
                width: 1024,
                height: 1024
            )
        },
        aiartStyles: { _ in
            [
                "ANIME", "CYBERPUNK", "WATERCOLOR", "PIXEL_ART", "THREE_D_CARTOON",
                "FANTASY", "OIL_PAINTING", "LINE_ART", "MINIMAL", "PHOTOREAL",
            ]
        },
        searchPhotos: { _, _, _, _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return PhotoSearchResult(
                total: 100,
                totalPages: 5,
                results: [
                    Photo(
                        id: "photo-1", description: "A landscape photo",
                        width: 1920, height: 1080,
                        urls: PhotoUrls(small: "https://example.com/photo-sm.jpg", thumb: "https://example.com/photo-th.jpg"),
                        userName: "John Doe", likes: 42
                    ),
                ]
            )
        },
        photoVisualSearch: { _, _, _, _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return PhotoSearchResult(total: 10, totalPages: 1, results: [])
        },
        listMedia: { _, _, _, _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return PhotoSearchResult(total: 50, totalPages: 3, results: [])
        },
        homeDesign: { _, _ in
            try await Task.sleep(nanoseconds: MockConstants.longDelay)
            return HomedecorResult(
                imageURL: "https://example.com/redesigned-room.jpg",
                inputImageURL: "https://example.com/original-room.jpg",
                taskID: "mock-task-id"
            )
        },
        homeDesignStatus: { _, _ in
            HomedecorResult(
                imageURL: "https://example.com/redesigned-room.jpg",
                taskID: "mock-task-id"
            )
        },
        autoSuggestion: { _, _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return ObjectSegments(sessionID: "mock-session")
        },
        enhance: { _, _, _ in
            try await Task.sleep(nanoseconds: MockConstants.longDelay)
            return ObjectSegments(sessionID: "mock-session")
        },
        removeBackground: { _, _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return Segment(maskURL: "https://example.com/mask.png")
        },
        erase: { _, _, _, _, _ in
            try await Task.sleep(nanoseconds: MockConstants.longDelay)
            return EraseResult(sessionID: "mock-session", imageURL: "https://example.com/erased.jpg")
        },
        skinBeauty: { _, _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return ObjectSegments(sessionID: "mock-session")
        },
        sky: { _, _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return Segment(maskURL: "https://example.com/sky-mask.png")
        },
        categorizeClothes: { _, _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return ObjectSegments(sessionID: "mock-session")
        },
        tryOn: { _, _, _, _, _ in
            try await Task.sleep(nanoseconds: MockConstants.longDelay)
            return TryOnResult(status: .completed, imageURL: "https://example.com/tryon.jpg")
        },
        tryOnStatus: { _ in
            TryOnResult(status: .completed, imageURL: "https://example.com/tryon.jpg")
        },
        livescores: { _ in
            try await Task.sleep(nanoseconds: MockConstants.shortDelay)
            return [
                Fixture(id: "1", homeTeam: "Arsenal", awayTeam: "Chelsea", homeScore: 2, awayScore: 1, status: "FT"),
                Fixture(id: "2", homeTeam: "Liverpool", awayTeam: "Man City", homeScore: 0, awayScore: 0, status: "LIVE"),
            ]
        },
        fixtures: { _ in
            [Fixture(id: "1", homeTeam: "Arsenal", awayTeam: "Chelsea", status: "NS", date: "2026-03-25")]
        },
        fixture: { _ in
            [Fixture(id: "1", homeTeam: "Arsenal", awayTeam: "Chelsea", homeScore: 2, awayScore: 1, status: "FT")]
        },
        headToHead: { _, _ in
            [Fixture(id: "h2h-1", homeTeam: "Arsenal", awayTeam: "Chelsea", homeScore: 1, awayScore: 0, status: "FT")]
        },
        leagues: {
            [
                League(id: "39", name: "Premier League", country: "England", type: "League"),
                League(id: "140", name: "La Liga", country: "Spain", type: "League"),
            ]
        },
        searchLeagues: { _ in
            [League(id: "39", name: "Premier League", country: "England")]
        },
        standings: { _ in
            [Standing(rank: 1, teamID: "42", teamName: "Arsenal", points: 75, played: 30)]
        },
        searchTeams: { _ in
            [Team(id: "42", name: "Arsenal", logo: "https://example.com/arsenal.png", country: "England")]
        },
        team: { _ in
            [Team(id: "42", name: "Arsenal", logo: "https://example.com/arsenal.png", country: "England")]
        },
        searchPlayers: { _ in
            [Player(id: "1", name: "Bukayo Saka", position: "Attacker", nationality: "England")]
        },
        player: { _ in
            [Player(id: "1", name: "Bukayo Saka", position: "Attacker", nationality: "England")]
        },
        league: { _ in
            [League(id: "39", name: "Premier League", country: "England")]
        },
        topscorers: { _ in
            [Player(id: "1", name: "Erling Haaland", position: "Attacker", nationality: "Norway")]
        },
        predictions: { _ in Data() },
        odds: { _, _ in Data() },
        expectedGoals: { _, _ in Data() },
        news: { _, _ in Data() },
        highlights: { _, _ in
            [
                Highlight(
                    title: "Arsenal vs Chelsea Highlights",
                    videoURL: "https://example.com/video.mp4",
                    clips: [
                        HighlightClip(
                            id: "mock-clip-1",
                            title: "Full match highlights",
                            embed: "<iframe src=\"https://www.scorebat.com/embed/v/mock\" width=\"100%\" height=\"100%\" frameborder=\"0\" allowfullscreen allow=\"autoplay; fullscreen\" style=\"border:0;\"></iframe>"
                        ),
                    ]
                ),
            ]
        }
    )
}
