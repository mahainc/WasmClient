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
            url: "https://github.com/mahainc/flow-kit/releases/download/1.2.26-26.1.1/FlowKit.xcframework.zip",
            checksum: "382c117d2980c95854166f538e3502dab94921ba2dd50f2b9b575b3a3fd6b056"
        ),
        .target(
            name: "CModules",
            path: "Sources/CModules",
            publicHeadersPath: "."
        ),
    ]
)
