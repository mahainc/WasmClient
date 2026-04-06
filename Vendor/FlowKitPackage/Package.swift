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
            url: "https://github.com/mahainc/flow-kit/releases/download/1.2.7-26.1.1/FlowKit.xcframework.zip",
            checksum: "bfe7eb1ad796bcf2722653d10e58c49d9296ede42219998e9cb26f61f92dad26"
        ),
        .target(
            name: "CModules",
            path: "Sources/CModules",
            publicHeadersPath: "."
        ),
    ]
)
