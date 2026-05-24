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
    /// Inert mock — every operation returns immediately with empty/default
    /// values and streams finish without emitting. Use as a baseline in tests
    /// and override only the operations exercised by the test under
    /// `withDependencies { $0.wasm = .noop; $0.wasm.scan = { ... } }`.
    public static let noop = Self(
        start: { },
        observeEngineState: { AsyncStream { $0.finish() } },
        reset: { },
        restart: { },
        engineVersion: { nil },
        resetDownloads: { },
        setExpectedVersionProvider: { _ in },
        setUserName: { _ in },
        warmUp: { },
        availableActions: { [] },
        refreshActions: { },
        scan: { _, _, _ in ScanResult() },
        describe: { _, _, _, _ in ScanResult() },
        visualSearch: { _, _ in [] },
        shopping: { _, _ in [] },
        uploadImage: { _ in "" },
        uploadFile: { _, _ in "" },
        chatModels: { _, _, _, _ in ([], 0) },
        chatSend: { _, _ in ChatMessage(role: .assistant, content: "") },
        chatStream: { _, _ in
            AsyncThrowingStream { $0.finish() }
        },
        createChatModel: { _, _ in "" },
        initializeChatProvider: { _, _ in },
        musicDiscover: { _, _ in MusicTrackList() },
        musicDetails: { _ in MusicTrackDetail() },
        musicTracks: { _, _ in MusicTrackList() },
        musicSearch: { _, _ in MusicTrackList() },
        musicLyrics: { _ in [] },
        musicRelated: { _, _ in MusicTrackList() },
        musicSuggestions: { _ in [] },
        suggest: { _, _ in [] },
        readOutLoud: { _, _, _ in .data(Data(), mime: "") },
        ttsVoices: { _, _ in [] },
        aiartGenerate: { _, _ in AiartResult() },
        aiartStyles: { _ in [] },
        aiartVideoCreate: { _ in AiartVideoResult(status: .processing) },
        aiartVideoStatus: { _ in AiartVideoResult() },
        aiartVideoPoll: { _, _, _ in AiartVideoResult() },
        listPendingTasks: { [] },
        observePendingTasks: { AsyncStream { $0.finish() } },
        observeTaskCreated: { AsyncStream { $0.finish() } },
        removePendingTask: { _ in },
        clearPendingTasks: { },
        searchPhotos: { _, _, _, _ in PhotoSearchResult() },
        photoVisualSearch: { _, _, _, _ in PhotoSearchResult() },
        listMedia: { _, _, _, _ in PhotoSearchResult() },
        homeDesign: { _, _ in HomeDecor.Result() },
        homeDesignStatus: { _, _ in HomeDecor.Result() },
        homeDesignRequest: { _, _ in HomeDecor.Result() },
        homeDecorStyles: { _ in [] },
        homeDecorRoomTypes: { _ in [] },
        homeDecorColorPalettes: { _ in [] },
        homeDecorSurfaceTypes: { _ in [] },
        homeDecorStyleSelections: { _ in [] },
        autoSuggestion: { _ in ObjectSegments() },
        enhance: { _, _ in ObjectSegments() },
        removeBackground: { _ in Segment() },
        erase: { _, _, _, _ in EraseResult() },
        skinBeauty: { _ in ObjectSegments() },
        sky: { _ in Segment() },
        categorizeClothes: { _ in Segment() },
        tryOn: { _, _ in "" },
        webpageLeagues: { [] },
        webpageCompetitions: { _, _, _ in [] },
        webpageTeams: { _, _, _, _ in [] },
        webpage: { _ in [] },
        webpageDiscovers: { [] },
        webpageCompetition: { _ in nil },
        webpageTeam: { _ in nil },
        webpageVideos: { _, _, _, _, _, _ in [] },
        webpageNews: { _, _, _, _, _ in [] },
        upcoming: { [] },
        scoresByDate: { _ in [] },
        matchDetail: { id in
            WasmClient.LiveScore.Match(
                summary: WasmClient.LiveScore.UpcomingMatch(
                    id: id,
                    homeTeam: "", awayTeam: "",
                    homeLogoURL: "", awayLogoURL: "",
                    kickoff: Date(),
                    competitionID: "",
                    homeScore: 0, awayScore: 0,
                    embedURL: ""
                )
            )
        },
        competitionDetail: { id in
            WasmClient.LiveScore.Competition(id: id)
        },
        teamDetail: { id in
            WasmClient.LiveScore.Team(id: id)
        },
        liveMatchEvents: { AsyncStream { $0.finish() } },
        submitSurvey: { _, _ in },
        setNotification: { _, _, _, _ in },
        getNotificationSettings: { NotificationSettings(enabled: false, topics: []) },
        notificationSubscribe: { _, _, _ in },
        reportLiveActivityToken: { _, _, _ in }
    )

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
        setUserName: { _ in },
        warmUp: {
            try? await Task.sleep(nanoseconds: MockConstants.warmUpDelay)
        },
        availableActions: {
            [
                ActionInfo(actionID: ActionID.chat.rawValue, provider: "openai", name: "Chat"),
                ActionInfo(actionID: ActionID.scan.rawValue, provider: "vision", name: "Scan"),
                ActionInfo(actionID: ActionID.lsWebpage.rawValue, provider: "football", name: "Livescore Webpage"),
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
        chatModels: { offset, limit, keyword, category in
            let all: [ChatModelInfo] = [
                ChatModelInfo(
                    modelId: "gpt-4o-mini", name: "GPT-4o mini",
                    ownedBy: "openai", vision: true,
                    description: "Fast, affordable multimodal model.",
                    providerId: "openai", providerName: "OpenAI"
                ),
                ChatModelInfo(
                    modelId: "gpt-4o", name: "GPT-4o",
                    ownedBy: "openai", isPro: true, vision: true,
                    description: "Flagship multimodal model.",
                    providerId: "openai", providerName: "OpenAI"
                ),
                ChatModelInfo(
                    modelId: "claude-sonnet-4-6", name: "Claude Sonnet 4.6",
                    ownedBy: "anthropic", isPro: true, vision: true,
                    description: "Anthropic's balanced model.",
                    providerId: "anthropic", providerName: "Anthropic"
                ),
            ]
            var filtered = all
            if let kw = keyword?.trimmingCharacters(in: .whitespaces), !kw.isEmpty {
                let lower = kw.lowercased()
                filtered = filtered.filter {
                    $0.modelId.lowercased().contains(lower)
                        || $0.name.lowercased().contains(lower)
                }
            }
            if let cat = category?.trimmingCharacters(in: .whitespaces), !cat.isEmpty {
                let lower = cat.lowercased()
                filtered = filtered.filter { $0.ownedBy.lowercased() == lower }
            }
            let start = max(0, min(offset, filtered.count))
            let end = max(start, min(start + limit, filtered.count))
            return (Array(filtered[start..<end]), filtered.count)
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
        createChatModel: { _, input in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            let slug = input.name
                .lowercased()
                .replacingOccurrences(of: " ", with: "-")
            return "mock-model-\(slug)"
        },
        initializeChatProvider: { _, _ in
            try await Task.sleep(nanoseconds: MockConstants.shortDelay)
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
        readOutLoud: { _, _, _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return .url(URL(string: "https://example.com/mock-tts.mp3")!)
        },
        ttsVoices: { _, _ in
            try await Task.sleep(nanoseconds: MockConstants.shortDelay)
            return ["alloy", "echo", "shimmer"]
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
        aiartVideoCreate: { _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return AiartVideoResult(
                status: .processing,
                videoID: "mock-video-\(UUID().uuidString)",
                progress: 0.05
            )
        },
        aiartVideoStatus: { videoID in
            try await Task.sleep(nanoseconds: MockConstants.shortDelay)
            return AiartVideoResult(
                status: .completed,
                videoID: videoID,
                videoURL: "https://example.com/avatar-fx.mp4",
                styledImageURL: "https://example.com/avatar-fx-styled.png",
                audioURL: "https://example.com/avatar-fx-audio.mp3",
                prompt: "A friendly avatar speaking",
                artStyle: "Ghibli",
                progress: 1.0
            )
        },
        aiartVideoPoll: { videoID, _, onUpdate in
            // Stream three progress ticks then resolve, so previews and
            // tests see the same shape as a real generation.
            for value in [0.25, 0.55, 0.85] {
                try await Task.sleep(nanoseconds: MockConstants.shortDelay)
                onUpdate?(
                    AiartVideoResult(
                        status: .processing,
                        videoID: videoID,
                        progress: value
                    )
                )
            }
            try await Task.sleep(nanoseconds: MockConstants.shortDelay)
            let final = AiartVideoResult(
                status: .completed,
                videoID: videoID,
                videoURL: "https://example.com/avatar-fx.mp4",
                styledImageURL: "https://example.com/avatar-fx-styled.png",
                audioURL: "https://example.com/avatar-fx-audio.mp3",
                prompt: "A friendly avatar speaking",
                artStyle: "Ghibli",
                progress: 1.0
            )
            onUpdate?(final)
            return final
        },
        listPendingTasks: { [] },
        observePendingTasks: {
            AsyncStream { continuation in
                continuation.yield([])
                continuation.finish()
            }
        },
        observeTaskCreated: { AsyncStream { $0.finish() } },
        removePendingTask: { _ in },
        clearPendingTasks: { },
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
            return HomeDecor.Result(
                imageURL: "https://example.com/redesigned-room.jpg",
                inputImageURL: "https://example.com/original-room.jpg",
                taskID: "mock-task-id"
            )
        },
        homeDesignStatus: { _, _ in
            HomeDecor.Result(
                imageURL: "https://example.com/redesigned-room.jpg",
                taskID: "mock-task-id"
            )
        },
        homeDesignRequest: { request, onProgress in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            await onProgress?(0.25)
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            await onProgress?(0.75)
            try await Task.sleep(nanoseconds: MockConstants.shortDelay)
            await onProgress?(1.0)
            return HomeDecor.Result(
                status: .completed,
                imageURL: "https://example.com/redesigned-room.jpg",
                inputImageURL: request.file.isEmpty ? "https://example.com/original-room.jpg" : request.file,
                taskID: "mock-task-id",
                metadata: ["progress": "1.0"],
                processType: request.processType,
                roomStyle: request.roomStyle,
                roomType: request.roomType,
                progress: 1.0,
                provider: "mock"
            )
        },
        homeDecorStyles: { _ in [.modern, .minimalist, .scandinavian, .japandi, .cozy] },
        homeDecorRoomTypes: { _ in [.livingRoom, .bedroom, .kitchen, .bathroom, .office] },
        homeDecorColorPalettes: { _ in [.millennialGray, .neonSunset, .forestHues, .pastelBreeze] },
        homeDecorSurfaceTypes: { _ in [.wall, .ceiling, .floorSurface] },
        homeDecorStyleSelections: { _ in [.structuralPreservation, .renovationDesign] },
        autoSuggestion: { _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return ObjectSegments(sessionID: "mock-session")
        },
        enhance: { _, _ in
            try await Task.sleep(nanoseconds: MockConstants.longDelay)
            return ObjectSegments(sessionID: "mock-session")
        },
        removeBackground: { _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return Segment(maskURL: "https://example.com/mask.png")
        },
        erase: { _, _, _, _ in
            try await Task.sleep(nanoseconds: MockConstants.longDelay)
            return EraseResult(sessionID: "mock-session", imageURL: "https://example.com/erased.jpg")
        },
        skinBeauty: { _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return ObjectSegments(sessionID: "mock-session")
        },
        sky: { _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return Segment(maskURL: "https://example.com/sky-mask.png")
        },
        categorizeClothes: { _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return Segment(maskURL: "https://example.com/clothes-mask.png")
        },
        tryOn: { _, _ in
            try await Task.sleep(nanoseconds: MockConstants.longDelay)
            return "https://example.com/tryon.jpg"
        },
        webpageLeagues: {
            [LiveScore.WebPage(id: "league/premier-league", title: "Premier League", subtitle: "England")]
        },
        webpageCompetitions: { _, _, _ in
            [LiveScore.WebPage(id: "competition/champions-league", title: "Champions League", subtitle: "UEFA")]
        },
        webpageTeams: { _, _, _, _ in
            [LiveScore.WebPage(id: "team/arsenal", title: "Arsenal", subtitle: "England")]
        },
        webpage: { _ in
            [LiveScore.WebPage(id: "page/example", title: "Example Page", url: "https://example.com")]
        },
        webpageDiscovers: {
            [LiveScore.WebPage(id: "discover/featured", title: "Featured", subtitle: "Discover")]
        },
        webpageCompetition: { id in
            LiveScore.WebPage(id: "competition/\(id)", title: "Mock Competition \(id)", subtitle: "UEFA")
        },
        webpageTeam: { id in
            LiveScore.WebPage(id: "team/\(id)", title: "Mock Team \(id)", subtitle: "England")
        },
        webpageVideos: { _, _, _, _, _, _ in
            [LiveScore.WebPage(id: "video/example", title: "Example Highlight", subtitle: "Premier League")]
        },
        webpageNews: { _, _, _, _, _ in
            [
                LiveScore.WebPage(
                    id: "news/example",
                    title: "Example Headline",
                    subtitle: "livescore · Mock Author",
                    url: "https://example.com/news/1"
                )
            ]
        },
        upcoming: {
            [
                LiveScore.UpcomingMatch(
                    id: "1",
                    homeTeam: "PSG", awayTeam: "Bayern Munich",
                    homeLogoURL: "", awayLogoURL: "",
                    kickoff: Date().addingTimeInterval(3600),
                    competitionID: "0",
                    homeScore: 0, awayScore: 0,
                    status: .notStarted, embedURL: ""
                )
            ]
        },
        scoresByDate: { _ in
            [
                LiveScore.UpcomingMatch(
                    id: "2",
                    homeTeam: "Arsenal", awayTeam: "Chelsea",
                    homeLogoURL: "", awayLogoURL: "",
                    kickoff: Date(),
                    competitionID: "1",
                    homeScore: 1, awayScore: 1,
                    status: .secondHalf, embedURL: "",
                    competitionImage: "",
                    competitionName: "ENGLAND: Premier League",
                    competitionRegion: "England"
                )
            ]
        },
        matchDetail: { id in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return LiveScore.Match(
                summary: LiveScore.UpcomingMatch(
                    id: id,
                    homeTeam: "Arsenal", awayTeam: "Chelsea",
                    homeLogoURL: "", awayLogoURL: "",
                    kickoff: Date(),
                    competitionID: "1",
                    homeScore: 2, awayScore: 1,
                    status: .secondHalf, embedURL: "",
                    competitionImage: "",
                    competitionName: "ENGLAND: Premier League",
                    competitionRegion: "England"
                ),
                events: [
                    LiveScore.MatchEvent(
                        playerName: "Saka", participantID: "home",
                        minute: 23, eventType: .goal
                    ),
                    LiveScore.MatchEvent(
                        playerName: "Sterling", participantID: "away",
                        minute: 41, eventType: .yellowCard
                    ),
                    LiveScore.MatchEvent(
                        playerName: "Jesus", participantID: "home",
                        minute: 67, eventType: .goal,
                        relatedPlayerName: "Ødegaard"
                    )
                ],
                statistics: [
                    LiveScore.FixtureStatistic(
                        typeName: "Possession", location: "home",
                        statType: .possession, valueString: "58"
                    ),
                    LiveScore.FixtureStatistic(
                        typeName: "Possession", location: "away",
                        statType: .possession, valueString: "42"
                    )
                ],
                refereeName: "Michael Oliver",
                venue: LiveScore.Venue(id: "9", name: "Emirates Stadium")
            )
        },
        competitionDetail: { id in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return LiveScore.Competition(
                id: id,
                name: "Premier League",
                image: "",
                region: "England",
                slug: "competition/england-premier-league",
                seasonID: 0,
                country: LiveScore.Country(id: "1", name: "England", iso2: "GB"),
                url: "",
                fixtures: [],
                standings: [],
                stats: LiveScore.CompetitionStats()
            )
        },
        teamDetail: { id in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
            return LiveScore.Team(
                id: id,
                name: "Arsenal",
                image: "",
                slug: "team/arsenal",
                url: "",
                countryName: "England",
                countryID: "1",
                national: false,
                aka: ["The Gunners"]
            )
        },
        liveMatchEvents: {
            AsyncStream { continuation in
                continuation.yield(.connected)
                continuation.yield(
                    .update(
                        LiveScore.MatchUpdate(
                            id: "1001",
                            home: LiveScore.MatchUpdateSide(
                                teamID: "team/arsenal", teamName: "Arsenal",
                                oldScore: 0, newScore: 1
                            ),
                            away: LiveScore.MatchUpdateSide(
                                teamID: "team/chelsea", teamName: "Chelsea",
                                oldScore: 1, newScore: 1
                            ),
                            competitionID: "competition/england-premier-league",
                            competitionName: "Premier League",
                            competitionRegion: "England",
                            oldStatus: .secondHalf,
                            newStatus: .secondHalf,
                            eventType: .goal,
                            kickoff: Date()
                        )
                    )
                )
                continuation.finish()
            }
        },
        submitSurvey: { _, _ in
            try await Task.sleep(nanoseconds: MockConstants.mediumDelay)
        },
        setNotification: { _, _, _, _ in
            try await Task.sleep(nanoseconds: MockConstants.shortDelay)
        },
        getNotificationSettings: {
            try await Task.sleep(nanoseconds: MockConstants.shortDelay)
            return NotificationSettings(enabled: true, topics: ["live_scores"])
        },
        notificationSubscribe: { _, _, _ in
            try await Task.sleep(nanoseconds: MockConstants.shortDelay)
        },
        reportLiveActivityToken: { _, _, _ in
            try await Task.sleep(nanoseconds: MockConstants.shortDelay)
        }
    )
}
