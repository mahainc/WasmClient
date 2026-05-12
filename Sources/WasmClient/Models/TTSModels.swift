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
}
