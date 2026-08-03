@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Notifications

extension WasmActor {

    func setNotification(
        enabled: Bool,
        firebaseToken: String,
        firebaseUID: String?,
        liveActivityToken: String,
        liveActivityAttributesType: WasmClient.Notification.LiveActivityAttributesType?
    ) async throws {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.notificationSettings.rawValue,
            logger: logger
        )

        var args: [String: Google_Protobuf_Value] = [
            "enabled": Google_Protobuf_Value(stringValue: enabled ? "true" : "false")
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
        if let type = liveActivityAttributesType?.rawValue, !type.isEmpty {
            args["live_activity_attributes_type"] = Google_Protobuf_Value(stringValue: type)
        }

        let argsCopy = args
        let task = try await Task.detached {
            try await instance.create(action: action, args: argsCopy)
        }.value
        guard task.status == .completed else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
    }

    func reportLiveActivityToken(
        entity: String,
        entityID: String,
        laToken: String
    ) async throws {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.liveActivityToken.rawValue,
            logger: logger
        )
        let args: [String: Google_Protobuf_Value] = [
            "entity": Google_Protobuf_Value(stringValue: entity),
            "entity_id": Google_Protobuf_Value(stringValue: entityID),
            "la_token": Google_Protobuf_Value(stringValue: laToken),
        ]
        let argsCopy = args
        let task = try await Task.detached {
            try await instance.create(action: action, args: argsCopy)
        }.value
        guard task.status == .completed else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
    }

    func notificationSubscribe(
        entity: String,
        id: String,
        enabled: Bool
    ) async throws {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.notificationSubscribe.rawValue,
            logger: logger
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

    func getNotificationSettings() async throws -> WasmClient.Notification.Settings {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.getNotificationSettings.rawValue,
            logger: logger
        )
        let task = try await Task.detached {
            try await instance.create(action: action, args: [:])
        }.value
        guard task.status == .completed else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
        let enabled = task.metadata.fields["enabled"]?.boolValue ?? true
        let topics =
            task.metadata.fields["topics"]?
            .listValue.values.compactMap { $0.stringValue } ?? []
        return WasmClient.Notification.Settings(enabled: enabled, topics: topics)
    }
}
