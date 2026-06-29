# CLAUDE.md

This file provides guidance to Claude Code when working with the WasmClient package.

## Overview

WasmClient wraps FlowKit's WASM engine as a dependency client using [swift-dependencies](https://github.com/pointfreeco/swift-dependencies). Two products:

- **WasmClient** — Pure Swift interface with models, `@DependencyClient` struct, and mocks. Depends only on `Dependencies` + `DependenciesMacros`.
- **WasmClientLive** — Live implementation using FlowKit. Provides `DependencyKey` conformance (`liveValue`).

## Build

```bash
# Interface only (macOS/iOS)
swift build --target WasmClient

# Live implementation (iOS only — FlowKit xcframework has no macOS slice)
# Must build via Xcode or xcodebuild for iOS simulator/device
```

WasmClientLive requires a build plugin (`MergeFlowKitModules`) that merges FlowKit's sub-modules into a directory. The plugin runs automatically during build.

## Key Constraints

- Swift 6.2 tools version, Swift 6.0 language mode with strict concurrency
- iOS 17.0 / macOS 14.0 minimum
- All public types are `Sendable` and `Equatable`
- Do NOT add a separate `swift-protobuf` SPM dependency — SwiftProtobuf is provided by FlowKit's merged modules. Adding it causes duplicate ObjC class registrations.
- Do NOT depend on `swift-composable-architecture` — only `swift-dependencies` is needed.

## LLDB / Debugger Compatibility

The current **`-ffi`** FlowKit engine (uniffi/Rust backend, e.g. `1.2.59-26.1.1-ffi`) is
**LLDB-safe** — you can Run from Xcode with the debugger attached and set breakpoints in
WasmClient/app code normally. The default scheme (`selectedDebuggerIdentifier=…LLDB`) is fine; no
`debugEnabled: false` / PosixSpawn launcher workaround is needed.

**Historical note (pre-`-ffi` engines only):** the older WASM runtime crashed when LLDB was
attached — it used SIGSEGV signal handlers for memory bounds checking, LLDB intercepted those
signals, and startup failed with `WasmParser.WasmParserError`. On such an engine, consumer apps had
to disable the debugger in their scheme (XcodeGen `run: { debugEnabled: false, launchAutomaticallySubstyle: 2 }`;
scheme XML `selectedDebuggerIdentifier=""` + `selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.PosixSpawn"`)
and attach manually after the engine started. If you ever pin back to a non-`-ffi` build, restore
that workaround.

## Architecture

- `WasmActor` (actor) serializes all engine access
- `WasmDelegate` (NSObject, @unchecked Sendable) bridges FlowKit's delegate callbacks
- Engine state observation supports multiple concurrent subscribers via UUID-keyed continuations
- Engine start uses `CheckedContinuation` (not polling) to wait for `.running` state
- Action discovery happens eagerly during `start()`, not lazily on first use

## Adding New Domains

1. Add models in `Sources/WasmClient/Models/`
2. Add closure(s) to `WasmClient` struct in `Interface.swift`
3. Add mock implementation in `Mocks.swift`
4. Add session extension on `WasmActor` in `Sources/WasmClientLive/Sessions/`
5. Wire in `Live.swift`
