// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "WasmClient",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
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
        // from the canonical mahainc/flow-kit SPM package. As of
        // 1.2.62-26.1.1-ffi the xcframework ships a single `FlowKit.swiftmodule`
        // (all sub-modules folded in), so `import FlowKit` alone is sufficient —
        // no module-merge plugin and no `-I` search paths. Pinned exact to match
        // any sibling FlowKit consumer (e.g. FunnelWasm) so the app graph
        // resolves one shared FlowKit target.
        .package(
            url: "https://github.com/mahainc/flow-kit.git",
            exact: "1.2.65-26.1.1-ffi"
        ),
        // SwiftProtobuf for the generated `*.pb.swift` runtime. FlowKit's
        // compiled `.swiftmodule` declares a module dependency on SwiftProtobuf
        // but does NOT bundle or re-export it, so every FlowKit consumer must
        // supply it in the package graph. SPM dedupes with any sibling
        // swift-protobuf consumer in the app.
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
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                "WasmClient",
            ]
        ),
        .target(
            name: "WasmClientWebKit",
            dependencies: [
                .product(name: "FlowKit", package: "flow-kit"),
                // FlowKit's binary swiftmodule declares a module dependency on
                // SwiftProtobuf; under explicit-modules builds every target that
                // imports FlowKit must resolve it, even though this target's own
                // source only imports FlowKit + WebKit.
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ]
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
