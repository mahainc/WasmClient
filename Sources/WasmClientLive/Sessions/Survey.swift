@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Survey

extension WasmActor {

    func submitSurvey(
        questions: [WasmClient.Survey.Question],
        answers: [String: String]
    ) async throws {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.submitSurvey.rawValue,
            logger: logger
        )

        let qaJson = Self.buildQAJson(questions: questions, answers: answers)
        let completedAt = ISO8601DateFormatter().string(from: Date())

        let args: [String: Google_Protobuf_Value] = [
            "qa_json": Google_Protobuf_Value(stringValue: qaJson),
            "completed_at": Google_Protobuf_Value(stringValue: completedAt),
        ]
        let task = try await instance.create(action: action, args: args)
        guard task.status == .completed else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
    }

    private static func buildQAJson(
        questions: [WasmClient.Survey.Question],
        answers: [String: String]
    ) -> String {
        var dict: [String: [String: String]] = [:]
        for q in questions {
            dict[q.id] = [
                "question": q.text,
                "answer": answers[q.id] ?? "",
            ]
        }
        guard
            let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
            let json = String(data: data, encoding: .utf8)
        else { return "{}" }
        return json
    }
}
