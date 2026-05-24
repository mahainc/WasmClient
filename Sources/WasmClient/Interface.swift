import Dependencies
import DependenciesMacros
import Foundation

/// General-purpose TCA dependency client wrapping FlowKit's WASM engine.
///
/// Exposes all WASM domains (chat, vision/scan, blobstore, music, suggest,
/// AI art, visual/media, home decor, inpaint, livescore, survey) as
/// `@Sendable` async closures. The interface target has no FlowKit dependency —
/// all FlowKit types are mapped to pure Swift models nested under `WasmClient`.
///
/// Usage:
/// ```swift
/// @Dependency(\.wasm) var wasm
/// try await wasm.start()
/// let pages = try await wasm.webpageLeagues()
/// ```
@DependencyClient
public struct WasmClient: Sendable {

    // MARK: - Engine Lifecycle

    /// Start the WASM engine. Boots the engine, waits for actions to register,
    /// and begins emitting state updates. Call on app launch or screen appear.
    /// Safe to call multiple times — no-ops if already started.
    public var start: @Sendable () async throws -> Void

    /// Observe engine state changes as an async stream.
    /// Emits `.stopped`, `.starting`, `.updating(Double)`, `.running`, `.failed(String)`.
    /// Use this to drive loading UI (progress → content → error/retry).
    public var observeEngineState: @Sendable () async -> AsyncStream<WasmClient.EngineState> = { AsyncStream { _ in } }

    /// Reset the WASM engine. Clears all cached state and stops the engine.
    /// After calling reset, you must call `start` again.
    public var reset: @Sendable () async throws -> Void

    /// Reset and restart the WASM engine in one call.
    /// Equivalent to calling `reset()` then `start()`.
    public var restart: @Sendable () async throws -> Void

    /// Current WASM binary version ID, or nil if engine hasn't loaded yet.
    public var engineVersion: @Sendable () async -> String? = { nil }

    /// Clear the cached WASM binary, forcing re-download on next start.
    public var resetDownloads: @Sendable () async -> Void = { }

    /// Register a callback that returns the wasm version the app expects to run.
    /// Invoked inside `start()` before `TaskWasm.default()`. If the returned ID
    /// differs from the currently cached version, the download cache is cleared
    /// so the engine fetches the new bundle on start. Returning `nil` or throwing
    /// is treated as "no expectation" and preserves the default behavior.
    /// Configure once at app launch — the registered provider persists across
    /// `reset()` / `restart()`.
    public var setExpectedVersionProvider: @Sendable (
        _ provider: @escaping @Sendable () async throws -> String?
    ) -> Void = { _ in }

    /// Set the display name used by auto-init paths that invoke `providerInit`
    /// internally (currently `readOutLoud`). CAI registers the user under this
    /// name; providers that don't need bootstrap ignore it. Call once at app
    /// launch (e.g. after sign-in) so callers don't have to thread the name
    /// through every TTS / chat invocation. The value persists across
    /// `reset()` / `restart()` because it lives on the same delegate as
    /// `setExpectedVersionProvider`.
    public var setUserName: @Sendable (_ name: String) -> Void = { _ in }

    /// Pre-warm the WASM engine. Convenience wrapper around `start` that
    /// ignores errors. Call early (e.g. on home screen appear) to avoid cold-start delay.
    public var warmUp: @Sendable () async -> Void = { }

    /// List all available actions from the running engine.
    public var availableActions: @Sendable () async throws -> [WasmClient.ActionInfo]

    /// Re-poll the engine for action providers. Use after a network-related
    /// failure during initial startup to retry provider discovery.
    public var refreshActions: @Sendable () async throws -> Void

    // MARK: - Vision / Scan

    /// Scan a photo: uploads to blobstore, runs vision scan, returns structured result.
    /// - Parameters:
    ///   - imageData: JPEG image data
    ///   - category: scan category (default "object")
    ///   - language: result language (default "en")
    public var scan: @Sendable (
        _ imageData: Data, _ category: String, _ language: String
    ) async throws -> WasmClient.ScanResult

    /// Describe/enrich a previously scanned image with full details.
    /// Uses the image URL returned by a prior `scan` call and the detected category
    /// to fetch characteristics, AI commentary, and richer metadata.
    /// Pass the scan result's `provider` to ensure the same provider handles enrichment.
    public var describe: @Sendable (
        _ imageURL: String, _ category: String, _ language: String, _ provider: String
    ) async throws -> WasmClient.ScanResult

    /// Visual search on an already-uploaded image URL. Returns matching products.
    /// Pass the scan result's `provider` for provider-consistent results.
    public var visualSearch: @Sendable (
        _ imageURL: String, _ provider: String
    ) async throws -> [WasmClient.ShoppingProduct]

    /// Search for shopping products by text query.
    /// Pass the scan result's `provider` for provider-consistent results.
    public var shopping: @Sendable (
        _ query: String, _ provider: String
    ) async throws -> [WasmClient.ShoppingProduct]

    // MARK: - Blobstore

    /// Upload image data, returning the hosted URL.
    public var uploadImage: @Sendable (_ imageData: Data) async throws -> String

    /// Upload a local file by path, returning the hosted URL.
    public var uploadFile: @Sendable (_ filePath: String, _ filename: String) async throws -> String

    // MARK: - Chat (OpenAI-compatible)

    /// Fetch chat models via the standalone `listModels` action.
    /// Supports pagination (`offset` / `limit`), free-text `keyword`
    /// filtering, and a backend `category` filter (e.g. `"anime"`,
    /// `"assistant"`). Each row is stamped with its source provider so
    /// callers can route subsequent chat requests correctly. Returns the
    /// page of rows plus the backend-reported `total` (drives "load more"
    /// logic).
    public var chatModels: @Sendable (
        _ offset: Int, _ limit: Int, _ keyword: String?, _ category: String?
    ) async throws -> (models: [WasmClient.ChatModelInfo], total: Int)

    /// Send a single chat message and get the full response.
    /// Stateless — does not maintain conversation history.
    public var chatSend: @Sendable (
        _ config: WasmClient.ChatConfig,
        _ messages: [WasmClient.ChatMessage]
    ) async throws -> WasmClient.ChatMessage

    /// Stream a chat response, yielding content deltas as they arrive via SSE.
    /// Stateless — caller manages conversation history.
    public var chatStream: @Sendable (
        _ config: WasmClient.ChatConfig,
        _ messages: [WasmClient.ChatMessage]
    ) async throws -> AsyncThrowingStream<String, Swift.Error>

    /// Create a custom chat model on a specific provider. Returns the
    /// provider-assigned model id (used as the `modelId` for subsequent
    /// `chatSend`/`chatStream` calls). Pass empty string for `providerId`
    /// to use the first available provider that supports `createModel`;
    /// pass an `ActionInfo.provider` from `availableActions()` to pin a
    /// specific one. Discover eligible providers by filtering
    /// `availableActions()` on `ActionID.createModel.rawValue`.
    public var createChatModel: @Sendable (
        _ providerId: String,
        _ input: WasmClient.CreateChatModelInput
    ) async throws -> String

    /// Run a chat provider's pre-flight init action. CAI registers the
    /// user via this call (using `metadata.name` as the display name);
    /// providers that don't need bootstrap return Completed immediately.
    /// Without it CAI rejects downstream calls with `unspecified`. Pass
    /// an empty `providerId` to fan out across every chat-capable provider.
    ///
    /// Idempotent within an engine session — repeated calls for the same
    /// `providerId` short-circuit on a per-session cache (cleared by
    /// `reset()`). Failures are also marked, so a provider that's
    /// genuinely unreachable doesn't get retry-looped; clear via `reset()`
    /// to retry. When `providerId` doesn't resolve to a provider that
    /// exposes `providerInit`, the call is a no-op success (the requested
    /// provider is marked as "tried" so auto-init from `readOutLoud`
    /// doesn't waste round-trips).
    public var initializeChatProvider: @Sendable (
        _ providerId: String,
        _ userName: String
    ) async throws -> Void

    // MARK: - Music

    /// Discover music tracks by category.
    public var musicDiscover: @Sendable (
        _ category: String, _ continuation: String?
    ) async throws -> WasmClient.MusicTrackList

    /// Get detailed info for a music track.
    public var musicDetails: @Sendable (
        _ trackID: String
    ) async throws -> WasmClient.MusicTrackDetail

    /// List tracks (e.g. playlist, album).
    public var musicTracks: @Sendable (
        _ listID: String, _ continuation: String?
    ) async throws -> WasmClient.MusicTrackList

    /// Search music by query.
    public var musicSearch: @Sendable (
        _ query: String, _ continuation: String?
    ) async throws -> WasmClient.MusicTrackList

    /// Get lyrics for a track.
    public var musicLyrics: @Sendable (
        _ trackID: String
    ) async throws -> [WasmClient.MusicLyricSegment]

    /// Get related tracks.
    public var musicRelated: @Sendable (
        _ trackID: String, _ continuation: String?
    ) async throws -> WasmClient.MusicTrackList

    /// Get music search suggestions.
    public var musicSuggestions: @Sendable (
        _ query: String
    ) async throws -> [String]

    // MARK: - Suggest

    /// Get AI-generated prompt suggestions.
    /// Optionally pass an image URL for context-aware suggestions.
    public var suggest: @Sendable (
        _ systemPrompt: String, _ imageURL: String?
    ) async throws -> [String]

    // MARK: - Read Out Loud (TTS)

    /// Synthesize speech (or fetch a provider replay URL) for the given
    /// text via the `tts` action. One-shot, stateless.
    ///
    /// On first call against a given `providerId` in this engine session,
    /// runs `providerInit` for that provider as a best-effort step so CAI
    /// (which rejects `tts` calls before user registration) Just Works.
    /// The display name comes from whatever the host most recently passed
    /// to `setUserName` — call that once at launch / after sign-in. If
    /// `setUserName` has never been called (or was called with an empty
    /// string), auto-init is skipped so the consumer can still recover
    /// after setting the name. Subsequent calls within the same session
    /// short-circuit via the internal `initializedProviders` cache;
    /// `reset()` clears it.
    ///
    /// Pair with `ttsVoices(providerId:modelId:)` to drive a voice picker.
    ///
    /// - Parameters:
    ///   - text: the message to read.
    ///   - voice: a voice id from `ttsVoices(providerId:modelId:)` (or
    ///     `ChatModelInfo.voices`), or `nil` to let the provider use its
    ///     default (e.g. OpenAI `alloy`).
    ///   - providerId: pin the TTS call to a specific provider — pass
    ///     `state.selectedModel?.providerId` so the voice list, replay
    ///     endpoint, and credentials match the chat provider the user is
    ///     currently on. Pass empty string to fall back to whichever
    ///     provider's `tts` action was registered first (auto-init is
    ///     skipped in that case — call `initializeChatProvider` first).
    ///
    /// Returns either a streamable URL or raw audio bytes — the consumer
    /// handles playback.
    public var readOutLoud: @Sendable (
        _ text: String, _ voice: String?, _ providerId: String
    ) async throws -> WasmClient.TTSAudio

    /// List the voice presets exposed by a specific chat model on a specific
    /// provider. Wraps `chatModels` and returns `ChatModelInfo.voices` for
    /// the matching row, or `[]` if the model is unknown / offers no voices.
    ///
    /// Pair with `readOutLoud` to build a voice picker — same data source
    /// flow-kit-example uses to drive its `confirmationDialog` (each model's
    /// `metadata.voices` from the `listModels` action).
    public var ttsVoices: @Sendable (
        _ providerId: String, _ modelId: String
    ) async throws -> [String]

    // MARK: - AI Art

    /// Generate AI art using the specified action (stamp or normal).
    /// Pass the action ID (e.g. `ActionID.aiartStamp.rawValue`) and flat string args
    /// (prompt, style, image_url, aspect_ratio, etc.).
    public var aiartGenerate: @Sendable (
        _ actionID: String, _ args: [String: String]
    ) async throws -> WasmClient.AiartResult

    /// Available style values for an aiart action, parsed from the action
    /// schema's `style` arg regex validator (e.g. `^(ANIME|CYBERPUNK|...)$`).
    /// Returns an empty array if the action has no style validator or the regex
    /// cannot be parsed. Callers should use these values verbatim when building
    /// args for `aiartGenerate` — sending a style that isn't in this list causes
    /// the server to reject the task with `status=unspecified`.
    public var aiartStyles: @Sendable (
        _ actionID: String
    ) async throws -> [String]

    /// Submit an AI art video generation task (Character.AI Avatar FX).
    /// Returns immediately with `.processing` status and the `videoID` used
    /// for polling via `aiartVideoStatus`. Pass flat string args
    /// (`image_path`, `audio_path`, `art_style`, `cache_dir`, …).
    public var aiartVideoCreate: @Sendable (
        _ args: [String: String]
    ) async throws -> WasmClient.AiartVideoResult

    /// Poll a video generation task by `videoID`. Returns the latest snapshot
    /// (`.processing` with progress, `.completed` with `videoURL`, or
    /// `.failed`). Caller drives the polling cadence — typically every 5s
    /// until terminal state.
    public var aiartVideoStatus: @Sendable (
        _ videoID: String
    ) async throws -> WasmClient.AiartVideoResult

    /// Drive the polling loop end-to-end: calls `aiartVideoStatus` every
    /// `interval` seconds, invoking `onUpdate` with the current snapshot
    /// (so callers can surface progress to the UI), and returns the final
    /// `.completed` result. Throws `Error.taskFailed` on `.failed`, and
    /// propagates `CancellationError` so the caller's task can interrupt
    /// in-flight polls (e.g. when the user backs out of the screen).
    /// Caller is responsible for upstream `Task` lifetime / timeouts.
    public var aiartVideoPoll: @Sendable (
        _ videoID: String,
        _ interval: TimeInterval,
        _ onUpdate: (@Sendable (WasmClient.AiartVideoResult) -> Void)?
    ) async throws -> WasmClient.AiartVideoResult

    // MARK: - Pending Tasks

    /// Snapshot of every persisted task descriptor (in-flight + recently
    /// completed) in the engine's default cache directory. Use to drive
    /// out-of-band progress UI such as the Profile → Videos grid that surfaces
    /// generations the user kicked off and then dismissed the originating
    /// screen for. Filter by `actionID` (e.g. `isVideoTask`) for domain-specific
    /// listings.
    public var listPendingTasks: @Sendable () async -> [WasmClient.PendingTask] = { [] }

    /// Observe persisted task descriptors as an async stream. The first value
    /// is the current snapshot; subsequent values are emitted whenever the
    /// engine's auto-resume loop or any caller mutates a descriptor (status
    /// change, progress tick, removal). Bridges FlowKit's
    /// `pendingTasksChanged` Combine subject so SwiftUI/TCA features can
    /// observe with a single async-for loop. Cancel by terminating the
    /// stream's iterator (e.g. when the parent Effect is cancelled).
    public var observePendingTasks: @Sendable () async -> AsyncStream<[WasmClient.PendingTask]> = { AsyncStream { _ in } }

    /// Observe newly-created task descriptors as an async stream. Emits one
    /// `PendingTask` per task ID that appears AFTER the subscriber attaches —
    /// pre-existing descriptors at subscribe time are seeded into the seen
    /// set and never replayed. Driven by the same `pendingTasksChanged`
    /// Combine subject + periodic re-read that powers `observePendingTasks`,
    /// so creations from any caller (this screen, another screen, the
    /// engine's own auto-resume) are surfaced uniformly. Each subscriber
    /// gets its own seen set; multiple subscribers each see the same new
    /// task exactly once. Cancel by terminating the iterator.
    public var observeTaskCreated: @Sendable () async -> AsyncStream<WasmClient.PendingTask> = { AsyncStream { $0.finish() } }

    /// Remove a single persisted task descriptor by ID. Used for swipe-to-
    /// remove on completed/errored rows; safe to call even when the engine
    /// hasn't been started yet (no-ops on missing descriptor).
    public var removePendingTask: @Sendable (_ taskID: String) async -> Void = { _ in }

    /// Remove every persisted task descriptor in the default cache. Used by
    /// "Clear all" actions on the pending-tasks UI.
    public var clearPendingTasks: @Sendable () async -> Void = { }

    // MARK: - Visual / Media

    /// Search photos by text query. Positional closure surface; prefer the
    /// labelled `searchPhotos(query:provider:page:perPage:)` overload in
    /// `Visual+Conveniences.swift` (defaults `page = 1`, `perPage = 20`).
    /// Pass empty string for `provider` to use the first available provider;
    /// pass an `ActionInfo.provider` value (from `availableActions()` or
    /// `searchPhotoProviders()`) to pin a specific one. For an empty-query
    /// editorial feed, use `listMedia(query: "")` instead.
    public var searchPhotos: @Sendable (
        _ query: String, _ provider: String, _ page: Int, _ perPage: Int
    ) async throws -> WasmClient.PhotoSearchResult

    /// Visual search: find similar photos given an image URL. Positional
    /// closure surface; prefer the labelled
    /// `photoVisualSearch(imageURL:provider:page:perPage:)` overload.
    /// Pass empty string for `provider` to use the first available provider;
    /// pass an `ActionInfo.provider` value (from `availableActions()` or
    /// `photoVisualSearchProviders()`) to pin a specific one.
    public var photoVisualSearch: @Sendable (
        _ imageURL: String, _ provider: String, _ page: Int, _ perPage: Int
    ) async throws -> WasmClient.PhotoSearchResult

    /// List media (editorial/trending). Positional closure surface; prefer
    /// the labelled `listMedia(query:provider:page:perPage:)` overload.
    /// Pass empty query for the provider's default editorial feed.
    /// Pass empty string for `provider` to use the first available provider;
    /// pass an `ActionInfo.provider` value (from `availableActions()` or
    /// `listMediaProviders()`) to pin a specific one.
    public var listMedia: @Sendable (
        _ query: String, _ provider: String, _ page: Int, _ perPage: Int
    ) async throws -> WasmClient.PhotoSearchResult

    // MARK: - Home Decor

    /// Generate a home decor design. Pass the action ID for the design type
    /// (e.g. `ActionID.interiorDesign.rawValue`) and flat string args
    /// (file, room_style, room_type, etc.).
    /// May return `.processing` status — poll via `homeDesignStatus`.
    public var homeDesign: @Sendable (
        _ actionID: String, _ args: [String: String]
    ) async throws -> WasmClient.HomeDecor.Result

    /// Poll a home decor task by ID. Pass the same actionID used for `homeDesign`.
    public var homeDesignStatus: @Sendable (
        _ taskID: String, _ actionID: String
    ) async throws -> WasmClient.HomeDecor.Result

    /// Submit a typed home-decor request. Resolves the `ActionID` from
    /// `request.processType`, builds wire args via `HomeDecor.Request.toWireArgs()`,
    /// polls until terminal, and returns the enriched `HomeDecor.Result`.
    /// `onProgress` is invoked between polls when the engine reports a progress
    /// fraction in `task.metadata.fields["progress"]`.
    public var homeDesignRequest: @Sendable (
        _ request: WasmClient.HomeDecor.Request,
        _ onProgress: (@Sendable (Double) async -> Void)?
    ) async throws -> WasmClient.HomeDecor.Result

    /// Available room styles for a process type, parsed from the active
    /// provider's `action.args["room_style"].validator.regex`. Returns `[]`
    /// when the provider does not expose this arg. Mirrors `aiartStyles`.
    public var homeDecorStyles: @Sendable (
        _ processType: WasmClient.HomeDecor.ProcessType
    ) async throws -> [WasmClient.HomeDecor.RoomStyle]

    /// Available room types for a process type, parsed from the active
    /// provider's `action.args["room_type"].validator.regex`.
    public var homeDecorRoomTypes: @Sendable (
        _ processType: WasmClient.HomeDecor.ProcessType
    ) async throws -> [WasmClient.HomeDecor.RoomType]

    /// Available color palettes for a process type (paint), parsed from the
    /// active provider's `action.args["color"].validator.regex`.
    public var homeDecorColorPalettes: @Sendable (
        _ processType: WasmClient.HomeDecor.ProcessType
    ) async throws -> [WasmClient.HomeDecor.ColorPalette]

    /// Available surface types for a process type (paint), parsed from the
    /// active provider's `action.args["surface_type"].validator.regex`.
    public var homeDecorSurfaceTypes: @Sendable (
        _ processType: WasmClient.HomeDecor.ProcessType
    ) async throws -> [WasmClient.HomeDecor.SurfaceType]

    /// Available style selections for a process type, parsed from the active
    /// provider's `action.args["style_selection"].validator.regex`.
    public var homeDecorStyleSelections: @Sendable (
        _ processType: WasmClient.HomeDecor.ProcessType
    ) async throws -> [WasmClient.HomeDecor.StyleSelection]

    // MARK: - Inpaint
    //
    // Rust derives the inpaint cache subdir internally from `TaskWasm.create()`,
    // so callers no longer pass a `cacheDir`. Mirrors flow-kit-example's
    // `Sources/InpaintSession.swift` post-1.2.47-26.1.1-ffi shape.

    /// Auto-detect objects in an image for removal suggestions.
    public var autoSuggestion: @Sendable (
        _ image: String
    ) async throws -> WasmClient.ObjectSegments

    /// Enhance (upscale) an image.
    public var enhance: @Sendable (
        _ image: String, _ zoomFactor: Int
    ) async throws -> WasmClient.ObjectSegments

    /// Remove background from an image.
    public var removeBackground: @Sendable (
        _ image: String
    ) async throws -> WasmClient.Segment

    /// Erase selected objects from an image.
    public var erase: @Sendable (
        _ image: String?,
        _ sessionId: String?,
        _ maskBrush: String?,
        _ maskObjects: String?
    ) async throws -> WasmClient.EraseResult

    /// Skin beauty filter.
    public var skinBeauty: @Sendable (
        _ image: String
    ) async throws -> WasmClient.ObjectSegments

    /// Sky segmentation.
    public var sky: @Sendable (
        _ image: String
    ) async throws -> WasmClient.Segment

    /// Categorize clothes from an image for virtual try-on.
    public var categorizeClothes: @Sendable (
        _ image: String
    ) async throws -> WasmClient.Segment

    /// Virtual try-on. Runs the full flow on the engine side (model/cloth
    /// checks → create → poll-to-done) and returns the finished image URL.
    public var tryOn: @Sendable (
        _ modelImage: String,
        _ clothImage: String
    ) async throws -> String

    // MARK: - Livescore Webpage

    /// Fetch the leagues directory as web pages (lsWebpage type=1).
    public var webpageLeagues: @Sendable () async throws -> [WasmClient.LiveScore.WebPage]

    /// Fetch the competitions directory as web pages (lsWebpage type=2).
    /// `q` runs a server-side full-text filter on name + region; `limit`/`offset`
    /// drive offset-based pagination — stop when a response returns fewer than
    /// `limit` rows. Backend clamps `limit` to `[1, 100]` (default 30 when nil).
    public var webpageCompetitions: @Sendable (
        _ q: String?,
        _ limit: Int64?,
        _ offset: Int64?
    ) async throws -> [WasmClient.LiveScore.WebPage]

    /// Fetch the teams directory as web pages (lsWebpage type=3).
    /// `q` runs a server-side full-text filter; `limit`/`offset` drive
    /// offset-based pagination — stop when a response returns fewer than
    /// `limit` rows. `competitionId` narrows to teams that played in the
    /// given competition (slug-form id, e.g. "competition/england-premier-league").
    public var webpageTeams: @Sendable (
        _ q: String?,
        _ limit: Int64?,
        _ offset: Int64?,
        _ competitionId: String?
    ) async throws -> [WasmClient.LiveScore.WebPage]

    /// Fetch a specific URL via lsWebpage (type=4).
    public var webpage: @Sendable (_ url: String) async throws -> [WasmClient.LiveScore.WebPage]

    /// Fetch the discover feed as web pages (lsWebpage type=5).
    public var webpageDiscovers: @Sendable () async throws -> [WasmClient.LiveScore.WebPage]

    /// Fetch one competition by numeric Scorebat id. Routes through
    /// `lsWebpage type=2` with an `id` filter and returns the single
    /// matching row (or nil when the backend doesn't know the id).
    public var webpageCompetition: @Sendable (
        _ id: String
    ) async throws -> WasmClient.LiveScore.WebPage?

    /// Fetch one team by numeric Scorebat id. Routes through
    /// `lsWebpage type=3` with an `id` filter and returns the single
    /// matching row (or nil when the backend doesn't know the id).
    public var webpageTeam: @Sendable (
        _ id: String
    ) async throws -> WasmClient.LiveScore.WebPage?

    /// Fetch Scorebat highlight videos (lsWebpage type=6). All filters are
    /// optional. `videoType` is the bucket tag (`"featured"` or `"livestream"`,
    /// `nil` = all). `competitionID` / `teamID` are slug strings from
    /// `WebPage.id` (e.g. `"team/real-madrid"`,
    /// `"competition/england-premier-league"`) and are mutually exclusive on
    /// the server side. `page` is 1-based; `pageSize` is clamped server-side
    /// to `[1, 60]` (default 20).
    public var webpageVideos: @Sendable (
        _ videoType: String?,
        _ competitionID: String?,
        _ teamID: String?,
        _ q: String?,
        _ page: Int64?,
        _ pageSize: Int64?
    ) async throws -> [WasmClient.LiveScore.WebPage]

    /// Fetch soccer news articles (lsWebpage type=7). Offset-based
    /// pagination — caller computes "has more" by comparing the returned
    /// count to `limit` (rows < limit ⇒ end of feed). `limit` is clamped
    /// server-side to `[1, 100]` (default 30); `q` is full-text search
    /// (≤200 chars). `competitionID` / `teamID` scope the feed to a single
    /// entity — the backend treats them as mutually exclusive when both
    /// are passed.
    public var webpageNews: @Sendable (
        _ limit: Int64?, _ offset: Int64?, _ q: String?,
        _ competitionID: String?, _ teamID: String?
    ) async throws -> [WasmClient.LiveScore.WebPage]

    /// Fetch the global upcoming-matches feed (no date arg).
    /// Backed by `lsUpcoming` action returning `LivescoreUpcomingMatchList`.
    public var upcoming: @Sendable () async throws -> [WasmClient.LiveScore.UpcomingMatch]

    /// Fetch matches for the given date (YYYY-MM-DD). Pass `nil` for "today" —
    /// the backend resolves it from the JWT `tz` claim (set in flowOptions
    /// from the device's current `TimeZone`). Rows are enriched with
    /// `competition{Image,Name,Region}` server-side.
    public var scoresByDate: @Sendable (
        _ date: String?
    ) async throws -> [WasmClient.LiveScore.UpcomingMatch]

    /// Enriched match detail (events, lineups, statistics, predictions,
    /// referee, venue, h2h, highlight videos). Independent of the `lsWebpage`
    /// catalog flow — fetch this when opening the match detail screen for
    /// a single fixture by id.
    public var matchDetail: @Sendable (
        _ id: String
    ) async throws -> WasmClient.LiveScore.Match

    /// Enriched competition detail (standings, stats, fixtures, top
    /// scorers/assists). `id` is the competition slug (e.g.
    /// `"competition/england-premier-league"`). Independent of the
    /// `lsWebpage` catalog flow.
    public var competitionDetail: @Sendable (
        _ id: String
    ) async throws -> WasmClient.LiveScore.Competition

    /// Enriched team detail (aka, fixtures, results, tables). `id` is the
    /// team slug (e.g. `"team/real-madrid"`). Independent of the `lsWebpage`
    /// catalog flow.
    public var teamDetail: @Sendable (
        _ id: String
    ) async throws -> WasmClient.LiveScore.Team

    /// Subscribe to the live `/soccer/events` Server-Sent Events stream. Yields
    /// `.connected` once the upstream connection is open, then `.update(_)` per
    /// `MatchUpdate` delta (goals, status changes, kickoff, halftime,
    /// full-time) as it arrives. The `.connected` event lets a consumer clear a
    /// "reconnecting" banner even during a quiet period with no goals. The
    /// stream runs until the consumer cancels it — dropping the `AsyncStream`
    /// (or cancelling the iterating task) tears down the underlying wasm task.
    /// Open/error paths finish the stream silently rather than throw, matching
    /// the noop default.
    public var liveMatchEvents: @Sendable () async -> AsyncStream<WasmClient.LiveScore.LiveEvent> = { AsyncStream { $0.finish() } }

    // MARK: - Survey

    /// Submit a completed survey. Builds the `qa_json` payload (a flat
    /// `{ qid: { question, answer } }` JSON string) from the questions +
    /// answers and stamps `completed_at` with the current ISO-8601 timestamp.
    /// Multi-select answers should be passed comma-joined in the answers map.
    /// Returns when the engine acknowledges the submission.
    public var submitSurvey: @Sendable (
        _ questions: [WasmClient.SurveyQuestion], _ answers: [String: String]
    ) async throws -> Void

    // MARK: - Notifications

    /// Register the device with the backend for push notifications.
    /// Pass an empty `firebaseToken` to deregister, or send `enabled: false` to
    /// stop delivery while keeping the token on file. `firebaseUID` lets the
    /// backend correlate device → user across reinstalls. `liveActivityToken`
    /// is the device-wide push-to-start token (iOS 17.2+); pass `""` when not
    /// applicable.
    public var setNotification: @Sendable (
        _ enabled: Bool, _ firebaseToken: String, _ firebaseUID: String?, _ liveActivityToken: String
    ) async throws -> Void

    /// Fetch current server-side notification settings (enabled + subscribed topics).
    public var getNotificationSettings: @Sendable () async throws -> WasmClient.NotificationSettings

    /// Subscribe (or unsubscribe) the device from notifications for an
    /// `(entity, id)` pair. `entity` is a free-form namespace string (e.g.
    /// `"competition"`, `"team"`); the backend keys (bundle_id, device_id,
    /// entity, id) and fans out push notifications without knowing about
    /// the originating feature. Consumer code that wants a typed entity
    /// enum can wrap this with its own `RawRepresentable where RawValue == String`.
    public var notificationSubscribe: @Sendable (
        _ entity: String, _ id: String, _ enabled: Bool
    ) async throws -> Void

    /// Forward an Apple Live Activity APNs push token to the backend.
    /// `entity` / `entityId` identify what the activity is tracking
    /// (e.g. `("match", "12345")`); `laToken` is lowercase hex, or `""`
    /// to retire the row after the activity ends or is dismissed.
    public var reportLiveActivityToken: @Sendable (
        _ entity: String, _ entityId: String, _ laToken: String
    ) async throws -> Void
}
