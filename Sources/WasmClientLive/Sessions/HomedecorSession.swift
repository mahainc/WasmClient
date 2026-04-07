@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Home Decor

extension WasmActor {

    /// Generate a home decor design. May return `.processing` — poll via `homeDesignStatus`.
    func homeDesign(
        actionID: String,
        args: [String: String]
    ) async throws -> WasmClient.HomedecorResult {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(actionID: actionID, logger: logger)

        var protoArgs: [String: Google_Protobuf_Value] = [:]
        for (key, value) in args where !value.isEmpty {
            protoArgs[key] = Google_Protobuf_Value(stringValue: value)
        }

        let task = try await instance.create(action: action, args: protoArgs)
        return mapHomedecorTask(task)
    }

    /// Poll a home decor task by ID.
    func homeDesignStatus(taskID: String) async throws -> WasmClient.HomedecorResult {
        let instance = try await readyEngine()
        var taskRef = WaTTask()
        taskRef.id = taskID
        guard let engine = instance as? TaskWasmEngine else {
            throw WasmClient.Error.engineNotReady
        }
        let updated = try await engine.status(task: taskRef)
        return mapHomedecorTask(updated)
    }

    // MARK: - Homedecor Mapping

    private func mapHomedecorTask(_ task: WaTTask) -> WasmClient.HomedecorResult {
        let status: WasmClient.TaskStatus
        var imageURL = ""
        var inputImageURL = ""
        var metadata: [String: String] = [:]

        switch task.status {
        case .completed:
            status = .completed
            if task.hasValue {
                if let res = try? HomedecorGenerateResult(unpackingAny: task.value) {
                    if res.hasResult { imageURL = res.result.url }
                    if res.hasInput { inputImageURL = res.input.url }
                } else if let res = try? HomedecorGenerateResult(serializedBytes: task.value.value) {
                    if res.hasResult { imageURL = res.result.url }
                    if res.hasInput { inputImageURL = res.input.url }
                }
            }
        case .processing:
            status = .processing
        default:
            let errorMsg = task.metadata.fields["error"]?.stringValue ?? "\(task.status)"
            status = .failed(errorMsg)
        }

        // Extract metadata from task
        for (key, value) in task.metadata.fields {
            if case .stringValue(let s) = value.kind {
                metadata[key] = s
            }
        }

        return WasmClient.HomedecorResult(
            status: status,
            imageURL: imageURL,
            inputImageURL: inputImageURL,
            taskID: task.id,
            metadata: metadata
        )
    }
}
