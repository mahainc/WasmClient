import Foundation
import XCTest

@testable import WasmClient

/// Guards the hand-maintained pair of FlowKit version declarations:
///
/// - `flowKitVersion` in `Package.swift` — which binary ships in the app.
/// - `WasmClient.bundledFlowKitVersion` in `EngineModels.swift` — what hosts
///   feed into `setExpectedVersionProvider` so a stale cached wasm bundle is
///   evicted on app update.
///
/// When they drift apart (bumped one, forgot the other), every install that
/// carries an old cached bundle keeps it forever and all engine RPCs fail —
/// e.g. food scans returning "Couldn't recognize" for 100% of upgraded users
/// (hit on-device 2026-07-08, FlowKit 1.2.57→1.2.59). This test makes the
/// drift a build-time failure instead of a field incident.
final class FlowKitVersionSyncTests: XCTestCase {

    func testBundledFlowKitVersionMatchesPackagePin() throws {
        // Tests/WasmClientTests/FlowKitVersionSyncTests.swift → package root.
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let manifestURL = packageRoot.appendingPathComponent("Package.swift")
        let manifest = try String(contentsOf: manifestURL, encoding: .utf8)

        // let flowKitVersion = "1.2.59-26.1.1-ffi"
        let pattern = #"let\s+flowKitVersion\s*=\s*"([^"]+)""#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(manifest.startIndex..., in: manifest)
        guard
            let match = regex.firstMatch(in: manifest, range: range),
            let versionRange = Range(match.range(at: 1), in: manifest)
        else {
            return XCTFail(
                "Couldn't find `let flowKitVersion = \"…\"` in \(manifestURL.path). "
                    + "If the manifest declaration was renamed, update this test."
            )
        }
        let pinned = String(manifest[versionRange])

        XCTAssertEqual(
            WasmClient.bundledFlowKitVersion,
            pinned,
            """
            FlowKit version drift: Package.swift pins \(pinned) but \
            WasmClient.bundledFlowKitVersion is \(WasmClient.bundledFlowKitVersion). \
            Bump `bundledFlowKitVersion` in Sources/WasmClient/Models/EngineModels.swift \
            to match — otherwise upgraded installs never evict the stale cached wasm \
            bundle and every engine RPC (food scan, chat, …) fails.
            """
        )
    }
}
