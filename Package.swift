// swift-tools-version: 6.2
import PackageDescription

let packageDir = Context.packageDirectory

let package = Package(
    name: "WasmClient",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "WasmClient", targets: ["WasmClient"]),
        .library(name: "WasmClientLive", targets: ["WasmClientLive"]),
        .library(name: "WasmClientWebKit", targets: ["WasmClientWebKit"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-dependencies.git",
            from: "1.9.0"
        ),
        // FlowKit (binary xcframework + asyncify_wasmFFI + CModules) is consumed
        // from the canonical mahainc/flow-kit SPM package rather than vendored
        // in-repo, so an app that also depends on FlowKit (directly or via
        // FunnelWasm) shares a single FlowKit target graph instead of hitting
        // duplicate-target resolution errors. Pinned exact to match the version
        // any sibling FlowKit consumer pins.
        .package(
            url: "https://github.com/mahainc/flow-kit.git",
            exact: "1.2.62-26.1.1-ffi"
        ),
        // SwiftProtobuf for the generated `*.pb.swift` runtime. FlowKit's
        // xcframework stopped vending its own SwiftProtobuf sub-module interface
        // as of 1.2.62-26.1.1-ffi, so consumers bring their own (matching how
        // FunnelWasm declares it). SPM dedupes this with any sibling
        // swift-protobuf consumer in the app graph.
        .package(
            url: "https://github.com/apple/swift-protobuf.git",
            from: "1.22.0"
        ),
    ],
    targets: [
        .target(
            name: "WasmClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
            ]
        ),
        .target(
            name: "WasmClientLive",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "FlowKit", package: "flow-kit"),
                .product(name: "FlowKitCModules", package: "flow-kit"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                "WasmClient",
            ],
            swiftSettings: [
                // Merged sub-module directory created by MergeFlowKitModules plugin.
                // Contains AsyncWasm, TaskWasm, SwiftProtobuf, etc. but NOT FlowKit
                // (resolved by SPM to the correct xcframework slice).
                // Xcode 26's explicit-modules dependency scanner can't see
                // FlowKit xcframework sub-modules (AsyncWasmCore, MobileFFI)
                // that are exposed via -I instead of as declared SPM deps.
                // Consumers must set `SWIFT_ENABLE_EXPLICIT_MODULES=NO` at the
                // app target level — there is no per-target swiftc flag that
                // disables explicit modules in a way the driver will accept.
                .unsafeFlags([
                    "-I", "\(packageDir)/.build/flowkit-merged-modules",  // local dev
                    "-I", "/tmp/wasmclient-flowkit-modules",  // build plugin
                ])
            ],
            plugins: [
                .plugin(name: "MergeFlowKitModules")
            ]
        ),
        .target(
            name: "WasmClientWebKit",
            dependencies: [
                .product(name: "FlowKit", package: "flow-kit"),
                .product(name: "FlowKitCModules", package: "flow-kit"),
            ],
            swiftSettings: [
                .unsafeFlags([
                    "-I", "\(packageDir)/.build/flowkit-merged-modules",
                    "-I", "/tmp/wasmclient-flowkit-modules",
                ])
            ],
            plugins: [
                .plugin(name: "MergeFlowKitModules")
            ]
        ),
        .plugin(
            name: "MergeFlowKitModules",
            capability: .buildTool()
        ),
        .testTarget(
            name: "WasmClientTests",
            dependencies: [
                "WasmClient",
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
    ]
)
