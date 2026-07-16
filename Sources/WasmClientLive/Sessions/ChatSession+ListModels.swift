import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - ListModels wire decoding
//
// The backend changed the `/models` response from a generic
// `google.protobuf.Struct` to a typed `asyncify.types.ListModels` message.
// All parsing for that new format lives here, isolated from the rest of
// ChatSession so it can be reviewed or reverted on its own. Only
// `chatModels()` calls into this file.
extension WasmActor {

    /// Minimal protobuf wire-format decoder for `asyncify.types.ListModels`.
    /// Top-level field 1 = repeated model rows, field 2 = total count,
    /// field 4 = number returned in this page. Avoids a generated
    /// `.pb.swift` dependency for a single response type.
    static func decodeListModels(
        _ bytes: [UInt8],
        providerNames: [String: String]
    ) -> (models: [WasmClient.ChatModelInfo], total: Int) {
        var models: [WasmClient.ChatModelInfo] = []
        var total = 0
        var i = 0
        let n = bytes.count

        func readVarint() -> UInt64? {
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

        func skip(wire: Int) -> Bool {
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

        while i < n {
            guard let tag = readVarint() else { break }
            let field = Int(tag >> 3)
            let wire = Int(tag & 7)
            switch (field, wire) {
            case (1, 2): // model row (length-delimited message)
                guard let len = readVarint(), i + Int(len) <= n else { return (models, total) }
                let row = Array(bytes[i..<i + Int(len)]); i += Int(len)
                if let model = decodeModelRow(row, providerNames: providerNames) {
                    models.append(model)
                }
            case (2, 0): // total
                if let v = readVarint() { total = Int(v) }
            case (4, 0): // returned count (ignored; we use models.count)
                _ = readVarint()
            default:
                guard skip(wire: wire) else { return (models, total) }
            }
        }
        return (models, total)
    }

    /// Decode one model row: field 1 id, 2 name, 3 owned_by, 4 metadata Struct.
    static func decodeModelRow(
        _ bytes: [UInt8],
        providerNames: [String: String]
    ) -> WasmClient.ChatModelInfo? {
        var i = 0
        let n = bytes.count
        var id = ""
        var name = ""
        var ownedBy = ""
        var metaFields: [String: Google_Protobuf_Value] = [:]

        func readVarint() -> UInt64? {
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
        func readString(_ len: Int) -> String {
            defer { i += len }
            return String(decoding: bytes[i..<i + len], as: UTF8.self)
        }

        while i < n {
            guard let tag = readVarint() else { break }
            let field = Int(tag >> 3)
            let wire = Int(tag & 7)
            switch (field, wire) {
            case (1, 2):
                guard let len = readVarint(), i + Int(len) <= n else { return nil }
                id = readString(Int(len))
            case (2, 2):
                guard let len = readVarint(), i + Int(len) <= n else { return nil }
                name = readString(Int(len))
            case (3, 2):
                guard let len = readVarint(), i + Int(len) <= n else { return nil }
                ownedBy = readString(Int(len))
            case (4, 2):
                guard let len = readVarint(), i + Int(len) <= n else { return nil }
                let metaBytes = Data(bytes[i..<i + Int(len)]); i += Int(len)
                if let s = try? Google_Protobuf_Struct(serializedBytes: metaBytes) {
                    metaFields = s.fields
                }
            default:
                switch wire {
                case 0: if readVarint() == nil { return nil }
                case 1: i += 8
                case 2:
                    guard let len = readVarint(), i + Int(len) <= n else { return nil }
                    i += Int(len)
                case 5: i += 4
                default: return nil
                }
            }
        }

        guard !id.isEmpty else { return nil }
        return mapModelRow(
            id: id,
            name: name,
            ownedBy: ownedBy,
            meta: metaFields,
            providerNames: providerNames
        )
    }

    /// Map a decoded model row + its metadata Struct into a `ChatModelInfo`.
    static func mapModelRow(
        id rawId: String,
        name rawName: String,
        ownedBy: String,
        meta: [String: Google_Protobuf_Value],
        providerNames: [String: String]
    ) -> WasmClient.ChatModelInfo? {
        let modelId = rawId
        guard !modelId.isEmpty else { return nil }
        let name: String = rawName.isEmpty ? modelId : rawName
        let isPro: Bool = {
            if case .boolValue(let b)? = meta["is_pro"]?.kind { return b }
            return false
        }()
        let vision: Bool = {
            if case .boolValue(let b)? = meta["vision"]?.kind { return b }
            return false
        }()
        let voices: [String] = {
            guard case .listValue(let l)? = meta["voices"]?.kind else { return [] }
            return l.values.compactMap { v in
                if case .stringValue(let s) = v.kind { return s }
                return nil
            }
        }()
        let greetings: [String] = {
            guard case .listValue(let l)? = meta["greetings"]?.kind else { return [] }
            return l.values.compactMap { v in
                if case .stringValue(let s) = v.kind { return s }
                return nil
            }
        }()
        let image: String = {
            if case .stringValue(let s)? = meta["image"]?.kind { return s }
            return ""
        }()
        let interactions: Int = {
            if case .numberValue(let n)? = meta["interactions"]?.kind { return Int(n) }
            return 0
        }()
        let description: String = {
            if case .stringValue(let s)? = meta["description"]?.kind { return s }
            return ""
        }()
        let tags: [String] = {
            guard case .listValue(let l)? = meta["tags"]?.kind else { return [] }
            return l.values.compactMap {
                if case .stringValue(let s) = $0.kind { return s }
                return nil
            }
        }()
        let providerId: String = {
            if case .stringValue(let s)? = meta["provider_id"]?.kind { return s }
            return ""
        }()
        let providerName = providerNames[providerId] ?? ""

        return WasmClient.ChatModelInfo(
            modelId: modelId,
            name: name,
            ownedBy: ownedBy,
            isPro: isPro,
            vision: vision,
            voices: voices,
            greetings: greetings,
            image: image,
            interactions: interactions,
            description: description,
            tags: tags,
            providerId: providerId,
            providerName: providerName
        )
    }
}
