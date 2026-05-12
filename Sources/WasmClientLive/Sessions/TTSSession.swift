@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Read Out Loud (TTS)

extension WasmActor {

    /// Invoke the `tts` action and return a typed audio payload. Mirrors
    /// flow-kit-example's `ChatView.playMessage`, but without playback or
    /// last-assistant-message gating (consumer concerns).
    func readOutLoud(text: String, voice: String?) async throws -> WasmClient.TTSAudio {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.tts.rawValue,
            logger: logger
        )

        var args: [String: Google_Protobuf_Value] = [
            "input": .init(stringValue: text),
        ]
        if let voice, !voice.isEmpty {
            args["voice"] = .init(stringValue: voice)
        }

        let task = try await instance.create(action: action, args: args)

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
           let url = URL(string: urlString) {
            return .url(url)
        }

        // Fallback: base64 bytes + optional MIME hint. Default to "mp3"
        // when audio_mime is absent, matching flow-kit-example's extension logic.
        if case .stringValue(let b64)? = payload.fields["audio_b64"]?.kind,
           !b64.isEmpty,
           let data = Data(base64Encoded: b64) {
            let mime: String = {
                if case .stringValue(let m)? = payload.fields["audio_mime"]?.kind,
                   !m.isEmpty {
                    return m
                }
                return "mp3"
            }()
            return .data(data, mime: mime)
        }

        throw WasmClient.Error.unexpectedResponseFormat
    }
}
