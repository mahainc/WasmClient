@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - AI Art

extension WasmActor {

    func generateAIArt(_ request: WasmClient.AIArt.ImageRequest) async throws -> WasmClient.AIArt.ImageResult {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: Self.aiartActionID(for: request.kind),
            logger: logger
        )

        let result: AiartGenerateResult = try await instance.run(
            action: action,
            args: Self.protoArgs(from: request.toWireArgs())
        )
        return Self.mapAiartResult(result)
    }

    func loadAIArtModelCatalog(mode: WasmClient.AIArt.Mode) async throws -> WasmClient.AIArt.ModelCatalog {
        let instance = try await readyEngine()

        var args: [String: Google_Protobuf_Value] = [:]
        if !mode.rawValue.isEmpty {
            args["mode"] = Google_Protobuf_Value(stringValue: mode.rawValue)
        }

        let method = WasmClient.AIArt.ServiceMethod.listModels.rawValue
        logger("loadAIArtModelCatalog: dispatch method=\(method) mode=\(mode.rawValue)")
        let resp: AiartListModelsResponse = try await instance.run(
            method: WasmClient.AIArt.ServiceMethod.listModels.rawValue,
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
        logger("loadAIArtModelCatalog: decoded \(models.count) model(s), default=\(resp.defaultModelID)")
        return WasmClient.AIArt.ModelCatalog(models: models, defaultModelID: resp.defaultModelID)
    }

    func listAIArtStyles(kind: WasmClient.AIArt.ImageRequest.Kind) async throws -> [WasmClient.AIArt.Style] {
        _ = try await readyEngine()
        let actionID = Self.aiartActionID(for: kind)
        let action = try await delegate.resolveAction(actionID: actionID, logger: logger)

        logger(
            "listAIArtStyles: kind=\(kind.rawValue) actionID=\(actionID) provider=\(action.provider) "
                + "args=\(action.args.keys.sorted())"
        )

        guard let styleArg = action.args["style"] else {
            logger("listAIArtStyles: no 'style' arg on action")
            return []
        }
        guard styleArg.hasValidator else {
            logger("listAIArtStyles: style arg has no validator")
            return []
        }
        guard case .string(let stringValidator) = styleArg.validator.data else {
            logger(
                "listAIArtStyles: style validator is not a string validator (data=\(styleArg.validator.data as Any))"
            )
            return []
        }
        guard stringValidator.hasRegex else {
            logger("listAIArtStyles: string validator has no regex")
            return []
        }

        let rawPattern = stringValidator.regex
        logger("listAIArtStyles: raw regex=\(rawPattern)")

        let parsed = Self.parseRegexAlternatives(rawPattern) ?? []
        logger("listAIArtStyles: parsed \(parsed.count) styles → \(parsed)")
        return parsed.map { WasmClient.AIArt.Style(rawValue: $0) }
    }

    // MARK: - AIArt Video

    func submitAIArtVideo(_ request: WasmClient.AIArt.VideoRequest) async throws -> WasmClient.AIArt.VideoTaskSnapshot {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.aiartVideo.rawValue,
            logger: logger
        )

        let task = try await instance.create(action: action, args: Self.protoArgs(from: request.toWireArgs()))
        if task.status == .processing {
            await ensurePendingTasksResumeLoop()
        }
        return Self.mapAiartVideoTask(task)
    }

    func getAIArtVideoStatus(videoID: String) async throws -> WasmClient.AIArt.VideoTaskSnapshot {
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

    func pollAIArtVideo(
        videoID: String,
        interval: TimeInterval,
        onUpdate: (@Sendable (WasmClient.AIArt.VideoTaskSnapshot) -> Void)?
    ) async throws -> WasmClient.AIArt.VideoTaskSnapshot {
        let nanos = UInt64(max(interval, 0.1) * 1_000_000_000)
        while true {
            try Task.checkCancellation()
            let snapshot = try await getAIArtVideoStatus(videoID: videoID)
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

    // MARK: - AIArt Mapping

    private static func aiartActionID(for kind: WasmClient.AIArt.ImageRequest.Kind) -> String {
        kind.rawValue == WasmClient.AIArt.ImageRequest.Kind.stamp.rawValue
            ? WasmClient.ActionID.aiartStamp.rawValue
            : WasmClient.ActionID.aiartNormal.rawValue
    }

    private static func protoArgs(from args: [String: String]) -> [String: Google_Protobuf_Value] {
        var protoArgs: [String: Google_Protobuf_Value] = [:]
        for (key, value) in args where !value.isEmpty {
            protoArgs[key] = Google_Protobuf_Value(stringValue: value)
        }
        return protoArgs
    }

    private static func mapAiartVideoTask(_ task: WaTTask) -> WasmClient.AIArt.VideoTaskSnapshot {
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
                    if case .stringValue(let stringValue) = value.kind {
                        metadata[key] = stringValue
                    }
                }
            }
        }

        for (key, value) in task.metadata.fields {
            if case .stringValue(let stringValue) = value.kind, metadata[key] == nil {
                metadata[key] = stringValue
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

        return WasmClient.AIArt.VideoTaskSnapshot(
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

    private static func mapAiartResult(_ proto: AiartGenerateResult) -> WasmClient.AIArt.ImageResult {
        WasmClient.AIArt.ImageResult(
            images: proto.images.compactMap { image in
                guard image.hasURL, !image.url.isEmpty else { return nil }
                return WasmClient.AIArt.Image(url: image.url)
            },
            prompt: proto.prompt,
            style: proto.hasStyle ? Self.mapAiartStyle(proto.style) : .unspecified,
            aspectRatio: proto.aspectRatio,
            width: Int(proto.width),
            height: Int(proto.height),
            providerTaskID: proto.providerTaskID
        )
    }

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
            case .unspecified, .UNRECOGNIZED: return .unspecified
        }
    }

    static func parseRegexAlternatives(_ pattern: String) -> [String]? {
        guard pattern.hasPrefix("^("), pattern.hasSuffix(")$") else { return nil }
        let inner = String(pattern.dropFirst(2).dropLast(2))
        let values = inner.components(separatedBy: "|")
        return values.isEmpty ? nil : values
    }
}
