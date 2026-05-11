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
            // The engine returns `.unspecified` for video tasks that are
            // still queued / processing on the server — and ships them
            // with an empty `statusString` and no error metadata. The
            // descriptor it writes to disk in the same call carries a
            // monotonically increasing progress. Only treat the response
            // as a hard failure when there's an explicit failure signal;
            // otherwise keep polling.
            let upper = statusString.uppercased()
            let hasError = metadata["error"] != nil
                || task.metadata.fields["error"]?.stringValue != nil
            let isExplicitFailure = upper == "FAILED"
                || upper == "ERRORED"
                || upper == "ERROR"
            if hasError || isExplicitFailure {
                let errorMsg = metadata["error"]
                    ?? task.metadata.fields["error"]?.stringValue
                    ?? (statusString.isEmpty ? "\(task.status)" : statusString)
                status = .failed(errorMsg)
            } else {
                status = .processing
            }
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
    /// the expected shape. This matches the format used by aiart action
    /// schema validators.
    private static func parseRegexAlternatives(_ pattern: String) -> [String]? {
        guard pattern.hasPrefix("^("), pattern.hasSuffix(")$") else { return nil }
        let inner = String(pattern.dropFirst(2).dropLast(2))
        let values = inner.components(separatedBy: "|")
        return values.isEmpty ? nil : values
    }
}
