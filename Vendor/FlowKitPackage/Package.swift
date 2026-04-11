// swift-tools-version: 5.10
import PackageDescription

// Switch FlowKit artifact version with: scripts/use-flowkit-xcode.sh <26.1.1|26.4>
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
            url: "https://github.com/mahainc/flow-kit/releases/download/1.2.8-26.1.1/FlowKit.xcframework.zip",
            checksum: "57abf7c0595af806b82a6b83bcd0c3f818d95f549b056f52848df92b0907e8e1"
        ),
        .target(
            name: "CModules",
            path: "Sources/CModules",
            publicHeadersPath: "."
        ),
    ]
)
