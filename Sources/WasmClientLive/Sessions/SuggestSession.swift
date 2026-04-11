@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Suggest

extension WasmActor {

    /// Get AI-generated prompt suggestions.
    ///
    /// Mirrors flow-kit-example's `AiartView.fetchSuggestions()`
    /// (AiartView.swift:291-312): resolve action, pass `system_prompt` and
    /// optional `image_url`, decode `TypesListStrings`, return empty on failure.
    func suggest(systemPrompt: String, imageURL: String?) async throws -> [String] {
        let instance = try await readyEngine()
        let action = try await delegate.resolveNextAction(
            actionID: WasmClient.ActionID.suggest.rawValue, logger: logger
        )
        var args: [String: Google_Protobuf_Value] = [
            "system_prompt": Google_Protobuf_Value(stringValue: systemPrompt),
        ]
        if let imageURL, !imageURL.isEmpty {
            args["image_url"] = Google_Protobuf_Value(stringValue: imageURL)
        }
        logger("Suggest: creating task with args: \(args.keys.sorted().joined(separator: ", "))")
        let task = try await instance.create(action: action, args: args)
        logger("Suggest: task status=\(task.status) hasValue=\(task.hasValue)")
        guard task.status == .completed, task.hasValue else {
            logger("Suggest: task not completed or no value — returning empty")
            return []
        }
        do {
            let list = try TypesListStrings(unpackingAny: task.value)
            logger("Suggest: decoded \(list.values.count) suggestions")
            return list.values
        } catch {
            logger("Suggest: TypesListStrings decode failed: \(error)")
            return []
        }
    }
}
