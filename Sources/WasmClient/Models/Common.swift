import Foundation

// MARK: - Action ID

extension WasmClient {
    public struct ActionID: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        // OpenAI
        public static let chat = Self(rawValue: "5e1ab91a-ac32-4269-9e20-4d864df4112d")
        public static let suggest = Self(rawValue: "b2d4e6f8-1a3c-5e7g-9i0k-2m4o6q8s0u2w")
        public static let listModels = Self(rawValue: "c3d5e7f9-2b4d-6e8f-0a1c-3e5f7b9d1c3e")
        public static let createModel = Self(rawValue: "d4e5f6a7-b8c9-4d1e-a2f3-4b5c6d7e8f90")
        public static let providerInit = Self(rawValue: "f1c8d4a2-3b5e-4d7f-9a1c-6e8b0d2f4a3c")
        // TTS / Read Out Loud
        public static let tts = Self(rawValue: "e5f6a7b8-c9d0-4e1f-a2b3-4c5d6e7f8091")
        // Vision
        public static let scan = Self(rawValue: "d4e5f6a7-3b2c-1d0e-9f8a-7b6c5d4e3f2a")
        public static let visualSearch = Self(rawValue: "e5f6a7b8-4c3d-2e1f-0a9b-8c7d6e5f4a3b")
        public static let shopping = Self(rawValue: "f6a7b8c9-5d4e-3f2a-1b0c-9d8e7f6a5b4c")
        public static let describe = Self(rawValue: "a7b8c9d0-6e5f-4a3b-2c1d-0e9f8a7b6c5d")
        // Blobstore
        public static let upload = Self(rawValue: "c3f5a7b9-2d4e-6f8a-0c2e-4g6i8k0m2o4q")
        // Inpaint
        public static let autoSuggestion = Self(rawValue: "0d6339a1-ea1c-432e-b8d5-9bc0f7d5fe09")
        public static let enhance = Self(rawValue: "4425e05a-cf76-4f3f-923e-249494e636bf")
        public static let removeBg = Self(rawValue: "1abf881d-23fe-452b-9615-f7c22176e5b3")
        public static let erase = Self(rawValue: "c98b41f5-c69b-4dcd-85c0-c01937a56dd9")
        public static let sky = Self(rawValue: "30eefa03-bf11-4c33-b397-e5d7015a2bfa")
        public static let skinBeauty = Self(rawValue: "64c2e11a-8f23-4c26-8720-e4a065337e2a")
        public static let tryOn = Self(rawValue: "75958fa2-978f-41e4-9d4a-a41a645bc59a")
        public static let clothes = Self(rawValue: "4b545ec7-c0f2-40d0-a6c1-ff0c39656f62")
        // Music
        public static let discover = Self(rawValue: "0e425df1-fcda-4489-969a-d4350392a016")
        public static let details = Self(rawValue: "1b1bcaf6-01fc-40b4-83b8-36915d9e505c")
        public static let tracks = Self(rawValue: "a9b31651-43b3-415a-b99c-00468be15e28")
        public static let search = Self(rawValue: "5d922423-a6fb-4302-b951-ac074c681b7c")
        public static let lyrics = Self(rawValue: "47575b25-3d87-4c9d-96d5-a681d064884b")
        public static let related = Self(rawValue: "5c770798-6c09-4dd7-8e77-5bab032c269b")
        // Suggestion
        public static let musicSuggestion = Self(rawValue: "c5edf8f6-e18d-4a9d-acef-27d19fbb909a")
        // Aiart
        public static let aiartStamp = Self(rawValue: "b7e5fcb7-4746-4f79-b2b9-a78c7b574001")
        public static let aiartNormal = Self(rawValue: "b7e5fcb7-4746-4f79-b2b9-a78c7b574002")
        public static let aiartVideo = Self(rawValue: "b7e5fcb7-4746-4f79-b2b9-a78c7b574004")
        // Visual / Media
        public static let searchPhotos = Self(rawValue: "f1a2b3c4-5d6e-7f8a-9b0c-1d2e3f4a5b6c")
        public static let photoVisualSearch = Self(rawValue: "a7b8c9d0-1e2f-3a4b-5c6d-7e8f9a0b1c2d")
        public static let listMedia = Self(rawValue: "b2c3d4e5-6f7a-8b9c-0d1e-2f3a4b5c6d7e")
        // Homedecor
        public static let interiorDesign = Self(rawValue: "6e9ba966-b677-4de4-acab-32711586f52a")
        public static let exteriorDesign = Self(rawValue: "6e9ba966-b677-4de4-acab-32711586f52b")
        public static let gardenDesign = Self(rawValue: "6e9ba966-b677-4de4-acab-32711586f52c")
        public static let paintRoom = Self(rawValue: "6e9ba966-b677-4de4-acab-32711586f52d")
        public static let replaceObjects = Self(rawValue: "6e9ba966-b677-4de4-acab-32711586f52e")
        public static let floorRestyle = Self(rawValue: "6e9ba966-b677-4de4-acab-32711586f52f")
        public static let referenceStyle = Self(rawValue: "6e9ba966-b677-4de4-acab-327115870530")
        public static let roomStaging = Self(rawValue: "6e9ba966-b677-4de4-acab-327115870531")
        public static let declutterRoom = Self(rawValue: "6e9ba966-b677-4de4-acab-327115870532")
        public static let floorPlan = Self(rawValue: "6e9ba966-b677-4de4-acab-327115870533")
        public static let planToImage = Self(rawValue: "6e9ba966-b677-4de4-acab-327115870534")
        public static let lsWebpage = Self(rawValue: "b2d4f6a8-3c5e-4b7d-9f1a-2c3d4e5f6a7b")
        public static let lsUpcoming = Self(rawValue: "c3e5a7b9-4d6f-4c8e-a0b2-3d4e5f6a7b8c")
        public static let lsScores = Self(rawValue: "d4f6a8b0-5e7f-4d9a-b1c3-4e5f6a7b8c9d")
        public static let lsMatchDetail = Self(rawValue: "a7c9d1e3-8192-50ad-e4f6-71829304e5f6")
        public static let lsCompetitionDetail = Self(rawValue: "e5a7b9c1-6f80-4e0b-c2d4-5f607182c3d4")
        public static let lsTeamDetail = Self(rawValue: "f6b8c0d2-7081-4f1c-d3e5-60718293d4e5")
        public static let lsLiveEvents = Self(rawValue: "2417a638-d9a8-4394-9f3a-50add84e12d7")
        // Surveys
        public static let submitSurvey = Self(rawValue: "e7c3a1d0-8b4f-5d2e-9a1c-3f6e8d2b4a0c")
        // Notifications
        public static let notificationSettings = Self(rawValue: "b8f4c2e0-5d7a-6b9f-0e3c-2a1d4f6b8c0e")
        public static let getNotificationSettings = Self(rawValue: "c9a5d3f1-6e8b-4c0d-9f4a-3b5e7d9f1a3c")
        public static let notificationSubscribe = Self(rawValue: "f8c2b4e0-1d5a-4e7c-9b3f-2a4d6e8c0b1a")
        public static let liveActivityToken = Self(rawValue: "a3d9e5c1-7b2f-4e1d-8c4a-9f5e3b7d2c6e")
    }
}

// MARK: - Vision Method

extension WasmClient {
    public struct VisionMethod: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static let scan = Self(rawValue: "asyncify.vision.VisionService/Scan")
        public static let visualSearch = Self(rawValue: "asyncify.vision.VisionService/VisualSearch")
        public static let shopping = Self(rawValue: "asyncify.vision.VisionService/Shopping")
        public static let describe = Self(rawValue: "asyncify.vision.VisionService/Describe")
    }
}

// MARK: - Task Status

extension WasmClient {
    public enum TaskStatus: Sendable, Equatable, Hashable {
        case processing
        case completed
        case failed(String)
    }
}

// MARK: - Error

extension WasmClient {
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
