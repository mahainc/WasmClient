# Optional-arg assembly in `Sessions/LiveScore.swift` — fixed 2026-09-25

Five livescore endpoints each built a `[String: Google_Protobuf_Value]` by hand,
and the "set this key only if the caller supplied a value" step was spelled out
once per key — 19 times in the file. `competition_id` alone appeared three times
(lines 98, 142, 171) and `team_id` twice (145, 174), each in the same shape:

```swift
if let competitionID, !competitionID.isEmpty {
    args["competition_id"] = Google_Protobuf_Value(stringValue: competitionID)
}
```

`clean-code` raised it as **G5** on the type-level unit. The duplication was
entirely pre-existing — `git show HEAD:` produced the same five line numbers —
but it was real, so it was collapsed rather than excepted.

## What it became

`Sources/WasmClientLive/Sessions/LivescoreArgs.swift`, an extension on the args
dictionary itself:

```swift
extension Dictionary where Key == String, Value == Google_Protobuf_Value {
    mutating func set(_ key: String, ifPresent value: String?)   // skips nil AND empty
    mutating func set(_ key: String, ifGiven value: String?)     // skips nil, keeps empty
    mutating func set(_ key: String, ifPresent value: Int64?)    // widens to numberValue
}
```

All 19 sites are now one line each: `args.set("q", ifPresent: q)`.

### Why two names instead of one flag

`set(_:ifPresent:skippingEmpty: Bool)` would read better at first glance and is
wrong: a boolean parameter that forks the body is **F3**, and the fork here is
exactly the wire distinction below. Two names keep each call site honest about
which contract it wants.

### The empty-string distinction is load-bearing

| Key | Guard | Why |
|---|---|---|
| `q`, `competition_id`, `team_id`, `video_type` | `ifPresent` | a blank query would make the backend filter on emptiness |
| `date` | `ifGiven` | passed through as given |
| `limit`, `offset`, `page`, `page_size` | `ifPresent` (Int64) | protobuf carries every number as a `Double` |

`date` is the only `ifGiven` caller. Worth knowing: its only producer
(`ScoresDay.requestDate` in the consuming app) returns `nil` or a formatted
`yyyy-MM-dd`, never `""` — so the keep-empty branch is currently unreachable in
practice. It was preserved anyway, because narrowing it would change what goes
on the wire and that is a separate decision.

## What G5 still reports, and why it is not the same finding

The G5 candidate on this file survives the fix, because the five lines it now
counts are signatures rather than logic:

```
5x  ) async throws -> [WasmClient.LiveScore.Entry] {
5x  var args: [String: Google_Protobuf_Value] = [:]
4x  q: String? = nil,
4x  args.set("q", ifPresent: q)
```

Five distinct endpoints returning the same type will always share their return
clause. The detector counts identical lines; it does not separate a shared
signature from a repeated idea.

## Still open

The wire keys themselves (`"competition_id"`, `"page_size"`, …) remain bare
string literals and carry a recurring `G25` every time this file is touched. A
single `enum LivescoreArgKey: String` would answer that — and would pair
naturally with the helper above, since every call site already names its key.
