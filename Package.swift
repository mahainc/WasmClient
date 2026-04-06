// swift-tools-version: 6.2
import PackageDescription

let packageDir = Context.packageDirectory

let package = Package(
    name: "WasmClient",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "WasmClient", targets: ["WasmClient"]),
        .library(name: "WasmClientLive", targets: ["WasmClientLive"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/apple/swift-protobuf.git",
            branch: "main"
        ),
        .package(path: "Vendor/FlowKitPackage"),
    ],
    targets: [
        .target(
            name: "WasmClient",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "WasmClientLive",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "FlowKit", package: "FlowKitPackage"),
                .product(name: "FlowKitCModules", package: "FlowKitPackage"),
                "WasmClient",
            ],
            resources: [
                .copy("Resources/base.wasm"),
            ],
            swiftSettings: [
                // Merged sub-module directory created by MergeFlowKitModules plugin.
                // Contains AsyncWasm, TaskWasm, etc. but NOT FlowKit/SwiftProtobuf
                // (those are resolved by SPM to the correct xcframework slice).
                .unsafeFlags([
                    "-I", "\(packageDir)/.build/flowkit-merged-modules",  // local dev
                    "-I", "/tmp/wasmclient-flowkit-modules",              // build plugin
                ]),
            ],
            plugins: [
                .plugin(name: "MergeFlowKitModules"),
            ]
        ),
        .plugin(
            name: "MergeFlowKitModules",
            capability: .buildTool()
        ),
    ]
)
