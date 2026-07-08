import Foundation

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
