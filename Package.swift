// swift-tools-version: 6.2
import PackageDescription

let packageDir = Context.packageDirectory
let flowKitVersion = "1.2.52-26.1.1-ffi"
let flowKitChecksum = "70649c712708d3151a7a7d84a2bad76e47568adcd47058f20141b747e7d1209d"
let flowKitURL = "https://github.com/mahainc/flow-kit/releases/download/\(flowKitVersion)/FlowKit.xcframework.zip"

let package = Package(
    name: "WasmClient",
    platforms: [
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
        // C shim that exposes the uniffi-generated `asyncify_wasmFFI` Clang
        // module that FlowKit's `MobileFFI.swiftmodule` links against. The
        // FFI symbols themselves live in the FlowKit binary; this target only
        // ships headers + modulemap. Mirrors mahainc/flow-kit's Package.swift.
        .target(
            name: "asyncify_wasmFFI",
            path: "Vendor/FlowKitFFI/asyncify_wasmFFI",
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
                "asyncify_wasmFFI",
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
                "asyncify_wasmFFI",
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
