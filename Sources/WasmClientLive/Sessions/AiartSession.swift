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
    ) async throws -> WasmClient.AIArt.Result {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(actionID: actionID, logger: logger)

        var protoArgs: [String: Google_Protobuf_Value] = [:]
        for (key, value) in args where !value.isEmpty {
            protoArgs[key] = Google_Protobuf_Value(stringValue: value)
        }

        let result: AiartGenerateResult = try await instance.run(action: action, args: protoArgs)
        return mapAiartResult(result)
    }

    /// Per-mode model discovery for aiart. Dispatches the `ListModels` rpc by
    /// method name (`AIArt.Method.listModels`) — the engine resolves the
    /// provider via the persisted `provider_strategy`, mirroring
    /// `ScanSession.visualSearch`. Each `TypesModelInfo` row is mapped to a
    /// public `AIArt.Model`, reading `provider_id` + `aspect_ratios` from its
    /// `metadata` (same shape as flow-kit-example's `loadModels`).
    func aiartListModels(mode: WasmClient.AIArt.Mode) async throws -> WasmClient.AIArt.ModelList {
        let instance = try await readyEngine()

        var args: [String: Google_Protobuf_Value] = [:]
        if !mode.rawValue.isEmpty {
            args["mode"] = Google_Protobuf_Value(stringValue: mode.rawValue)
        }

        logger("aiartListModels: dispatch method=\(WasmClient.AIArt.Method.listModels.rawValue) mode=\(mode.rawValue)")
        let resp: AiartListModelsResponse = try await instance.run(
            method: WasmClient.AIArt.Method.listModels.rawValue,
            args: args
        )

        let models = resp.models.map { info in
            let providerID = info.metadata.fields["provider_id"]?.stringValue ?? ""
            let aspectRatios =
                info.metadata.fields["aspect_ratios"]?
                .listValue.values.map { $0.stringValue } ?? []
            return WasmClient.AIArt.Model(
                id: info.id,
                name: info.name,
                providerID: providerID,
                aspectRatios: aspectRatios
            )
        }
        logger("aiartListModels: decoded \(models.count) model(s), default=\(resp.defaultModelID)")
        return WasmClient.AIArt.ModelList(models: models, defaultModelID: resp.defaultModelID)
    }

    /// Read the valid style values from an aiart action's `style` arg
    /// regex validator. Returns an empty array if the validator is missing
    /// or the regex pattern cannot be parsed.
    func aiartStyles(actionID: String) async throws -> [WasmClient.AIArt.Style] {
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
        return parsed.map { WasmClient.AIArt.Style(rawValue: $0) }
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
    func aiartVideoCreate(args: [String: String]) async throws -> WasmClient.AIArt.VideoResult {
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
    func aiartVideoStatus(videoID: String) async throws -> WasmClient.AIArt.VideoResult {
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
        onUpdate: (@Sendable (WasmClient.AIArt.VideoResult) -> Void)?
    ) async throws -> WasmClient.AIArt.VideoResult {
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

    private static func mapAiartVideoTask(_ task: WaTTask) -> WasmClient.AIArt.VideoResult {
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
                let errorMsg =
                    metadata["error"]
                    ?? task.metadata.fields["error"]?.stringValue
                    ?? (statusString.isEmpty ? "\(task.status)" : statusString)
                status = .failed(errorMsg)
        }

        return WasmClient.AIArt.VideoResult(
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

    private func mapAiartResult(_ proto: AiartGenerateResult) -> WasmClient.AIArt.Result {
        WasmClient.AIArt.Result(
            images: proto.images.compactMap { image in
                guard image.hasURL, !image.url.isEmpty else { return nil }
                return WasmClient.AIArt.Image(url: image.url)
            },
            prompt: proto.prompt,
            style: proto.hasStyle ? Self.mapAiartStyle(proto.style) : WasmClient.AIArt.Style(rawValue: ""),
            aspectRatio: proto.aspectRatio,
            width: Int(proto.width),
            height: Int(proto.height),
            providerTaskID: proto.providerTaskID
        )
    }

    /// Map the `AiartStyle` proto enum to the public `AIArt.Style` whose
    /// `rawValue` is the wire name — keeping `Result.style` consistent with
    /// the wire-name values returned by `aiartStyles`. Unknown/unspecified
    /// values decay to an empty-rawValue `Style`.
    private static func mapAiartStyle(_ proto: AiartStyle) -> WasmClient.AIArt.Style {
        switch proto {
            case .anime: return .anime
            case .cyberpunk: return .cyberpunk
            case .watercolor: return .watercolor
            case .pixelArt: return .pixelArt
            case .threeDCartoon: return .threeDCartoon
            case .fantasy: return .fantasy
            case .oilPainting: return .oilPainting
            case .lineArt: return .lineArt
            case .minimal: return .minimal
            case .photoreal: return .photoreal
            case .postage: return .postage
            case .vintagePostage: return .vintagePostage
            case .waxSeal: return .waxSeal
            case .rubberStamp: return .rubberStamp
            case .engraved: return .engraved
            case .botanicalPostage: return .botanicalPostage
            case .unspecified, .UNRECOGNIZED: return WasmClient.AIArt.Style(rawValue: "")
        }
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
