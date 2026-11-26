@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - OpenAI-plugin Voice API (Tts, ListProviders, UpdateVoice)
//
// `ListVoices`, `CreateVoice` and `DeleteVoice` live in `Chat.swift`. This file
// holds the calls that need arbitrary-text synthesis against a voice id, the
// `voice_creatable` provider flag (absent from the generated proto), and voice
// renaming. Distinct from the CAI replay-`tts` wrapped by `readOutLoud`.
extension WasmActor {

    /// Synthesize `input` against a specific voice UUID via the OpenAI-plugin
    /// `Tts` method. Unlike `readOutLoud` (CAI replay-tts), this accepts
    /// arbitrary text + a real voice UUID and returns freshly-synthesized
    /// audio. Mirrors flow-kit-example's `VoiceView.playVoice`.
    ///
    /// - Parameters:
    ///   - providerID: the voice's owning provider (`VoiceInfo.providerID`);
    ///     empty falls back to the backend's provider picker.
    ///   - input: text to speak.
    ///   - voiceID: provider-assigned voice UUID (`VoiceInfo.id`).
    func voiceTTS(
        providerID: String,
        input: String,
        voiceID: String,
        format: String = ""
    ) async throws -> WasmClient.Chat.TTSAudio {
        let instance = try await readyEngine()

        var args: [String: Google_Protobuf_Value] = [
            "input": .init(stringValue: input),
        ]
        if !voiceID.isEmpty {
            args["voice_id"] = .init(stringValue: voiceID)
        }
        // Output container hint (`mp3`/`wav`/`flac`/`opus`/`pcm16`). Forward
        // only when set so an empty value keeps the provider's default.
        if !format.isEmpty {
            args["format"] = .init(stringValue: format)
        }
        // `Tts` flattens `base.provider_id` into the top-level args (see the
        // example's `argsFromRequestFlatteningBase`); pass it directly.
        if !providerID.isEmpty {
            args["provider_id"] = .init(stringValue: providerID)
        }

        let argsCopy = args
        let task = try await Task.detached {
            try await instance.create(
                providerId: providerID,
                actionId: WasmClient.Chat.Method.tts.rawValue,
                args: argsCopy
            )
        }.value

        guard task.status == .completed else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
        guard task.hasValue else {
            throw WasmClient.Error.missingValue
        }
        return try Self.decodeTtsResponse([UInt8](task.value.value))
    }

    /// List OpenAI-plugin providers that can create voices, via the
    /// `ListProviders` method (filtered to `voice_creatable == true`).
    /// Mirrors flow-kit-example's `VoiceView` provider picker.
    func listVoiceProviders() async throws -> [WasmClient.Chat.ProviderInfo] {
        let instance = try await readyEngine()

        let task = try await Task.detached {
            try await instance.create(
                providerId: "",
                actionId: WasmClient.Chat.Method.listProviders.rawValue,
                args: [:]
            )
        }.value

        guard task.status == .completed else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
        guard task.hasValue else {
            throw WasmClient.Error.missingValue
        }
        return Self.decodeListProviders([UInt8](task.value.value))
    }

    /// Rename a voice via the `UpdateVoice` method. The request proto
    /// (`OpenAIUpdateVoiceRequest`) carries `id`, optional `name`,
    /// `visibility`, and `preview_text`; here we only send `id` + `name`
    /// (rename). `base.provider_id` is flattened into the top-level args,
    /// same as `Tts`/`CreateVoice`. Returns the updated `VoiceInfo`
    /// (response field 1 = `voice`, same shape as `CreateVoice`).
    func updateVoice(
        providerID: String,
        id: String,
        name: String
    ) async throws -> WasmClient.Chat.VoiceInfo {
        let instance = try await readyEngine()

        var args: [String: Google_Protobuf_Value] = [:]
        if !id.isEmpty {
            args["id"] = .init(stringValue: id)
        }
        if !name.isEmpty {
            args["name"] = .init(stringValue: name)
        }
        if !providerID.isEmpty {
            args["provider_id"] = .init(stringValue: providerID)
        }

        print(
            "[WasmClient][UpdateVoice] dispatch providerID='\(providerID)' voiceId='\(id)' name='\(name)'"
        )
        let argsCopy = args
        let task = try await Task.detached {
            try await instance.create(
                providerId: providerID,
                actionId: WasmClient.Chat.Method.updateVoice.rawValue,
                args: argsCopy
            )
        }.value

        let backendError = task.metadata.fields["error"]?.stringValue
        print(
            "[WasmClient][UpdateVoice] result status=\(task.status) hasValue=\(task.hasValue) error='\(backendError ?? "")'"
        )
        guard task.status == .completed else {
            throw WasmClient.Error.taskFailed(status: backendError ?? "\(task.status)")
        }
        guard task.hasValue else {
            throw WasmClient.Error.missingValue
        }
        // `UpdateVoiceResponse` shares `CreateVoiceResponse`'s wire shape
        // (field 1 = voice), and has no generated type of its own.
        let response = try OpenAICreateVoiceResponse(serializedBytes: task.value.value)
        guard response.hasVoice else {
            throw WasmClient.Error.unexpectedResponseFormat
        }
        let voice = Self.mapVoice(response.voice)
        print(
            "[WasmClient][UpdateVoice] decoded voiceId='\(voice.id)' name='\(voice.name)' providerID='\(voice.providerID)'"
        )
        return voice
    }

    // MARK: - Wire decoding

    /// Decode `OpenAITtsResponse`: 1 audio_url, 2 audio_b64, 3 audio_mime.
    /// Prefer the streamable URL; fall back to inline base64 bytes.
    static func decodeTtsResponse(_ bytes: [UInt8]) throws -> WasmClient.Chat.TTSAudio {
        var audioURL = ""
        var audioB64 = ""
        var audioMime = ""
        var reader = ProtoReader(bytes)
        while let (field, wire) = reader.nextTag() {
            switch (field, wire) {
            case (1, 2): audioURL = reader.readString() ?? ""
            case (2, 2): audioB64 = reader.readString() ?? ""
            case (3, 2): audioMime = reader.readString() ?? ""
            default:
                if !reader.skip(wire: wire) { break }
            }
        }
        if !audioURL.isEmpty, let url = URL(string: audioURL) {
            return .url(url)
        }
        if !audioB64.isEmpty, let data = Data(base64Encoded: audioB64) {
            return .data(data, mime: audioMime.isEmpty ? "mp3" : audioMime)
        }
        throw WasmClient.Error.unexpectedResponseFormat
    }

    /// Decode `OpenAIListProvidersResponse`: field 1 = repeated ProviderInfo.
    /// Keep only providers that can create voices (`voice_creatable == true`),
    /// mirroring flow-kit-example's `.filter(\.voiceCreatable)`.
    static func decodeListProviders(_ bytes: [UInt8]) -> [WasmClient.Chat.ProviderInfo] {
        var providers: [WasmClient.Chat.ProviderInfo] = []
        var reader = ProtoReader(bytes)
        while let (field, wire) = reader.nextTag() {
            switch (field, wire) {
            case (1, 2):
                guard let row = reader.readLengthDelimited() else { return providers }
                if let provider = decodeProviderInfo(row) { providers.append(provider) }
            default:
                if !reader.skip(wire: wire) { return providers }
            }
        }
        return providers
    }

    /// Decode one `OpenAIProviderInfo`: 1 id, 2 name, 3 creatable,
    /// 4 voice_creatable. Returns `nil` unless the provider can create voices.
    static func decodeProviderInfo(_ bytes: [UInt8]) -> WasmClient.Chat.ProviderInfo? {
        var id = ""
        var name = ""
        var creatable = false
        var voiceCreatable = false
        var reader = ProtoReader(bytes)
        while let (field, wire) = reader.nextTag() {
            switch (field, wire) {
            case (1, 2): id = reader.readString() ?? ""
            case (2, 2): name = reader.readString() ?? ""
            case (3, 0): creatable = (reader.readVarint() ?? 0) != 0
            case (4, 0): voiceCreatable = (reader.readVarint() ?? 0) != 0
            default:
                if !reader.skip(wire: wire) { break }
            }
        }
        guard !id.isEmpty, voiceCreatable else { return nil }
        return WasmClient.Chat.ProviderInfo(
            id: id,
            name: name.isEmpty ? id : name,
            creatable: creatable,
            voiceCreatable: true
        )
    }

}

// MARK: - Minimal protobuf wire reader

/// A tiny cursor over protobuf wire bytes, factored out of the ad-hoc decoders
/// in `ChatListModels.swift`. Only the wire types the voice messages use
/// (varint, length-delimited, 64-bit, 32-bit) are handled.
private struct ProtoReader {
    private let bytes: [UInt8]
    private var i = 0
    private let n: Int

    init(_ bytes: [UInt8]) {
        self.bytes = bytes
        self.n = bytes.count
    }

    mutating func readVarint() -> UInt64? {
        var shift: UInt64 = 0
        var result: UInt64 = 0
        while i < n {
            let b = bytes[i]; i += 1
            result |= UInt64(b & 0x7f) << shift
            if b & 0x80 == 0 { return result }
            shift += 7
            if shift > 63 { return nil }
        }
        return nil
    }

    /// Read the next field tag, returning `(fieldNumber, wireType)`.
    mutating func nextTag() -> (Int, Int)? {
        guard i < n, let tag = readVarint() else { return nil }
        return (Int(tag >> 3), Int(tag & 7))
    }

    /// Read a length-delimited payload (wire type 2) as raw bytes.
    mutating func readLengthDelimited() -> [UInt8]? {
        guard let len = readVarint(), i + Int(len) <= n else { return nil }
        let slice = Array(bytes[i..<i + Int(len)])
        i += Int(len)
        return slice
    }

    /// Read a length-delimited payload (wire type 2) as a UTF-8 string.
    mutating func readString() -> String? {
        guard let len = readVarint(), i + Int(len) <= n else { return nil }
        defer { i += Int(len) }
        return String(decoding: bytes[i..<i + Int(len)], as: UTF8.self)
    }

    /// Advance past a field of the given wire type. Returns false on malformed
    /// input so callers can bail.
    mutating func skip(wire: Int) -> Bool {
        switch wire {
        case 0: return readVarint() != nil
        case 1: i += 8; return i <= n
        case 2:
            guard let len = readVarint(), i + Int(len) <= n else { return false }
            i += Int(len); return true
        case 5: i += 4; return i <= n
        default: return false
        }
    }
}
