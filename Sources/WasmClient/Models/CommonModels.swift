import Foundation

// MARK: - Action ID

extension WasmClient {
    /// All known WASM action IDs matching Rust constants.
    public enum ActionID: String, CaseIterable, Sendable {
        // OpenAI
        case chat = "5e1ab91a-ac32-4269-9e20-4d864df4112d"
        case suggest = "b2d4e6f8-1a3c-5e7g-9i0k-2m4o6q8s0u2w"
        case listModels = "c3d5e7f9-2b4d-6e8f-0a1c-3e5f7b9d1c3e"
        case createModel = "d4e5f6a7-b8c9-4d1e-a2f3-4b5c6d7e8f90"
        /// Pre-flight bootstrap for chat providers that need register
        /// (e.g. CAI). Default providers are no-ops and return Completed
        /// immediately. Call once per provider before invoking
        /// `createChatModel` / `chatStream` against that provider —
        /// without it CAI rejects subsequent calls with `unspecified`.
        case providerInit = "f1c8d4a2-3b5e-4d7f-9a1c-6e8b0d2f4a3c"
        // TTS / Read Out Loud
        case tts = "e5f6a7b8-c9d0-4e1f-a2b3-4c5d6e7f8091"
        // Vision
        case scan = "d4e5f6a7-3b2c-1d0e-9f8a-7b6c5d4e3f2a"
        case visualSearch = "e5f6a7b8-4c3d-2e1f-0a9b-8c7d6e5f4a3b"
        case shopping = "f6a7b8c9-5d4e-3f2a-1b0c-9d8e7f6a5b4c"
        case describe = "a7b8c9d0-6e5f-4a3b-2c1d-0e9f8a7b6c5d"
        // Blobstore
        case upload = "c3f5a7b9-2d4e-6f8a-0c2e-4g6i8k0m2o4q"
        // Inpaint
        case autoSuggestion = "0d6339a1-ea1c-432e-b8d5-9bc0f7d5fe09"
        case enhance = "4425e05a-cf76-4f3f-923e-249494e636bf"
        case removeBg = "1abf881d-23fe-452b-9615-f7c22176e5b3"
        case erase = "c98b41f5-c69b-4dcd-85c0-c01937a56dd9"
        case sky = "30eefa03-bf11-4c33-b397-e5d7015a2bfa"
        case skinBeauty = "64c2e11a-8f23-4c26-8720-e4a065337e2a"
        case tryOn = "75958fa2-978f-41e4-9d4a-a41a645bc59a"
        case clothes = "4b545ec7-c0f2-40d0-a6c1-ff0c39656f62"
        // Music
        case discover = "0e425df1-fcda-4489-969a-d4350392a016"
        case details = "1b1bcaf6-01fc-40b4-83b8-36915d9e505c"
        case tracks = "a9b31651-43b3-415a-b99c-00468be15e28"
        case search = "5d922423-a6fb-4302-b951-ac074c681b7c"
        case lyrics = "47575b25-3d87-4c9d-96d5-a681d064884b"
        case related = "5c770798-6c09-4dd7-8e77-5bab032c269b"
        // Suggestion
        case musicSuggestion = "c5edf8f6-e18d-4a9d-acef-27d19fbb909a"
        // Aiart
        case aiartStamp = "b7e5fcb7-4746-4f79-b2b9-a78c7b574001"
        case aiartNormal = "b7e5fcb7-4746-4f79-b2b9-a78c7b574002"
        case aiartVideo = "b7e5fcb7-4746-4f79-b2b9-a78c7b574004"
        // Visual / Media
        case searchPhotos = "f1a2b3c4-5d6e-7f8a-9b0c-1d2e3f4a5b6c"
        case photoVisualSearch = "a7b8c9d0-1e2f-3a4b-5c6d-7e8f9a0b1c2d"
        case listMedia = "b2c3d4e5-6f7a-8b9c-0d1e-2f3a4b5c6d7e"
        // Homedecor
        case interiorDesign = "6e9ba966-b677-4de4-acab-32711586f52a"
        case exteriorDesign = "6e9ba966-b677-4de4-acab-32711586f52b"
        case gardenDesign = "6e9ba966-b677-4de4-acab-32711586f52c"
        case paintRoom = "6e9ba966-b677-4de4-acab-32711586f52d"
        case replaceObjects = "6e9ba966-b677-4de4-acab-32711586f52e"
        case floorRestyle = "6e9ba966-b677-4de4-acab-32711586f52f"
        case referenceStyle = "6e9ba966-b677-4de4-acab-327115870530"
        case roomStaging = "6e9ba966-b677-4de4-acab-327115870531"
        case declutterRoom = "6e9ba966-b677-4de4-acab-327115870532"
        case floorPlan = "6e9ba966-b677-4de4-acab-327115870533"
        case planToImage = "6e9ba966-b677-4de4-acab-327115870534"
        // Livescore — the single livescore action discriminates rows via
        // `type` (WebPageType: 1=leagues, 2=competitions, 3=teams, 4=page,
        // 5=discovers, 6=videos, 7=news). Videos and news used to live on
        // separate UUIDs (`lsHighlights`, `lsNews`) which the server has
        // since retired.
        case lsWebpage = "b2d4f6a8-3c5e-4b7d-9f1a-2c3d4e5f6a7b"
        case lsUpcoming = "c3e5a7b9-4d6f-4c8e-a0b2-3d4e5f6a7b8c"
        case lsScores = "d4f6a8b0-5e7f-4d9a-b1c3-4e5f6a7b8c9d"
        /// Enriched match detail (events, lineups, statistics, predictions,
        /// referee, venue, h2h, highlight videos). Returns a `LivescoreMatch`
        /// proto with the full nested payload — independent of the `lsWebpage`
        /// catalog flow.
        case lsMatchDetail = "a7c9d1e3-8192-50ad-e4f6-71829304e5f6"
        /// Enriched competition detail (standings, stats, fixtures, top
        /// scorers/assists). Returns a `LivescoreCompetition` proto. Backed by
        /// a single synchronous fetch — no WebPage involvement.
        case lsCompetitionDetail = "e5a7b9c1-6f80-4e0b-c2d4-5f607182c3d4"
        /// Enriched team detail (aka, fixtures, results, tables). Returns a
        /// `LivescoreTeam` proto. Backed by a single synchronous fetch — no
        /// WebPage involvement.
        case lsTeamDetail = "f6b8c0d2-7081-4f1c-d3e5-60718293d4e5"
        /// Server-Sent Events stream of `LivescoreMatchUpdate` deltas
        /// (`/soccer/events`). The stream runs for the life of the wasm task
        /// — cancel the consumer to close it.
        case lsLiveEvents = "2417a638-d9a8-4394-9f3a-50add84e12d7"
        // Surveys
        case submitSurvey = "e7c3a1d0-8b4f-5d2e-9a1c-3f6e8d2b4a0c"
        // Notifications
        case notificationSettings = "b8f4c2e0-5d7a-6b9f-0e3c-2a1d4f6b8c0e"
        case getNotificationSettings = "c9a5d3f1-6e8b-4c0d-9f4a-3b5e7d9f1a3c"
        case notificationSubscribe = "f8c2b4e0-1d5a-4e7c-9b3f-2a4d6e8c0b1a"
        /// Forwards an Apple Live Activity APNs push token to the
        /// backend so it can target updates by `(bundle_id, device_id,
        /// entity, entity_id)`. Send `la_token: ""` to retire the row
        /// after an activity ends or is dismissed.
        case liveActivityToken = "a3d9e5c1-7b2f-4e1d-8c4a-9f5e3b7d2c6e"
    }
}

// MARK: - Error

extension WasmClient {
    /// Typed errors for all client operations.
    public enum Error: Swift.Error, Sendable, Equatable, LocalizedError {
        case engineNotReady
        case engineNotStarted
        case engineInitFailed
        case noProviderFound(action: String)
        case taskFailed(status: String)
        case missingValue
        case uploadFailed(String)
        case unexpectedResponseFormat

        public var errorDescription: String? {
            switch self {
            case .engineNotReady:
                "The WASM engine is not ready. Please try again."
            case .engineNotStarted:
                "The WASM engine has not been started. Call start() first."
            case .engineInitFailed:
                "The WASM engine failed to initialize."
            case .noProviderFound(let action):
                "No provider found for action: \(action)"
            case .taskFailed(let status):
                "Task did not complete (status: \(status))"
            case .missingValue:
                "Task completed without a value"
            case .uploadFailed(let reason):
                "Upload failed: \(reason)"
            case .unexpectedResponseFormat:
                "Unexpected response data format"
            }
        }
    }
}
