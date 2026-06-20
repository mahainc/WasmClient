@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - AI Art

extension WasmActor {

    /// Generate AI art using the specified action and flat string args.
    func aiartGenerate(
        actionID: String,
        args: [String: String]
    ) async throws -> WasmClient.AiartResult {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(actionID: actionID, logger: logger)

        var protoArgs: [String: Google_Protobuf_Value] = [:]
        for (key, value) in args where !value.isEmpty {
            protoArgs[key] = Google_Protobuf_Value(stringValue: value)
        }

        let result: AiartGenerateResult = try await instance.run(action: action, args: protoArgs)
        return mapAiartResult(result)
    }

    /// Read the valid style values from an aiart action's `style` arg
    /// regex validator. Returns an empty array if the validator is missing
    /// or the regex pattern cannot be parsed.
    func aiartStyles(actionID: String) async throws -> [String] {
        _ = try await readyEngine()
        let action = try await delegate.resolveAction(actionID: actionID, logger: logger)

        logger("aiartStyles: actionID=\(actionID) provider=\(action.provider) args=\(action.args.keys.sorted())")

        guard let styleArg = action.args["style"] else {
            logger("aiartStyles: no 'style' arg on action")
            return []
        }
        guard styleArg.hasValidator else {
            logger("aiartStyles: style arg has no validator")
            return []
        }
        guard case .string(let stringValidator) = styleArg.validator.data else {
            logger("aiartStyles: style validator is not a string validator (data=\(styleArg.validator.data as Any))")
            return []
        }
        guard stringValidator.hasRegex else {
            logger("aiartStyles: string validator has no regex")
            return []
        }

        let rawPattern = stringValidator.regex
        logger("aiartStyles: raw regex=\(rawPattern)")

        let parsed = Self.parseRegexAlternatives(rawPattern) ?? []
        logger("aiartStyles: parsed \(parsed.count) styles → \(parsed)")
        return parsed
    }

    /// Available `aspect_ratio` values for an aiart action, parsed from the
    /// action's `aspect_ratio` arg regex validator. Returns an empty array
    /// when the validator is missing or the regex cannot be parsed.
    func aiartAspectRatios(actionID: String) async throws -> [String] {
        _ = try await readyEngine()
        let action = try await delegate.resolveAction(actionID: actionID, logger: logger)

        logger(
            "aiartAspectRatios: actionID=\(actionID) provider=\(action.provider) args=\(action.args.keys.sorted())"
        )

        guard let ratioArg = action.args["aspect_ratio"] else {
            logger("aiartAspectRatios: no 'aspect_ratio' arg on action")
            return []
        }
        guard ratioArg.hasValidator else {
            logger("aiartAspectRatios: aspect_ratio arg has no validator")
            return []
        }
        guard case .string(let stringValidator) = ratioArg.validator.data else {
            logger("aiartAspectRatios: aspect_ratio validator is not a string validator")
            return []
        }
        guard stringValidator.hasRegex else {
            logger("aiartAspectRatios: string validator has no regex")
            return []
        }

        let rawPattern = stringValidator.regex
        logger("aiartAspectRatios: raw regex=\(rawPattern)")

        let parsed = Self.parseRegexAlternatives(rawPattern) ?? []
        logger("aiartAspectRatios: parsed \(parsed.count) ratios → \(parsed)")
        return parsed
    }

    /// Read the model catalog from an aiart action's `metadata.model_infos`
    /// list and `metadata.default_model`. Returns an empty catalog when the
    /// provider exposes no `model_infos` (single fixed model). Mirrors how
    /// flow-kit-example reads `AiArtPlugin::models()` from action metadata.
    func aiartModels(actionID: String) async throws -> WasmClient.AiartModelCatalog {
        _ = try await readyEngine()
        let action = try await delegate.resolveAction(actionID: actionID, logger: logger)

        guard case .listValue(let list)? = action.metadata.fields["model_infos"]?.kind else {
            logger("aiartModels: no 'model_infos' list in action metadata")
            return WasmClient.AiartModelCatalog()
        }

        let models = list.values.compactMap(Self.mapAiartModelInfo(_:))

        var defaultModelID: String?
        if case .stringValue(let s)? = action.metadata.fields["default_model"]?.kind, !s.isEmpty {
            defaultModelID = s
        }

        logger("aiartModels: parsed \(models.count) models, default=\(defaultModelID ?? "nil")")
        return WasmClient.AiartModelCatalog(models: models, defaultModelID: defaultModelID)
    }

    /// Map one `model_infos` entry (a protobuf struct) into `AiartModelInfo`.
    /// Returns nil when the entry has no usable `id`. Mirrors
    /// flow-kit-example's `AiartModelOption.init(value:)`.
    private static func mapAiartModelInfo(_ value: Google_Protobuf_Value) -> WasmClient.AiartModelInfo? {
        guard case .structValue(let s) = value.kind else { return nil }
        guard case .stringValue(let id)? = s.fields["id"]?.kind, !id.isEmpty else { return nil }

        let name: String = {
            if case .stringValue(let n)? = s.fields["name"]?.kind, !n.isEmpty { return n }
            return id
        }()
        let ownedBy: String = {
            if case .stringValue(let v)? = s.fields["owned_by"]?.kind { return v }
            return ""
        }()
        let vision: Bool = {
            guard case .structValue(let meta)? = s.fields["metadata"]?.kind else { return false }
            if case .boolValue(let b)? = meta.fields["vision"]?.kind { return b }
            return false
        }()
        let isPro: Bool = {
            guard case .structValue(let meta)? = s.fields["metadata"]?.kind else { return false }
            if case .boolValue(let b)? = meta.fields["is_pro"]?.kind { return b }
            return false
        }()

        return WasmClient.AiartModelInfo(
            modelID: id,
            name: name,
            ownedBy: ownedBy,
            vision: vision,
            isPro: isPro
        )
    }

    // MARK: - Aiart Video

    /// Submit a video generation task. Returns immediately with the initial
    /// snapshot — typically `.processing` and a `videoID` to poll. Mirrors
    /// flow-kit-example's two-phase create+poll pattern.
    ///
    /// On `.processing`, kicks a fire-and-forget `resumePendingTasks` so the
    /// engine actively polls every persisted descriptor (including this one)
    /// at 5s intervals, rewriting them on each tick and firing
    /// `pendingTasksChanged`. Observers (e.g. Profile → Videos) react to
    /// each emission and re-read `listPendingTasks` to surface progress.
    /// Without this kick the engine's auto-resume loop only sweeps tasks
    /// persisted before engine boot, so in-session creates would freeze at
    /// their initial progress.
    func aiartVideoCreate(args: [String: String]) async throws -> WasmClient.AiartVideoResult {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.aiartVideo.rawValue,
            logger: logger
        )

        var protoArgs: [String: Google_Protobuf_Value] = [:]
        for (key, value) in args where !value.isEmpty {
            protoArgs[key] = Google_Protobuf_Value(stringValue: value)
        }

        let task = try await instance.create(action: action, args: protoArgs)
        if task.status == .processing {
            await ensurePendingTasksResumeLoop()
        }
        return Self.mapAiartVideoTask(task)
    }

    /// Poll a video generation task by `videoID`. Reconstructs the WaTTask
    /// routing fields from the resolved `aiartVideo` action, calls
    /// `engine.status(task:)`, and maps the response.
    func aiartVideoStatus(videoID: String) async throws -> WasmClient.AiartVideoResult {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.aiartVideo.rawValue,
            logger: logger
        )
        guard let engine = instance as? TaskWasmEngine else {
            throw WasmClient.Error.engineNotReady
        }
        var taskRef = WaTTask()
        taskRef.id = videoID
        taskRef.provider = action.provider
        let updated = try await engine.status(task: taskRef)
        return Self.mapAiartVideoTask(updated)
    }

    /// Drive the video-generation polling loop. On each tick, fetches a
    /// fresh status snapshot, hands it to `onUpdate` for UI progress
    /// surfacing, and either returns (on `.completed`) or throws (on
    /// `.failed`). `Task.checkCancellation` is honoured both around the
    /// sleep and the network call so callers can cancel by cancelling
    /// the enclosing task — same pattern as flow-kit-example's
    /// `aiartVideoPoll`.
    func aiartVideoPoll(
        videoID: String,
        interval: TimeInterval,
        onUpdate: (@Sendable (WasmClient.AiartVideoResult) -> Void)?
    ) async throws -> WasmClient.AiartVideoResult {
        let nanos = UInt64(max(interval, 0.1) * 1_000_000_000)
        while true {
            try Task.checkCancellation()
            let snapshot = try await aiartVideoStatus(videoID: videoID)
            onUpdate?(snapshot)
            switch snapshot.status {
            case .completed:
                return snapshot
            case .failed(let message):
                throw WasmClient.Error.taskFailed(status: message)
            case .processing:
                try await Task.sleep(nanoseconds: nanos)
            }
        }
    }

    // MARK: - Aiart Mapping

    private static func mapAiartVideoTask(_ task: WaTTask) -> WasmClient.AiartVideoResult {
        var videoID = task.id
        var videoURL = ""
        var styledImageURL = ""
        var audioURL = ""
        var prompt = ""
        var artStyle = ""
        var progress = 0.0
        var statusString = ""
        var metadata: [String: String] = [:]

        if task.hasValue, let res = try? AiartVideoGenerateResult(unpackingAny: task.value) {
            if !res.videoID.isEmpty { videoID = res.videoID }
            videoURL = res.videoURL
            styledImageURL = res.styledImageURL
            audioURL = res.audioURL
            prompt = res.prompt
            artStyle = res.artStyle
            progress = res.progress
            statusString = res.status
            if res.hasMetadata {
                for (key, value) in res.metadata.fields {
                    if case .stringValue(let s) = value.kind {
                        metadata[key] = s
                    }
                }
            }
        }

        for (key, value) in task.metadata.fields {
            if case .stringValue(let s) = value.kind, metadata[key] == nil {
                metadata[key] = s
            }
        }

        let status: WasmClient.TaskStatus
        switch task.status {
        case .completed:
            status = .completed
        case .processing:
            status = .processing
        default:
            let errorMsg = metadata["error"]
                ?? task.metadata.fields["error"]?.stringValue
                ?? (statusString.isEmpty ? "\(task.status)" : statusString)
            status = .failed(errorMsg)
        }

        return WasmClient.AiartVideoResult(
            status: status,
            videoID: videoID,
            videoURL: videoURL,
            styledImageURL: styledImageURL,
            audioURL: audioURL,
            prompt: prompt,
            artStyle: artStyle,
            progress: progress,
            metadata: metadata
        )
    }

    private func mapAiartResult(_ proto: AiartGenerateResult) -> WasmClient.AiartResult {
        WasmClient.AiartResult(
            images: proto.images.compactMap { image in
                guard image.hasURL, !image.url.isEmpty else { return nil }
                return WasmClient.AiartImage(url: image.url)
            },
            prompt: proto.prompt,
            style: proto.hasStyle ? "\(proto.style)" : "",
            aspectRatio: proto.aspectRatio,
            width: Int(proto.width),
            height: Int(proto.height),
            providerTaskID: proto.providerTaskID
        )
    }

    /// Parse a regex alternation pattern of the form `^(A|B|C)$` into its
    /// individual alternatives. Returns nil if the pattern doesn't match
    /// the expected shape. Shared by aiart and homedecor schema helpers.
    static func parseRegexAlternatives(_ pattern: String) -> [String]? {
        guard pattern.hasPrefix("^("), pattern.hasSuffix(")$") else { return nil }
        let inner = String(pattern.dropFirst(2).dropLast(2))
        let values = inner.components(separatedBy: "|")
        return values.isEmpty ? nil : values
    }
}
