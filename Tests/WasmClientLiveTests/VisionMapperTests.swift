import SwiftProtobuf
import XCTest

@testable import WasmClient
@testable import WasmClientLive

final class VisionMapperTests: XCTestCase {

    // MARK: - Additional files

    func testSetAdditionalFilesOmitsEmpty() {
        var args: [String: Google_Protobuf_Value] = [:]
        WasmActor.setAdditionalFiles([], into: &args)
        XCTAssertNil(args["additional_files"])
    }

    func testSetAdditionalFilesJoinsWithComma() {
        var args: [String: Google_Protobuf_Value] = [:]
        WasmActor.setAdditionalFiles(["https://a/1.jpg", "https://a/2.jpg"], into: &args)
        XCTAssertEqual(args["additional_files"]?.stringValue, "https://a/1.jpg,https://a/2.jpg")
    }

    // MARK: - Rock route fields

    func testMapScanResultCarriesCategoryInfoFactsAndAlternatives() {
        var rockInfo = VisionCategoryInfo()
        rockInfo.type = "rockInfo"
        rockInfo.fields = ["Hardness": "7"]
        var lookalike = VisionScanResult()
        lookalike.title = "Fluorite"
        var proto = VisionScanResult()
        proto.title = "Amethyst"
        proto.categoryType = "rock"
        proto.categoryInfo = rockInfo
        proto.facts = ["Formula": "SiO₂"]
        proto.alternatives = [lookalike]

        let result = WasmActor.mapScanResult(proto)
        XCTAssertEqual(result.categoryInfo, WasmClient.Vision.CategoryInfo(type: "rockInfo", fields: ["Hardness": "7"]))
        XCTAssertEqual(result.facts, ["Formula": "SiO₂"])
        XCTAssertEqual(result.alternatives.map(\.title), ["Fluorite"])
    }

    func testMapScanResultWithoutCategoryInfoIsNil() {
        let result = WasmActor.mapScanResult(VisionScanResult())
        XCTAssertNil(result.categoryInfo)
        XCTAssertTrue(result.facts.isEmpty)
        XCTAssertTrue(result.alternatives.isEmpty)
    }
}
