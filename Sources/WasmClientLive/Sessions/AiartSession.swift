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

    // MARK: - Aiart Mapping

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
}
