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
