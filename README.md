# WasmClient

A TCA-style dependency client wrapping [FlowKit](https://github.com/mahainc/flow-kit)'s `TaskWasmEngine` for running a downloaded Wasm runtime on-device. Exposes scan / describe / visual-search / chat / livescore / TTS / notification surfaces through a single `@DependencyClient` interface.

## Layout

- **`WasmClient`** — interface for the Wasm engine lifecycle (`start`, `reset`, `restart`, `warmUp`, `engineVersion`, `observeEngineState`), plus per-feature actions (scan, describe, visualSearch, chat, livescore, TTS, notifications). Models live under `Sources/WasmClient/Models/` grouped by feature.
- **`WasmClientLive`** — `FlowKit.TaskWasmEngine` wrapper with an actor + delegate that brokers engine state and per-action provider rotation; registers the live `DependencyKey`.
- **`WasmClientWebKit`** — auxiliary helper. One extension method `WKWebView.wasmClientNoProxy()` that bypasses the process-wide URLSession proxy the Wasm engine installs. Importable independently so views that need a WebView don't pull in the full Live target.

## Installation

```swift
.package(url: "https://github.com/mahainc/WasmClient.git", from: "1.2.52-26.1.1-ffi"),
```

- `WasmClient` on feature targets
- `WasmClientLive` on the app target
- `WasmClientWebKit` on any target that hosts a `WKWebView` alongside the Wasm engine

## ⚠ Build setup — explicit modules off

WasmClient depends on a `FlowKit.xcframework` whose sub-modules (`AsyncWasmCore`, `MobileFFI`, etc.) are exposed via `-I` include paths rather than declared SPM products. Xcode 26's explicit-modules dependency scanner can't see them.

**Consumer apps must disable explicit modules** at the app target level:

```
SWIFT_ENABLE_EXPLICIT_MODULES = NO
```

There is no per-target swiftc flag that disables this — the setting has to live on the app target. Without it you'll see build errors like `cannot find module 'AsyncWasmCore' in scope`.

The `MergeFlowKitModules` build plugin in this package merges the xcframework's sub-module `.swiftmodule`s into a single directory that the include paths point at; the plugin runs automatically as part of the build graph.

## Usage

```swift
import WasmClient
import ComposableArchitecture

@Reducer
struct EngineFeature {
    @ObservableState
    struct State {
        var engineState: WasmClient.EngineState = .idle
        var version: String?
    }

    enum Action {
        case task
        case engineStateChanged(WasmClient.EngineState)
        case versionResolved(String?)
    }

    @Dependency(\.wasmClient) var wasm

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .merge(
                    .run { _ in try await wasm.start() },
                    .run { send in
                        for await s in await wasm.observeEngineState() {
                            await send(.engineStateChanged(s))
                        }
                    },
                    .run { send in
                        let v = await wasm.engineVersion()
                        await send(.versionResolved(v))
                    }
                )

            case .engineStateChanged(let s):
                state.engineState = s
                return .none

            case .versionResolved(let v):
                state.version = v
                return .none
            }
        }
    }
}
```

## WebView coexistence

```swift
import WasmClientWebKit

let webView = WKWebView.wasmClientNoProxy()
```

## Testing

`@DependencyClient` generates unimplemented `testValue` defaults; override per call site:

```swift
let store = TestStore(initialState: EngineFeature.State()) {
    EngineFeature()
} withDependencies: {
    $0.wasmClient.start = { }
    $0.wasmClient.observeEngineState = { AsyncStream { c in c.yield(.ready) ; c.finish() } }
}
```

## Tag convention

Tags track the underlying FlowKit binary: `<wasm-version>-<xcode-version>[-<variant>][-<iteration>]`. The `<wasm-version>` matches the FlowKit release used in `Package.swift`'s `flowKitVersion`. Examples:

- `1.2.52-26.1.1-ffi` — FlowKit 1.2.52, Xcode 26.1.1, FFI variant
- `1.2.50-26.1.1-ffi-live-score-1` — same, feature-flagged livescore build, iteration 1

## Dependencies

- `swift-dependencies` from 1.9.0
- `FlowKit.xcframework` from [mahainc/flow-kit](https://github.com/mahainc/flow-kit) (binary target, pinned via `flowKitVersion` constant + checksum)

## Platform support

- iOS 17+

## License

MIT — see [LICENSE](./LICENSE).
