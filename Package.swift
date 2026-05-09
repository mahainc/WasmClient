// swift-tools-version: 6.2
import PackageDescription

let packageDir = Context.packageDirectory
let flowKitVersion = "1.2.29-26.1.1"
let flowKitChecksum = "86b9ab93039a75f6c316ec8b32b6555031eaf21a82cbe0615b623bdf930d45d3"
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
        .library(name: "WasmClientWebKit", targets: ["WasmClientWebKit"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-dependencies.git",
            from: "1.9.0"
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
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
            ]
        ),
        .target(
            name: "WasmClientLive",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
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
        .target(
            name: "WasmClientWebKit",
            dependencies: [
                "FlowKit",
                "FlowKitCModules",
            ],
            swiftSettings: [
                .unsafeFlags([
                    "-I", "\(packageDir)/.build/flowkit-merged-modules",
                    "-I", "/tmp/wasmclient-flowkit-modules",
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
