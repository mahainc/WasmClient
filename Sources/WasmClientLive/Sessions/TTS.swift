@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Read Out Loud (TTS)

extension WasmActor {

    func readOutLoud(
        text: String,
        voice: String?,
        providerID: String
    ) async throws -> WasmClient.Chat.TTSAudio {
        let instance = try await readyEngine()

        let userName = delegate.userName()
        if !providerID.isEmpty,
            !userName.isEmpty,
            !delegate.isProviderInitialized(providerID)
        {
            try? await initializeChatProvider(
                providerID: providerID,
                userName: userName
            )
        }

        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.tts.rawValue,
            preferredProvider: providerID.isEmpty ? nil : providerID,
            logger: logger
        )

        var args: [String: Google_Protobuf_Value] = [
            "input": .init(stringValue: text)
        ]
        if let voice, !voice.isEmpty {
            args["voice"] = .init(stringValue: voice)
        }

        let argsCopy = args
        let task = try await Task.detached {
            try await instance.create(action: action, args: argsCopy)
        }.value

        guard task.status == .completed else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
        guard task.hasValue else {
            throw WasmClient.Error.missingValue
        }
        // The engine returns a typed `asyncify.openai.TtsResponse`, not a
        // generic Struct.
        return try Self.decodeTtsResponse([UInt8](task.value.value))
    }

    func ttsVoices(
        providerID: String,
        modelID: String
    ) async throws -> [String] {
        let (models, _) = try await chatModels(
            offset: 0,
            limit: 200,
            keyword: nil,
            category: nil
        )
        guard
            let model = models.first(where: {
                $0.providerID == providerID && $0.modelID == modelID
            })
        else { return [] }
        return model.voices
    }
}
