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
        let task = try await instance.create(action: action, args: args)
        guard task.status == .completed, task.hasValue else { return [] }
        guard let list = try? TypesListStrings(unpackingAny: task.value),
              !list.values.isEmpty
        else { return [] }
        return list.values
    }
}
