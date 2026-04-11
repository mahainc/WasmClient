@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Suggest

extension WasmActor {

    /// Get AI-generated prompt suggestions.
    ///
    /// Tries all available providers (round-robin order) until one returns
    /// non-empty suggestions. Some providers return a valid but empty
    /// `TypesListStrings` — cycling through providers handles this gracefully.
    func suggest(systemPrompt: String, imageURL: String?) async throws -> [String] {
        let instance = try await readyEngine()
        let actions = try await delegate.resolveAllActions(
            actionID: WasmClient.ActionID.suggest.rawValue, logger: logger
        )
        var args: [String: Google_Protobuf_Value] = [
            "system_prompt": Google_Protobuf_Value(stringValue: systemPrompt),
        ]
        if let imageURL, !imageURL.isEmpty {
            args["image_url"] = Google_Protobuf_Value(stringValue: imageURL)
        }
        logger("Suggest: \(actions.count) providers available, args: \(args.keys.sorted().joined(separator: ", "))")

        for (index, action) in actions.enumerated() {
            logger("Suggest: trying provider \(index + 1)/\(actions.count) (\(action.provider.prefix(12))…)")
            do {
                let task = try await instance.create(action: action, args: args)
                logger("Suggest: provider \(index + 1) status=\(task.status) hasValue=\(task.hasValue)")
                guard task.status == .completed, task.hasValue else { continue }
                let list = try TypesListStrings(unpackingAny: task.value)
                if !list.values.isEmpty {
                    logger("Suggest: provider \(index + 1) returned \(list.values.count) suggestions")
                    return list.values
                }
                logger("Suggest: provider \(index + 1) returned 0 suggestions — trying next")
            } catch {
                logger("Suggest: provider \(index + 1) failed: \(error) — trying next")
            }
        }

        logger("Suggest: all \(actions.count) providers returned empty — returning []")
        return []
    }
}
