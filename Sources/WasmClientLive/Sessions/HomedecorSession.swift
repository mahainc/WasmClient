@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Home Decor

extension WasmActor {

    /// Generate a home decor design. Polls automatically if the task returns `.processing`,
    /// matching flow-kit-example's pattern of passing the original task to `status()`.
    func homeDesign(
        actionID: String,
        args: [String: String]
    ) async throws -> WasmClient.HomedecorResult {
        let instance = try await readyEngine()
        let action = try await delegate.resolveNextAction(actionID: actionID, logger: logger)

        var protoArgs: [String: Google_Protobuf_Value] = [:]
        for (key, value) in args where !value.isEmpty {
            protoArgs[key] = Google_Protobuf_Value(stringValue: value)
        }

        var task = try await instance.create(action: action, args: protoArgs)

        // Poll if processing — pass the original task object so all routing fields
        // (action_id, provider_id) are preserved, matching flow-kit-example's approach.
        if task.status == .processing {
            guard let engine = instance as? TaskWasmEngine else {
                throw WasmClient.Error.engineNotReady
            }
            let deadline = Date().addingTimeInterval(120)
            while task.status == .processing, Date() < deadline {
                try await Task.sleep(nanoseconds: 3_000_000_000)
                task = try await engine.status(task: task)
                logger("homedecor poll: status=\(task.status) id=\(task.id)")
            }
        }

        return mapHomedecorTask(task)
    }

    /// Poll a home decor task by ID (unused — polling is now built into homeDesign).
    func homeDesignStatus(taskID: String, actionID: String) async throws -> WasmClient.HomedecorResult {
        // Re-create the task via the action to get all routing fields, then poll.
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(actionID: actionID, logger: logger)
        guard let engine = instance as? TaskWasmEngine else {
            throw WasmClient.Error.engineNotReady
        }
        var taskRef = WaTTask()
        taskRef.id = taskID
        taskRef.provider = action.provider
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
