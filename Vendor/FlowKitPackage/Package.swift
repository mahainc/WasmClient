// swift-tools-version: 5.10
import PackageDescription

// Switch FlowKit artifact version with: Scripts/use-flowkit-xcode.sh <26.1.1>
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
            url: "https://github.com/mahainc/flow-kit/releases/download/1.2.21-26.1.1/FlowKit.xcframework.zip",
            checksum: "ac7d541e00521759a4971536829e5b2c3c416c541760feb4bcdb3c5d33121b9d"
        ),
        .target(
            name: "CModules",
            path: "Sources/CModules",
            publicHeadersPath: "."
        ),
    ]
)
