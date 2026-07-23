import Foundation
import SwiftProtobuf

// MARK: - protoc-gen-flow-kit support shims
//
// These helpers are emitted by the `protoc-gen-flow-kit` plugin into the
// FlowKit *source* package, but are NOT vended by the prebuilt
// `FlowKit.xcframework` binary this package links. Re-declared here so the
// generated `*.fk.pb.swift` accessors (e.g. `news.fk.pb.swift`) compile
// against the binary FlowKit. Keep in sync with flow-kit-example's codegen.

/// Enum ↔ SCREAMING_SNAKE_CASE wire-name bridge used by generated proto enums.
public protocol ProtoNameCarrying {
    var protoName: String { get }
    init(protoName name: String)
}

// MARK: - Ergonomic Value builders for ChatMessage.content
//
// `OpenAIChatMessage.content` is `google.protobuf.Value` so the wire
// format matches OpenAI's polymorphic `content` spec. Call sites build
// it via these helpers rather than constructing the Value enum by hand.
// Mirrors flow-kit-example's OpenAISession.swift — keep in sync.
extension OpenAIChatMessage {
    /// Set `content` to a plain string (text turn).
    public mutating func setContent(text: String) {
        content = .with { $0.stringValue = text }
    }

    /// Set `content` to an array of content parts (multimodal turn).
    /// Each part proto is serialized via its proto3 JSON shape so the
    /// result matches OpenAI's `[{type, text, image_url, …}]` wire form.
    public mutating func setContent(parts: [OpenAIContentPart]) throws {
        var opts = JSONEncodingOptions()
        opts.preserveProtoFieldNames = true
        let values: [Google_Protobuf_Value] = try parts.map { p in
            let data = try p.jsonUTF8Data(options: opts)
            return try Google_Protobuf_Value(jsonUTF8Data: data)
        }
        content = .with {
            $0.listValue = .with { $0.values = values }
        }
    }

    /// Read the text view of `content`. Returns the raw string for
    /// text-only turns; for multimodal turns returns the concatenation
    /// of the `text` parts. Empty when the message carries no content.
    public var contentText: String {
        guard hasContent else { return "" }
        switch content.kind {
        case .stringValue(let s):
            return s
        case .listValue(let lv):
            return lv.values.compactMap { v -> String? in
                guard case .structValue(let s) = v.kind,
                    case .stringValue(let t)? = s.fields["text"]?.kind
                else { return nil }
                return t
            }.joined()
        default:
            return ""
        }
    }
}
