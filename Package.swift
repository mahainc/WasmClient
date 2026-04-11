// swift-tools-version: 6.2
import PackageDescription

let packageDir = Context.packageDirectory
let flowKitVersion = "1.2.8-26.1.1"
let flowKitChecksum = "57abf7c0595af806b82a6b83bcd0c3f818d95f549b056f52848df92b0907e8e1"
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
        .package(
            url: "https://github.com/apple/swift-protobuf.git",
            branch: "main"
        ),
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
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                "FlowKit",
                "FlowKitCModules",
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
