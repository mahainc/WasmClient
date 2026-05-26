@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Notifications

extension WasmActor {

    /// Register / update the device's push-notification settings on the backend.
    /// Wraps the `notification_settings` action (`ActionID.notificationSettings`).
    /// `liveActivityToken` carries the device-wide push-to-start token
    /// (iOS 17.2+); pass `""` when not applicable.
    func setNotification(
        enabled: Bool,
        firebaseToken: String,
        firebaseUID: String?,
        liveActivityToken: String
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
        if !liveActivityToken.isEmpty {
            args["live_activity_token"] = Google_Protobuf_Value(stringValue: liveActivityToken)
        }
        // Must match the on-device `ActivityAttributes` struct name in
        // app773-live-score (see Features/Sources/LiveMatchAttributes); the
        // backend uses this as the APNs `attributes-type` header for
        // push-to-start and iOS silently drops mismatches.
        args["live_activity_attributes_type"] = Google_Protobuf_Value(stringValue: "LiveMatchAttributes")

        let argsCopy = args
        let task = try await Task.detached {
            try await instance.create(action: action, args: argsCopy)
        }.value
        guard task.status == .completed else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
    }

    /// Forward an Apple Live Activity APNs push token to the backend.
    /// Wraps the `live_activity_token` action. `laToken` is lowercase
    /// hex; pass `""` to retire the row when an activity ends or is
    /// dismissed.
    func reportLiveActivityToken(
        entity: String,
        entityId: String,
        laToken: String
    ) async throws {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.liveActivityToken.rawValue, logger: logger
        )
        let args: [String: Google_Protobuf_Value] = [
            "entity":    Google_Protobuf_Value(stringValue: entity),
            "entity_id": Google_Protobuf_Value(stringValue: entityId),
            "la_token":  Google_Protobuf_Value(stringValue: laToken),
        ]
        let argsCopy = args
        let task = try await Task.detached {
            try await instance.create(action: action, args: argsCopy)
        }.value
        guard task.status == .completed else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
    }

    /// Subscribe (or unsubscribe) the device from notifications for an
    /// `(entity, id)` pair. `enabled` MUST be sent as the literal string
    /// `"true"` / `"false"` — the Rust task-validator reads args via
    /// `string_for_field`, and boolean/number protobuf values are treated
    /// as missing, failing the required-arg check.
    func notificationSubscribe(
        entity: String,
        id: String,
        enabled: Bool
    ) async throws {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.notificationSubscribe.rawValue, logger: logger
        )
        let args: [String: Google_Protobuf_Value] = [
            "entity": Google_Protobuf_Value(stringValue: entity),
            "id": Google_Protobuf_Value(stringValue: id),
            "enabled": Google_Protobuf_Value(stringValue: enabled ? "true" : "false"),
        ]
        let argsCopy = args
        let task = try await Task.detached {
            try await instance.create(action: action, args: argsCopy)
        }.value
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
        let task = try await Task.detached {
            try await instance.create(action: action, args: [:])
        }.value
        guard task.status == .completed else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
        let enabled = task.metadata.fields["enabled"]?.boolValue ?? true
        let topics = task.metadata.fields["topics"]?
            .listValue.values.compactMap { $0.stringValue } ?? []
        return WasmClient.NotificationSettings(enabled: enabled, topics: topics)
    }
}
