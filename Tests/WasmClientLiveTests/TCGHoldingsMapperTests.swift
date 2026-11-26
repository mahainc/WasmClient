import SwiftProtobuf
import XCTest

@testable import WasmClient
@testable import WasmClientLive

final class TCGHoldingsMapperTests: XCTestCase {

    // MARK: - HoldingDetail

    func testMapHoldingDetail() {
        var card = TcgCard()
        card.id = "c1"
        card.name = "Charizard"

        var item = TcgCollectionItem()
        item.id = "h1"
        item.card = card
        item.quantity = 2
        item.condition = .nearMint

        var proto = TcgHoldingDetailResponse()
        proto.item = item

        let detail = WasmActor.mapHoldingDetail(proto)
        XCTAssertEqual(detail.item.id, "h1")
        XCTAssertEqual(detail.item.card.name, "Charizard")
        XCTAssertEqual(detail.item.quantity, 2)
        XCTAssertEqual(detail.item.condition, .nearMint)
    }

    // MARK: - UpdateHolding

    func testMapUpdateHolding() {
        var item = TcgCollectionItem()
        item.id = "h1"
        item.quantity = 3

        var proto = TcgUpdateHoldingResponse()
        proto.ok = true
        proto.item = item

        let result = WasmActor.mapUpdateHolding(proto)
        XCTAssertTrue(result.ok)
        XCTAssertEqual(result.item.id, "h1")
        XCTAssertEqual(result.item.quantity, 3)
    }

    // MARK: - Variant (public input -> proto for JSON serialization)

    func testVariantProto() {
        let variant = WasmClient.TCG.Variant(id: "v1", finish: .foil, grade: "PSA 10")
        let proto = WasmActor.variantProto(variant)
        XCTAssertEqual(proto.id, "v1")
        XCTAssertEqual(proto.finish, .foil)
        XCTAssertEqual(proto.grade, "PSA 10")

        let json = try? proto.jsonUTF8Data()
        XCTAssertNotNil(json)
    }

    func testVariantProtoUnsetDefaults() {
        let proto = WasmActor.variantProto(WasmClient.TCG.Variant())
        XCTAssertEqual(proto.id, "")
        XCTAssertEqual(proto.finish, .unspecified)
        XCTAssertEqual(proto.grade, "")
    }
}
