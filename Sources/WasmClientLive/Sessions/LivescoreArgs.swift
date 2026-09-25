import Foundation
import SwiftProtobuf
import WasmClient

/// Optional-argument assembly for the livescore action payloads.
///
/// Every livescore endpoint builds its `args` the same way: a key is present
/// only when the caller supplied a value. Two spellings exist because the wire
/// treats them differently — a blank query would filter on emptiness, so it is
/// dropped, while a blank date is passed through as given.
extension Dictionary where Key == String, Value == Google_Protobuf_Value {
    /// Sets `key` when `value` is neither nil nor empty.
    mutating func set(
        _ key: String,
        ifPresent value: String?
    ) {
        guard let value, !value.isEmpty else { return }
        self[key] = Google_Protobuf_Value(stringValue: value)
    }

    /// Sets `key` whenever `value` is non-nil, empty string included.
    mutating func set(
        _ key: String,
        ifGiven value: String?
    ) {
        guard let value else { return }
        self[key] = Google_Protobuf_Value(stringValue: value)
    }

    /// Sets `key` when `value` is non-nil. Protobuf carries every number as a
    /// `Double`, so the widening happens here rather than at each call site.
    mutating func set(
        _ key: String,
        ifPresent value: Int64?
    ) {
        guard let value else { return }
        self[key] = Google_Protobuf_Value(numberValue: Double(value))
    }
}
