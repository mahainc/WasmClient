# CLAUDE.md

This file provides guidance to Claude Code when working with the WasmClient package.

## Overview

WasmClient wraps FlowKit's WASM engine as a dependency client using [swift-dependencies](https://github.com/pointfreeco/swift-dependencies). Two products:

- **WasmClient** — Pure Swift interface with models, `@DependencyClient` struct, and mocks. Depends only on `Dependencies` + `DependenciesMacros`.
- **WasmClientLive** — Live implementation using FlowKit. Provides `DependencyKey` conformance (`liveValue`).

## Build

This package has a **side-by-side Bazel setup** (`MODULE.bazel` at the repo root — additive, it does NOT touch SPM/Xcode; consuming apps still resolve WasmClient via SPM). Compile-verification goes through **Bazel**, whose content-addressed cache survives `clean` / worktrees / CI / cross-machine.

**Route compile-verification through the `bazel-builder` subagent** (it drives the `bazel-build` CLI). For this package this OVERRIDES the global `swift-builder` rule. Targets live at `//Sources/<Name>`:

```
bazel-build WasmClient       # interface only (Dependencies + DependenciesMacros)
bazel-build WasmClientLive   # live impl (FlowKit + protos)
bazel-build WasmClientWebKit # WebKit no-proxy helper (FlowKit)
bazel-build --all            # all three in one invocation
bazel-build --list           # per-target route table
```

All three targets build under Bazel for the iOS simulator (`--config=ios_sim`); there is no `--app` (a package has no app scheme). **Never run raw `swift build` / `xcodebuild`** — go through `bazel-builder`. WasmClientLive links FlowKit directly (`import FlowKit`); the `-ffi` xcframework ships a single `FlowKit.swiftmodule` with all sub-modules folded in, so no build plugin or `-I` include paths are needed.

**Bazel-specific wiring** (already in the checked-in BUILD files — do not re-discover):
- FlowKit's binary swiftmodule + the generated `*.pb.swift` both `import WasmSwiftProtobuf` (swift-protobuf under an alias). A `# gazelle:resolve swift WasmSwiftProtobuf @swiftpkg_swift_protobuf//:SwiftProtobuf` in the root `BUILD.bazel` wires it.
- `WasmClientWebKit`'s source imports only FlowKit + WebKit, so gazelle would drop the required SwiftProtobuf dep — it is pinned with `# keep` in `Sources/WasmClientWebKit/BUILD.bazel`.
- flow-kit's `asyncify_wasmFFI` modulemap uses Clang `use` directives rspm rejects; stripped for the Bazel build only via `third-party/flow-kit/module.modulemap.patch`.

## Key Constraints

- Swift 6.2 tools version, Swift 6.0 language mode with strict concurrency
- iOS 17.0 / macOS 14.0 minimum
- All public types are `Sendable` and `Equatable`
- The `apple/swift-protobuf` dependency is REQUIRED on every FlowKit-linking target (`WasmClientLive`, `WasmClientWebKit`). FlowKit's `.swiftmodule` declares a module dependency on SwiftProtobuf but does not bundle/re-export it, so the module must be present in the package graph or the build fails with `Unable to find module dependency: 'SwiftProtobuf'`.
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
- AIArt is the only session that catalogue-ranks providers + fails over (to dodge an
  unprovisioned `runware`); read `docs/aiart-provider-failover.md` **only** when touching
  `Sessions/AIArt.swift` provider resolution or debugging a `missing runware data entry`.

## Code Quality (clean-code)

Route every non-trivial implementation or refactor in this package through the
`clean-code` skill so code lands clean the first time, not after a review round:

- **While writing** (`clean-code --apply`, default): apply the Chapter-17 heuristics
  (CC1–CC10) to changed Swift, then self-review the diff. Runs AFTER the domain shape
  is set (see below) and BEFORE compile-verify via `bazel-builder`.
- **Before a PR** (`clean-code --review <changed files>`): read-only audit citing each
  smell by book code (G5, F3, N1…); fix the Critical/Structural findings.

Package-specific carve-outs — `clean-code` handles the function/logic layer ONLY and
must defer to the gates that own the rest:

- `Sources/WasmClientLive/Protos/*.pb.swift` are generated — **out of scope**, never scored.
- Wire-facing values stay **struct + static let** (owned by the `wasm-domain` skill); the
  book's "enum for closed unions" guidance defers to that (CC7 = follow the repo's convention).
- Actor/delegate organization, the `Sessions/` layout, and the **L1–L6** concurrency rubric
  are owned by `tca-client`; `clean-code` does not re-litigate the actor split.
- Whitespace/layout belongs to `swift-format`/`swift-lint`. Never run `swift-lint --fix` on
  `Live.swift` (it injects `@retroactive`, which breaks the SPM build).

## Adding New Domains

1. Add models in `Sources/WasmClient/Models/`
2. Add closure(s) to `WasmClient` struct in `Interface.swift`
3. Add mock implementation in `Mocks.swift`
4. Add session extension on `WasmActor` in `Sources/WasmClientLive/Sessions/`
5. Wire in `Live.swift`
6. Run `clean-code --apply` on the new session, then `clean-code --review` the diff,
   before build-verifying via `bazel-builder`.
