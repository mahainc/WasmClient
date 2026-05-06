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
            url: "https://github.com/mahainc/flow-kit/releases/download/1.2.22-26.1.1/FlowKit.xcframework.zip",
            checksum: "00a050dbd56a02863c862088daf7584cee11d2b833e80876279d66ba8ba878f7"
        ),
        .target(
            name: "CModules",
            path: "Sources/CModules",
            publicHeadersPath: "."
        ),
    ]
)
