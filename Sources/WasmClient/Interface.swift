import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct WasmClient: Sendable {

    // MARK: - Engine Lifecycle

    public var start: @Sendable () async throws -> Void

    public var observeEngineState: @Sendable () async -> AsyncStream<WasmClient.EngineState> = { AsyncStream { _ in } }

    public var reset: @Sendable () async throws -> Void

    public var restart: @Sendable () async throws -> Void

    public var engineVersion: @Sendable () async -> String? = { nil }

    public var resetDownloads: @Sendable () async -> Void = {}

    public var setExpectedVersionProvider:
        @Sendable (
            _ provider: @escaping @Sendable () async throws -> String?
        ) -> Void = { _ in }

    public var setUserName: @Sendable (_ name: String) -> Void = { _ in }

    public var warmUp: @Sendable () async -> Void = {}

    public var availableActions: @Sendable () async throws -> [WasmClient.ActionInfo]

    public var refreshActions: @Sendable () async throws -> Void

    public var funnelEngine: @Sendable () async throws -> WasmClient.EngineHandle? = { nil }

    // MARK: - Vision / Scan

    public var scan:
        @Sendable (
            _ imageData: Data, _ category: String, _ language: String
        ) async throws -> WasmClient.Vision.ScanResult

    public var describe:
        @Sendable (
            _ imageURL: String, _ category: String, _ language: String, _ provider: String
        ) async throws -> WasmClient.Vision.ScanResult

    public var visualSearch:
        @Sendable (
            _ imageURL: String, _ provider: String
        ) async throws -> [WasmClient.Vision.ShoppingProduct]

    public var shopping:
        @Sendable (
            _ query: String, _ provider: String
        ) async throws -> [WasmClient.Vision.ShoppingProduct]

    // MARK: - Smart Car

    public var lookupVin: @Sendable (_ vin: String) async throws -> WasmClient.Smartcar.Vehicle

    public var smartcarConnectConfig:
        @Sendable (
            _ mode: WasmClient.Smartcar.Connection.Mode
        ) async throws -> WasmClient.Smartcar.Connection.Config

    public var smartcarHostedConnectEvent:
        @Sendable (
            _ url: String, _ bodyText: String
        ) async throws -> WasmClient.Smartcar.Connection.Decision

    public var smartcarAccounts: @Sendable () async throws -> [WasmClient.Smartcar.Account]

    public var smartcarSwitchAccount:
        @Sendable (
            _ userID: String
        ) async throws -> [WasmClient.Smartcar.Account]

    public var smartcarDeleteAccount:
        @Sendable (
            _ userID: String
        ) async throws -> [WasmClient.Smartcar.Account]

    public var smartcarAllVehicles:
        @Sendable (
            _ vehicleID: String, _ make: String
        ) async throws -> [WasmClient.Smartcar.Vehicle]

    public var smartcarGetPermissions:
        @Sendable (
            _ vehicleID: String, _ make: String
        ) async throws -> [WasmClient.Smartcar.Permission]

    public var smartcarRead:
        @Sendable (
            _ method: WasmClient.Smartcar.Method, _ vehicleID: String, _ make: String
        ) async throws -> [String: WasmClient.Smartcar.Value]

    public var smartcarControl:
        @Sendable (
            _ method: WasmClient.Smartcar.Method, _ vehicleID: String, _ args: [String: WasmClient.Smartcar.Value]
        ) async throws -> WasmClient.Smartcar.ControlResponse

    // MARK: - Blobstore

    public var uploadImage: @Sendable (_ imageData: Data) async throws -> String

    public var uploadFile: @Sendable (_ filePath: String, _ filename: String) async throws -> String

    // MARK: - Chat (OpenAI-compatible)

    public var chatModels:
        @Sendable (
            _ offset: Int, _ limit: Int, _ keyword: String?, _ category: String?
        ) async throws -> (models: [WasmClient.Chat.ModelInfo], total: Int)

    public var chatSend:
        @Sendable (
            _ config: WasmClient.Chat.Config,
            _ messages: [WasmClient.Chat.Message]
        ) async throws -> WasmClient.Chat.Message

    public var chatStream:
        @Sendable (
            _ config: WasmClient.Chat.Config,
            _ messages: [WasmClient.Chat.Message]
        ) async throws -> AsyncThrowingStream<String, Swift.Error>

    public var createChatModel:
        @Sendable (
            _ providerID: String,
            _ input: WasmClient.Chat.CreateModelInput
        ) async throws -> String

    public var initializeChatProvider:
        @Sendable (
            _ providerID: String,
            _ userName: String
        ) async throws -> Void

    public var completion:
        @Sendable (
            _ config: WasmClient.Chat.Config,
            _ messages: [WasmClient.Chat.Message]
        ) async throws -> WasmClient.Chat.Message

    /// Run the agentic tool-calling loop: send the conversation, and while the
    /// model keeps emitting `toolCalls`, run each tool's handler, feed the
    /// result back as a `role: .tool` message, and re-invoke the model — up to
    /// `maxRounds` times. Additive over `completion`; existing chat entry points
    /// are untouched.
    public var chatRun:
        @Sendable (
            _ config: WasmClient.Chat.Config,
            _ messages: [WasmClient.Chat.Message],
            _ tools: [WasmClient.Chat.ExecutableTool],
            _ maxRounds: Int,
            _ onEvent: (@Sendable (WasmClient.Chat.ChatRunEvent) async -> Void)?
        ) async throws -> WasmClient.Chat.ChatRunResult

    public var listProviders: @Sendable () async throws -> [WasmClient.Chat.ProviderInfo]

    public var authProvider:
        @Sendable (
            _ providerID: String
        ) async throws -> (providerID: String, cacheDir: String)

    public var listVoices:
        @Sendable (
            _ providerID: String, _ keyword: String, _ offset: Int, _ limit: Int
        ) async throws -> WasmClient.Chat.VoiceList

    public var createVoice:
        @Sendable (
            _ providerID: String,
            _ name: String,
            _ audio: String,
            _ gender: WasmClient.Chat.VoiceGender,
            _ visibility: WasmClient.Chat.VoiceVisibility
        ) async throws -> WasmClient.Chat.VoiceInfo

    public var deleteVoice:
        @Sendable (
            _ providerID: String,
            _ voiceID: String
        ) async throws -> Void

    // MARK: - Music

    public var musicDiscover:
        @Sendable (
            _ category: String, _ continuation: String?
        ) async throws -> WasmClient.Music.TrackList

    public var musicDetails:
        @Sendable (
            _ trackID: String
        ) async throws -> WasmClient.Music.TrackDetail

    public var musicTracks:
        @Sendable (
            _ listID: String, _ continuation: String?
        ) async throws -> WasmClient.Music.TrackList

    public var musicSearch:
        @Sendable (
            _ query: String, _ continuation: String?
        ) async throws -> WasmClient.Music.TrackList

    public var musicLyrics:
        @Sendable (
            _ trackID: String
        ) async throws -> [WasmClient.Music.LyricSegment]

    public var musicRelated:
        @Sendable (
            _ trackID: String, _ continuation: String?
        ) async throws -> WasmClient.Music.TrackList

    public var musicSuggestions:
        @Sendable (
            _ query: String
        ) async throws -> [String]

    // MARK: - Suggest

    public var suggest:
        @Sendable (
            _ systemPrompt: String, _ imageURL: String?
        ) async throws -> [String]

    // MARK: - Read Out Loud (TTS)

    public var readOutLoud:
        @Sendable (
            _ text: String, _ voice: String?, _ providerID: String
        ) async throws -> WasmClient.Chat.TTSAudio

    public var ttsVoices:
        @Sendable (
            _ providerID: String, _ modelID: String
        ) async throws -> [String]

    // MARK: - AI Art

    public var generateAIArt:
        @Sendable (
            _ request: WasmClient.AIArt.ImageRequest
        ) async throws -> WasmClient.AIArt.ImageResult

    public var listAIArtStyles:
        @Sendable (
            _ kind: WasmClient.AIArt.ImageRequest.Kind
        ) async throws -> [WasmClient.AIArt.Style]

    public var loadAIArtModelCatalog:
        @Sendable (
            _ mode: WasmClient.AIArt.Mode
        ) async throws -> WasmClient.AIArt.ModelCatalog

    public var submitAIArtVideo:
        @Sendable (
            _ request: WasmClient.AIArt.VideoRequest
        ) async throws -> WasmClient.AIArt.VideoTaskSnapshot

    public var getAIArtVideoStatus:
        @Sendable (
            _ videoID: String
        ) async throws -> WasmClient.AIArt.VideoTaskSnapshot

    public var pollAIArtVideo:
        @Sendable (
            _ videoID: String,
            _ interval: TimeInterval,
            _ onUpdate: (@Sendable (WasmClient.AIArt.VideoTaskSnapshot) -> Void)?
        ) async throws -> WasmClient.AIArt.VideoTaskSnapshot

    // MARK: - Pending Tasks

    public var listPendingTasks: @Sendable () async -> [WasmClient.PendingTask] = { [] }

    public var observePendingTasks: @Sendable () async -> AsyncStream<[WasmClient.PendingTask]> = {
        AsyncStream { _ in }
    }

    public var observeTaskCreated: @Sendable () async -> AsyncStream<WasmClient.PendingTask> = {
        AsyncStream { _ in }
    }

    public var removePendingTask: @Sendable (_ taskID: String) async -> Void = { _ in }

    public var clearPendingTasks: @Sendable () async -> Void = {}

    // MARK: - Visual / Media

    public var searchPhotos:
        @Sendable (
            _ query: String, _ provider: String, _ page: Int, _ perPage: Int
        ) async throws -> WasmClient.Visual.SearchResult

    public var photoVisualSearch:
        @Sendable (
            _ imageURL: String, _ provider: String, _ page: Int, _ perPage: Int
        ) async throws -> WasmClient.Visual.SearchResult

    public var listMedia:
        @Sendable (
            _ query: String, _ provider: String, _ page: Int, _ perPage: Int
        ) async throws -> WasmClient.Visual.SearchResult

    // MARK: - Home Decor

    public var homeDesign:
        @Sendable (
            _ actionID: String, _ args: [String: String]
        ) async throws -> WasmClient.HomeDecor.Result

    public var homeDesignStatus:
        @Sendable (
            _ taskID: String, _ actionID: String
        ) async throws -> WasmClient.HomeDecor.Result

    public var homeDesignRequest:
        @Sendable (
            _ request: WasmClient.HomeDecor.Request,
            _ onProgress: (@Sendable (Double) async -> Void)?
        ) async throws -> WasmClient.HomeDecor.Result

    public var homeDecorStyles:
        @Sendable (
            _ processType: WasmClient.HomeDecor.ProcessType
        ) async throws -> [WasmClient.HomeDecor.RoomStyle]

    public var homeDecorRoomTypes:
        @Sendable (
            _ processType: WasmClient.HomeDecor.ProcessType
        ) async throws -> [WasmClient.HomeDecor.RoomType]

    public var homeDecorColorPalettes:
        @Sendable (
            _ processType: WasmClient.HomeDecor.ProcessType
        ) async throws -> [WasmClient.HomeDecor.ColorPalette]

    public var homeDecorSurfaceTypes:
        @Sendable (
            _ processType: WasmClient.HomeDecor.ProcessType
        ) async throws -> [WasmClient.HomeDecor.SurfaceType]

    public var homeDecorStyleSelections:
        @Sendable (
            _ processType: WasmClient.HomeDecor.ProcessType
        ) async throws -> [WasmClient.HomeDecor.StyleSelection]

    // MARK: - Inpaint

    public var autoSuggestion:
        @Sendable (
            _ image: String
        ) async throws -> WasmClient.Inpaint.ObjectSegments

    public var enhance:
        @Sendable (
            _ image: String, _ zoomFactor: Int
        ) async throws -> WasmClient.Inpaint.ObjectSegments

    public var removeBackground:
        @Sendable (
            _ image: String
        ) async throws -> WasmClient.Inpaint.Segment

    public var erase:
        @Sendable (
            _ image: String?,
            _ sessionID: String?,
            _ maskBrush: String?,
            _ maskObjects: String?
        ) async throws -> WasmClient.Inpaint.EraseResult

    public var skinBeauty:
        @Sendable (
            _ image: String
        ) async throws -> WasmClient.Inpaint.ObjectSegments

    public var sky:
        @Sendable (
            _ image: String
        ) async throws -> WasmClient.Inpaint.Segment

    public var categorizeClothes:
        @Sendable (
            _ image: String
        ) async throws -> WasmClient.Inpaint.Segment

    public var tryOn:
        @Sendable (
            _ modelImage: String,
            _ clothImage: String
        ) async throws -> String

    // MARK: - Livescore Webpage

    public var webpageLeagues: @Sendable () async throws -> [WasmClient.LiveScore.Entry]

    public var webpageCompetitions:
        @Sendable (
            _ q: String?,
            _ limit: Int64?,
            _ offset: Int64?
        ) async throws -> [WasmClient.LiveScore.Entry]

    public var webpageTeams:
        @Sendable (
            _ q: String?,
            _ limit: Int64?,
            _ offset: Int64?,
            _ competitionID: String?
        ) async throws -> [WasmClient.LiveScore.Entry]

    public var webpage: @Sendable (_ url: String) async throws -> [WasmClient.LiveScore.Entry]

    public var webpageDiscovers: @Sendable () async throws -> [WasmClient.LiveScore.Entry]

    public var webpageCompetition:
        @Sendable (
            _ id: String
        ) async throws -> WasmClient.LiveScore.Entry?

    public var webpageTeam:
        @Sendable (
            _ id: String
        ) async throws -> WasmClient.LiveScore.Entry?

    public var webpageVideos:
        @Sendable (
            _ videoType: String?,
            _ competitionID: String?,
            _ teamID: String?,
            _ q: String?,
            _ page: Int64?,
            _ pageSize: Int64?
        ) async throws -> [WasmClient.LiveScore.Entry]

    public var webpageNews:
        @Sendable (
            _ limit: Int64?, _ offset: Int64?, _ q: String?,
            _ competitionID: String?, _ teamID: String?
        ) async throws -> [WasmClient.LiveScore.Entry]

    public var upcoming: @Sendable () async throws -> [WasmClient.LiveScore.MatchSummary]

    public var scoresByDate:
        @Sendable (
            _ date: String?
        ) async throws -> [WasmClient.LiveScore.MatchSummary]

    public var matchDetail:
        @Sendable (
            _ id: String
        ) async throws -> WasmClient.LiveScore.Match

    public var competitionDetail:
        @Sendable (
            _ id: String
        ) async throws -> WasmClient.LiveScore.Competition

    public var teamDetail:
        @Sendable (
            _ id: String
        ) async throws -> WasmClient.LiveScore.Team

    public var liveMatchEvents: @Sendable () async -> AsyncStream<WasmClient.LiveScore.LiveEvent> = {
        AsyncStream { _ in }
    }

    // MARK: - Survey

    public var submitSurvey:
        @Sendable (
            _ questions: [WasmClient.Survey.Question], _ answers: [String: String]
        ) async throws -> Void

    // MARK: - Notifications

    public var setNotification:
        @Sendable (
            _ enabled: Bool,
            _ firebaseToken: String,
            _ firebaseUID: String?,
            _ liveActivityToken: String,
            _ liveActivityAttributesType: WasmClient.Notification.LiveActivityAttributesType?
        ) async throws -> Void

    public var getNotificationSettings: @Sendable () async throws -> WasmClient.Notification.Settings

    public var notificationSubscribe:
        @Sendable (
            _ entity: String, _ id: String, _ enabled: Bool
        ) async throws -> Void

    public var reportLiveActivityToken:
        @Sendable (
            _ entity: String, _ entityID: String, _ laToken: String
        ) async throws -> Void
}
