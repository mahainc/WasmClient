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
        guard let payload = try? Google_Protobuf_Struct(unpackingAny: task.value) else {
            throw WasmClient.Error.unexpectedResponseFormat
        }

        // Prefer audio_url — streamable, no decode cost.
        if case .stringValue(let urlString)? = payload.fields["audio_url"]?.kind,
            !urlString.isEmpty,
            let url = URL(string: urlString)
        {
            return .url(url)
        }

        // Fallback: base64 bytes + optional MIME hint. Default to "mp3"
        // when audio_mime is absent, matching flow-kit-example's extension logic.
        if case .stringValue(let b64)? = payload.fields["audio_b64"]?.kind,
            !b64.isEmpty,
            let data = Data(base64Encoded: b64)
        {
            let mime: String = {
                if case .stringValue(let m)? = payload.fields["audio_mime"]?.kind,
                    !m.isEmpty
                {
                    return m
                }
                return "mp3"
            }()
            return .data(data, mime: mime)
        }

        throw WasmClient.Error.unexpectedResponseFormat
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
