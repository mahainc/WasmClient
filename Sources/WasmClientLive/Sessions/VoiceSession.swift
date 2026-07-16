@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - OpenAI-plugin Voice API (ListVoices + Tts)
//
// This is the flow-kit-example voice path, distinct from the CAI replay-`tts`
// wrapped by `readOutLoud`/`ttsVoices`:
//
//   * `readOutLoud` dispatches the synthetic UUID `ActionID.tts`
//     (`e5f6a7b8-…`) — a *replay* action that only re-serves audio already
//     generated for a prior chat message. It rejects arbitrary preview text
//     against a chat-model preset voice name with a backend `403`.
//   * The functions here dispatch the OpenAI-plugin service methods by their
//     wire method name (`asyncify.openai.OpenAIService/ListVoices` and
//     `.../Tts`) via `create(providerId:actionId:args:)` — the exact path
//     flow-kit-example's `VoiceView` uses (`eng.openAI.listVoices` /
//     `eng.openAI.tts(voiceID:)`). `ListVoices` returns real voice UUIDs +
//     preview clips; `Tts` synthesizes arbitrary text against a voice UUID.
//
// `create(providerId:actionId:args:)` is a `TaskWasmProtocol` requirement (a
// method-name dispatch that bypasses the UUID action cache), so these methods
// work without registering a synthetic `ActionID`. Response payloads are typed
// protobuf messages (not `google.protobuf.Struct`), decoded here from the wire
// bytes to avoid pulling a generated `.pb.swift` into WasmClient — same
// approach as `ChatSession+ListModels`.
extension WasmActor {

    /// OpenAI-plugin service method names, dispatched by `create(actionId:)`.
    private enum OpenAIMethod {
        static let listVoices = "asyncify.openai.OpenAIService/ListVoices"
        static let tts = "asyncify.openai.OpenAIService/Tts"
        static let listProviders = "asyncify.openai.OpenAIService/ListProviders"
        static let createVoice = "asyncify.openai.OpenAIService/CreateVoice"
        static let deleteVoice = "asyncify.openai.OpenAIService/DeleteVoice"
        static let updateVoice = "asyncify.openai.OpenAIService/UpdateVoice"
    }

    /// Fetch the backend voice catalog via the OpenAI-plugin `ListVoices`
    /// method. Each row carries a provider-assigned voice UUID (`id`) that
    /// `voiceTTS` can synthesize against, plus an optional pre-rendered
    /// `previewAudioURL` / `previewText`. Mirrors flow-kit-example's
    /// `VoiceView.loadVoices()`.
    ///
    /// - Parameters:
    ///   - keyword: optional name filter (empty = all).
    ///   - offset / limit: pagination window.
    func listVoices(
        keyword: String?,
        offset: Int,
        limit: Int
    ) async throws -> [WasmClient.VoiceInfo] {
        let instance = try await readyEngine()

        var args: [String: Google_Protobuf_Value] = [
            "offset": .init(numberValue: Double(offset)),
            "limit": .init(numberValue: Double(limit)),
        ]
        if let trimmed = keyword?.trimmingCharacters(in: .whitespaces),
           !trimmed.isEmpty {
            args["keyword"] = .init(stringValue: trimmed)
        }

        // Method-name dispatch on the global executor, matching the other
        // one-shot `create` sites (FlowKit's `create` blocks on a Rust-side
        // executor; running it off this actor's isolation avoids a premature
        // `.unspecified` return).
        let argsCopy = args
        let task = try await Task.detached {
            try await instance.create(
                providerId: "",
                actionId: OpenAIMethod.listVoices,
                args: argsCopy
            )
        }.value

        guard task.status == .completed else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
        guard task.hasValue else {
            throw WasmClient.Error.missingValue
        }
        return Self.decodeListVoices([UInt8](task.value.value))
    }

    /// Synthesize `input` against a specific voice UUID via the OpenAI-plugin
    /// `Tts` method. Unlike `readOutLoud` (CAI replay-tts), this accepts
    /// arbitrary text + a real voice UUID and returns freshly-synthesized
    /// audio. Mirrors flow-kit-example's `VoiceView.playVoice`.
    ///
    /// - Parameters:
    ///   - providerId: the voice's owning provider (`VoiceInfo.providerId`);
    ///     empty falls back to the backend's provider picker.
    ///   - input: text to speak.
    ///   - voiceID: provider-assigned voice UUID (`VoiceInfo.id`).
    func voiceTTS(
        providerId: String,
        input: String,
        voiceID: String,
        format: String = ""
    ) async throws -> WasmClient.TTSAudio {
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
        if !providerId.isEmpty {
            args["provider_id"] = .init(stringValue: providerId)
        }

        let argsCopy = args
        let task = try await Task.detached {
            try await instance.create(
                providerId: providerId,
                actionId: OpenAIMethod.tts,
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
    func listVoiceProviders() async throws -> [WasmClient.VoiceProviderInfo] {
        let instance = try await readyEngine()

        let task = try await Task.detached {
            try await instance.create(
                providerId: "",
                actionId: OpenAIMethod.listProviders,
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

    /// Clone a new voice from recorded/uploaded audio via the `CreateVoice`
    /// method. Mirrors flow-kit-example's `VoiceView.createVoice`. Returns the
    /// newly-created `VoiceInfo` (field 1 of the response).
    ///
    /// - Parameters:
    ///   - providerId: provider to create on; empty falls back to the picker.
    ///   - name: display name (3–20 chars).
    ///   - audio: `file://` URL string or `data:` URI of the source audio.
    ///   - gender: optional raw gender name.
    ///   - visibility: optional raw visibility.
    func createVoice(
        providerId: String,
        name: String,
        audio: String,
        gender: String?,
        visibility: String?
    ) async throws -> WasmClient.VoiceInfo {
        let instance = try await readyEngine()

        // `CreateVoice` flattens `base.provider_id` into the top-level args
        // (same as `Tts`); pass snake_case keys matching the request proto
        // name map (name, audio, gender, visibility, provider_id).
        var args: [String: Google_Protobuf_Value] = [:]
        if !name.isEmpty {
            args["name"] = .init(stringValue: name)
        }
        if !audio.isEmpty {
            args["audio"] = .init(stringValue: audio)
        }
        if let gender, !gender.isEmpty {
            args["gender"] = .init(stringValue: gender)
        }
        if let visibility, !visibility.isEmpty {
            args["visibility"] = .init(stringValue: visibility)
        }
        if !providerId.isEmpty {
            args["provider_id"] = .init(stringValue: providerId)
        }

        let argsCopy = args
        let task = try await Task.detached {
            try await instance.create(
                providerId: providerId,
                actionId: OpenAIMethod.createVoice,
                args: argsCopy
            )
        }.value

        guard task.status == .completed else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
        guard task.hasValue else {
            throw WasmClient.Error.missingValue
        }
        guard let voice = Self.decodeCreateVoice([UInt8](task.value.value)) else {
            throw WasmClient.Error.unexpectedResponseFormat
        }
        return voice
    }

    /// Delete a voice by its provider-assigned id via the `DeleteVoice`
    /// method. The response is empty; a completed task is success.
    func deleteVoice(providerId: String, id: String) async throws {
        let instance = try await readyEngine()

        var args: [String: Google_Protobuf_Value] = [:]
        if !id.isEmpty {
            args["id"] = .init(stringValue: id)
        }
        if !providerId.isEmpty {
            args["provider_id"] = .init(stringValue: providerId)
        }

        let argsCopy = args
        let task = try await Task.detached {
            try await instance.create(
                providerId: providerId,
                actionId: OpenAIMethod.deleteVoice,
                args: argsCopy
            )
        }.value

        guard task.status == .completed else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
    }

    /// Rename a voice via the `UpdateVoice` method. The request proto
    /// (`OpenAIUpdateVoiceRequest`) carries `id`, optional `name`,
    /// `visibility`, and `preview_text`; here we only send `id` + `name`
    /// (rename). `base.provider_id` is flattened into the top-level args,
    /// same as `Tts`/`CreateVoice`. Returns the updated `VoiceInfo`
    /// (response field 1 = `voice`, same shape as `CreateVoice`).
    func updateVoice(
        providerId: String,
        id: String,
        name: String
    ) async throws -> WasmClient.VoiceInfo {
        let instance = try await readyEngine()

        var args: [String: Google_Protobuf_Value] = [:]
        if !id.isEmpty {
            args["id"] = .init(stringValue: id)
        }
        if !name.isEmpty {
            args["name"] = .init(stringValue: name)
        }
        if !providerId.isEmpty {
            args["provider_id"] = .init(stringValue: providerId)
        }

        print(
            "[WasmClient][UpdateVoice] dispatch providerId='\(providerId)' voiceId='\(id)' name='\(name)'"
        )
        let argsCopy = args
        let task = try await Task.detached {
            try await instance.create(
                providerId: providerId,
                actionId: OpenAIMethod.updateVoice,
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
        guard let voice = Self.decodeCreateVoice([UInt8](task.value.value)) else {
            throw WasmClient.Error.unexpectedResponseFormat
        }
        print(
            "[WasmClient][UpdateVoice] decoded voiceId='\(voice.id)' name='\(voice.name)' providerId='\(voice.providerId)'"
        )
        return voice
    }

    // MARK: - Wire decoding

    /// Decode `OpenAIListVoicesResponse`: field 1 = repeated VoiceInfo message,
    /// field 2 = total, field 3 = offset, field 4 = limit. We only need the
    /// voice rows.
    static func decodeListVoices(_ bytes: [UInt8]) -> [WasmClient.VoiceInfo] {
        var voices: [WasmClient.VoiceInfo] = []
        var reader = ProtoReader(bytes)
        while let (field, wire) = reader.nextTag() {
            switch (field, wire) {
            case (1, 2):
                guard let row = reader.readLengthDelimited() else { return voices }
                if let voice = decodeVoiceInfo(row) { voices.append(voice) }
            default:
                if !reader.skip(wire: wire) { return voices }
            }
        }
        return voices
    }

    /// Decode one `OpenAIVoiceInfo`: 1 id, 2 name, 3 preview_text,
    /// 4 preview_audio_url, 5 gender (enum), 6 visibility (enum),
    /// 7 source_type, 8 creator_id, 9 created_at, 10 updated_at,
    /// 11 provider_id. We surface id/name/preview/gender/visibility/provider.
    static func decodeVoiceInfo(_ bytes: [UInt8]) -> WasmClient.VoiceInfo? {
        var id = ""
        var name = ""
        var previewText = ""
        var previewAudioURLString = ""
        var gender = ""
        var visibility = ""
        var sourceType = ""
        var creatorId = ""
        var providerId = ""
        var reader = ProtoReader(bytes)
        while let (field, wire) = reader.nextTag() {
            switch (field, wire) {
            case (1, 2): id = reader.readString() ?? ""
            case (2, 2): name = reader.readString() ?? ""
            case (3, 2): previewText = reader.readString() ?? ""
            case (4, 2): previewAudioURLString = reader.readString() ?? ""
            case (5, 0): gender = voiceGenderName(reader.readVarint() ?? 0)
            case (6, 0): visibility = voiceVisibilityName(reader.readVarint() ?? 0)
            case (7, 0): sourceType = voiceSourceName(reader.readVarint() ?? 0)
            case (8, 2): creatorId = reader.readString() ?? ""
            case (11, 2): providerId = reader.readString() ?? ""
            default:
                if !reader.skip(wire: wire) { break }
            }
        }
        guard !id.isEmpty else { return nil }
        return WasmClient.VoiceInfo(
            id: id,
            name: name.isEmpty ? id : name,
            previewText: previewText,
            previewAudioURL: previewAudioURLString.isEmpty
                ? nil : URL(string: previewAudioURLString),
            gender: gender,
            visibility: visibility,
            sourceType: sourceType,
            creatorId: creatorId,
            providerId: providerId
        )
    }

    /// Decode `OpenAITtsResponse`: 1 audio_url, 2 audio_b64, 3 audio_mime.
    /// Prefer the streamable URL; fall back to inline base64 bytes.
    static func decodeTtsResponse(_ bytes: [UInt8]) throws -> WasmClient.TTSAudio {
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
    static func decodeListProviders(_ bytes: [UInt8]) -> [WasmClient.VoiceProviderInfo] {
        var providers: [WasmClient.VoiceProviderInfo] = []
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
    static func decodeProviderInfo(_ bytes: [UInt8]) -> WasmClient.VoiceProviderInfo? {
        var id = ""
        var name = ""
        var voiceCreatable = false
        var reader = ProtoReader(bytes)
        while let (field, wire) = reader.nextTag() {
            switch (field, wire) {
            case (1, 2): id = reader.readString() ?? ""
            case (2, 2): name = reader.readString() ?? ""
            case (4, 0): voiceCreatable = (reader.readVarint() ?? 0) != 0
            default:
                if !reader.skip(wire: wire) { break }
            }
        }
        guard !id.isEmpty, voiceCreatable else { return nil }
        return WasmClient.VoiceProviderInfo(id: id, name: name.isEmpty ? id : name)
    }

    /// Decode `OpenAICreateVoiceResponse`: field 1 = the created VoiceInfo.
    static func decodeCreateVoice(_ bytes: [UInt8]) -> WasmClient.VoiceInfo? {
        var reader = ProtoReader(bytes)
        while let (field, wire) = reader.nextTag() {
            switch (field, wire) {
            case (1, 2):
                guard let row = reader.readLengthDelimited() else { return nil }
                return decodeVoiceInfo(row)
            default:
                if !reader.skip(wire: wire) { return nil }
            }
        }
        return nil
    }

    /// `OpenAIVoiceGender` enum → raw name (0 unspecified, 1 male, 2 female, 3 neutral).
    private static func voiceGenderName(_ v: UInt64) -> String {
        switch v {
        case 1: return "male"
        case 2: return "female"
        case 3: return "neutral"
        default: return ""
        }
    }

    /// `OpenAIVoiceVisibility` enum → raw name (0 unspecified, 1 public, 2 private).
    private static func voiceVisibilityName(_ v: UInt64) -> String {
        switch v {
        case 1: return "public"
        case 2: return "private"
        default: return ""
        }
    }

    /// `OpenAIVoiceSource` enum → raw name (0 unspecified, 1 file, 2 generated).
    /// Backend-created voices ("my voices") report `file`/`generated`; the
    /// default catalog reports `unspecified`.
    private static func voiceSourceName(_ v: UInt64) -> String {
        switch v {
        case 1: return "file"
        case 2: return "generated"
        default: return ""
        }
    }
}

// MARK: - Minimal protobuf wire reader

/// A tiny cursor over protobuf wire bytes, factored out of the ad-hoc decoders
/// in `ChatSession+ListModels`. Only the wire types the voice messages use
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
