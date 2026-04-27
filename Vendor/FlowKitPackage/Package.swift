// swift-tools-version: 5.10
import PackageDescription

// Switch FlowKit artifact version with: scripts/use-flowkit-xcode.sh <26.1.1>
let package = Package(
    name: "FlowKitPackage",
    platforms: [.macOS(.v14), .iOS(.v15)],
    products: [
        .library(name: "FlowKit", targets: ["FlowKit"]),
        .library(name: "FlowKitCModules", targets: ["CModules"]),
    ],
    targets: [
        .binaryTarget(
            name: "FlowKit",
            url: "https://github.com/mahainc/flow-kit/releases/download/1.2.16-26.1.1/FlowKit.xcframework.zip",
            checksum: "687d0192b61d15ce163b7e2795035290c398a2a894b6af3d6775a6b46151da87"
        ),
        .target(
            name: "CModules",
            path: "Sources/CModules",
            publicHeadersPath: "."
        ),
    ]
)
