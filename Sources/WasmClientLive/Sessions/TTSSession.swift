@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Read Out Loud (TTS)

extension WasmActor {

    /// Invoke the `tts` action and return a typed audio payload. Mirrors
    /// flow-kit-example's `ChatView.playMessage`, but without playback or
    /// last-assistant-message gating (consumer concerns).
    ///
    /// `providerId` pins the call to a specific chat provider (matching
    /// flow-kit-example's `providerSettings.actions(for: tts).first(where:
    /// { $0.provider == provider.id })`). Pass empty to fall back to the
    /// delegate's default first-match resolution.
    ///
    /// On the first call against a given non-empty `providerId` this
    /// session, the pinned provider's `providerInit` is dispatched
    /// best-effort via `initializeChatProvider` — this matches the eager
    /// fan-out flow-kit-example performs in `fetchPage(initial:)`. The
    /// display name passed to init is whatever the host stored via
    /// `WasmClient.setUserName`; auto-init is skipped entirely when that
    /// name is empty (calling init with `""` would mark the provider as
    /// "tried" forever in this session, locking out a later retry once
    /// the consumer realizes they forgot to set the name). Per-session
    /// dedup lives in `WasmDelegate.initializedProviders` and is cleared
    /// on `reset()`.
    func readOutLoud(
        text: String,
        voice: String?,
        providerId: String
    ) async throws -> WasmClient.TTSAudio {
        let instance = try await readyEngine()

        // Auto-init the pinned provider once per session. CAI's `tts`
        // (replay) action rejects calls before `providerInit` has registered
        // the user; flow-kit-example handles this in `fetchPage(initial:)`,
        // we handle it here so consumers don't have to remember. Best-effort:
        // any genuine TTS failure surfaces from the downstream `create`.
        //
        // Skip when the host hasn't supplied a `userName` yet — running init
        // with an empty name marks the provider as initialized (failures are
        // sticky, mirroring flow-kit-example) and locks the consumer out for
        // the rest of the session. Falling through lets the consumer call
        // `setUserName` and retry.
        let userName = delegate.userName()
        if !providerId.isEmpty,
           !userName.isEmpty,
           !delegate.isProviderInitialized(providerId)
        {
            try? await initializeChatProvider(
                providerId: providerId,
                userName: userName
            )
        }

        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.tts.rawValue,
            preferredProvider: providerId.isEmpty ? nil : providerId,
            logger: logger
        )

        var args: [String: Google_Protobuf_Value] = [
            "input": .init(stringValue: text),
        ]
        if let voice, !voice.isEmpty {
            args["voice"] = .init(stringValue: voice)
        }

        // Run instance.create on the global executor, matching the
        // chatStream pattern. FlowKit's `create` blocks on a Rust-side
        // executor; calling it from this actor's isolation can return the
        // pending task before it has actually run, surfacing as
        // `status: .unspecified`.
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

    /// Look up the voice presets for a specific (provider, model) pair by
    /// reusing `chatModels`. Returns `[]` when the model is unknown or the
    /// provider doesn't surface `metadata.voices` (e.g. OpenAI's stock
    /// `tts` voices live elsewhere). The decode is the same one
    /// flow-kit-example performs against `ChatModelOption.voices`.
    func ttsVoices(providerId: String, modelId: String) async throws -> [String] {
        let (models, _) = try await chatModels(
            offset: 0, limit: 200, keyword: nil, category: nil
        )
        guard let model = models.first(where: {
            $0.providerId == providerId && $0.modelId == modelId
        }) else { return [] }
        return model.voices
    }
}
