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
        // Exact pin keeps sibling FlowKit consumers on one shared engine build.
        .package(
            url: "https://github.com/mahainc/flow-kit.git",
            exact: "1.2.65-26.1.1-ffi"
        ),
        // FlowKit-linking targets must provide SwiftProtobuf explicitly.
        // EXACT pin: FlowKit's binary xcframework was built against SwiftProtobuf 1.39.x.
        // 1.40.0 đổi layout nội bộ của Google_Protobuf_Any._storage, khiến unpackTo() nổ
        // EXC_BAD_ACCESS khi giải mã task.value qua ranh giới binary (app923 chạy đúng ở 1.39.0).
        .package(
            url: "https://github.com/apple/swift-protobuf.git",
            exact: "1.39.0"
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
        .testTarget(
            name: "WasmClientLiveTests",
            dependencies: [
                "WasmClient",
                "WasmClientLive",
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
    ]
)
