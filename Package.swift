// swift-tools-version: 6.2
import PackageDescription

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
        .package(
            url: "https://github.com/mahainc/flow-kit.git",
            exact: "1.2.65-26.1.1-ffi"
        ),
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
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ]
        ),
    ]
)
