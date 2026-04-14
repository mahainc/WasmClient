// swift-tools-version: 6.2
import PackageDescription

let packageDir = Context.packageDirectory
let flowKitVersion = "1.2.13-26.1.1"
let flowKitChecksum = "868e1318455f41a6d51c162403dad59d1426a949f9b669aa02cf82a9afe49dff"
let flowKitURL = "https://github.com/mahainc/flow-kit/releases/download/\(flowKitVersion)/FlowKit.xcframework.zip"

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
        // SwiftProtobuf is provided by FlowKit.xcframework's merged modules.
        // Do NOT add a separate swift-protobuf SPM dependency — it creates
        // duplicate ObjC class registrations that silently break protobuf
        // arg passing to FlowKit when Xcode builds with a debug dylib.
    ],
    targets: [
        .binaryTarget(
            name: "FlowKit",
            url: flowKitURL,
            checksum: flowKitChecksum
        ),
        .target(
            name: "FlowKitCModules",
            path: "Vendor/FlowKitPackage/Sources/CModules",
            publicHeadersPath: "."
        ),
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
                // SwiftProtobuf comes from FlowKit.xcframework via merged modules
                "FlowKit",
                "FlowKitCModules",
                "WasmClient",
            ],
            resources: [
                .copy("Resources/base.wasm"),
            ],
            swiftSettings: [
                // Merged sub-module directory created by MergeFlowKitModules plugin.
                // Contains AsyncWasm, TaskWasm, SwiftProtobuf, etc. but NOT FlowKit
                // (resolved by SPM to the correct xcframework slice).
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
