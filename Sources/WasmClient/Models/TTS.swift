import Foundation

// MARK: - TTS

extension WasmClient.Chat {
    public enum TTSAudio: Sendable, Equatable {
        case url(URL)
        case data(Data, mime: String)
    }
}
