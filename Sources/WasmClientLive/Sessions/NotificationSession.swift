@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Notifications

extension WasmActor {

    /// Register / update the device's push-notification settings on the backend.
    /// Wraps the `notification_settings` action (`ActionID.notificationSettings`).
    func setNotification(
        enabled: Bool,
        firebaseToken: String,
        firebaseUID: String?
    ) async throws {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.notificationSettings.rawValue, logger: logger
        )

        var args: [String: Google_Protobuf_Value] = [
            "enabled": Google_Protobuf_Value(stringValue: enabled ? "true" : "false"),
        ]
        if !firebaseToken.isEmpty {
            args["firebase_token"] = Google_Protobuf_Value(stringValue: firebaseToken)
        }
        if let uid = firebaseUID, !uid.isEmpty {
            args["firebase_uid"] = Google_Protobuf_Value(stringValue: uid)
        }

        let task = try await instance.create(action: action, args: args)
        guard task.status == .completed else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
    }

    /// Fetch current server-side notification settings.
    /// Wraps the `get_notification_settings` action.
    func getNotificationSettings() async throws -> WasmClient.NotificationSettings {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.getNotificationSettings.rawValue, logger: logger
        )
        let task = try await instance.create(action: action, args: [:])
        guard task.status == .completed else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
        let enabled = task.metadata.fields["enabled"]?.boolValue ?? true
        let topics = task.metadata.fields["topics"]?
            .listValue.values.compactMap { $0.stringValue } ?? []
        return WasmClient.NotificationSettings(enabled: enabled, topics: topics)
    }
}
