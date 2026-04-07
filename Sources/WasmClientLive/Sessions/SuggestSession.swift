@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Suggest

extension WasmActor {

    /// Get AI-generated prompt suggestions.
    func suggest(systemPrompt: String, imageURL: String?) async throws -> [String] {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.suggest.rawValue, logger: logger
        )
        var args: [String: Google_Protobuf_Value] = [
            "system_prompt": Google_Protobuf_Value(stringValue: systemPrompt),
        ]
        if let imageURL, !imageURL.isEmpty {
            args["image_url"] = Google_Protobuf_Value(stringValue: imageURL)
        }
        let task = try await instance.create(action: action, args: args)
        guard task.status == .completed else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
        guard task.hasValue else {
            return []
        }
        if let list = try? TypesListStrings(unpackingAny: task.value), !list.values.isEmpty {
            return list.values
        }
        if let list = try? TypesListStrings(serializedBytes: task.value.value), !list.values.isEmpty {
            return list.values
        }
        return []
    }
}
