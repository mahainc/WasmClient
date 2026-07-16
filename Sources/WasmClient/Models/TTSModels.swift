import Foundation

// MARK: - TTS

extension WasmClient {
    /// Result of a read-out-loud (TTS) call. Providers return either a
    /// streamable URL or inline audio bytes — never both. WasmClient does
    /// not perform playback; consumers wire `AVPlayer` (or equivalent).
    public enum TTSAudio: Sendable, Equatable {
        /// Streamable remote audio. Hand directly to `AVPlayer(url:)`.
        case url(URL)
        /// Inline audio bytes plus the provider-supplied MIME hint
        /// (e.g. `"audio/mpeg"`, `"wav"`, `"mp3"`). Falls back to `"mp3"`
        /// when the provider omits `audio_mime`.
        case data(Data, mime: String)
    }

    /// A backend voice catalog entry from the OpenAI-plugin `ListVoices`
    /// action (`/serverless/mobile/voices`). Unlike `ChatModelInfo.voices`
    /// (bare preset name strings usable only with CAI replay-`tts`), each
    /// `VoiceInfo` carries a provider-assigned `id` (a real voice UUID) that
    /// synthesizes arbitrary text via the OpenAI-plugin `Tts` action, plus a
    /// ready-made `previewAudioURL` / `previewText` for a no-synthesis
    /// preview. Mirrors flow-kit-example's `OpenAIVoiceInfo`.
    public struct VoiceInfo: Sendable, Equatable, Identifiable {
        /// Provider-assigned voice UUID. Pass as `voiceID` to `voiceTTS`.
        public let id: String
        /// Human-readable display name (e.g. "Aria", "Narrator").
        public let name: String
        /// Suggested sample line for previewing this voice, or "".
        public let previewText: String
        /// Pre-rendered preview clip URL, or `nil` when the backend omits it.
        public let previewAudioURL: URL?
        /// Voice gender label as reported by the backend (raw enum name), or "".
        public let gender: String
        /// Visibility label (e.g. "public", "private"), or "".
        public let visibility: String
        /// How this voice was created — `"file"`/`"generated"` for user-made
        /// voices, `""` for the default catalog. Mirrors flow-kit-example's
        /// `sourceType`.
        public let sourceType: String
        /// Device/user id of whoever created this voice, or "". Compare against
        /// `UIDevice.current.identifierForVendor` to tell "my voices" from the
        /// shared defaults, as flow-kit-example's `isOwner` does.
        public let creatorId: String
        /// Provider that owns this voice — pass to `voiceTTS`'s `providerId`.
        public let providerId: String

        public init(
            id: String,
            name: String,
            previewText: String,
            previewAudioURL: URL?,
            gender: String,
            visibility: String,
            sourceType: String = "",
            creatorId: String = "",
            providerId: String
        ) {
            self.id = id
            self.name = name
            self.previewText = previewText
            self.previewAudioURL = previewAudioURL
            self.gender = gender
            self.visibility = visibility
            self.sourceType = sourceType
            self.creatorId = creatorId
            self.providerId = providerId
        }
    }

    /// A backend provider entry from the OpenAI-plugin `ListProviders` action.
    /// Used to populate the "create voice on which provider" picker. Mirrors
    /// flow-kit-example's `OpenAIProviderInfo` (filtered to `voiceCreatable`).
    public struct VoiceProviderInfo: Sendable, Equatable, Identifiable {
        /// Provider id — pass as `providerId` to `createVoice`.
        public let id: String
        /// Human-readable display name.
        public let name: String

        public init(id: String, name: String) {
            self.id = id
            self.name = name
        }
    }
}
