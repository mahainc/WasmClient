import SwiftProtobuf
import XCTest

@testable import WasmClient
@testable import WasmClientLive

final class TCGCollectionsMapperTests: XCTestCase {

    // MARK: - Condition mapping

    func testMapCondition() {
        XCTAssertEqual(WasmActor.mapCondition(.nearMint), .nearMint)
        XCTAssertEqual(WasmActor.mapCondition(.damaged), .damaged)
        XCTAssertEqual(WasmActor.mapCondition(.unspecified).rawValue, "")
    }

    // MARK: - Account

    func testMapAccountInfo() {
        var metadata = Google_Protobuf_Struct()
        metadata.fields = ["plan": Google_Protobuf_Value(stringValue: "pro")]

        var account = TcgAccount()
        account.id = "a1"
        account.handle = "trainer"
        account.nickname = "Ash"
        account.email = "ash@example.com"
        account.tier = "pro"
        account.defaultCurrency = "USD"
        account.totalCards = "250"
        account.metadata = metadata

        var proto = TcgAccountInfoResponse()
        proto.account = account

        let info = WasmActor.mapAccountInfo(proto)
        XCTAssertEqual(info.account.id, "a1")
        XCTAssertEqual(info.account.handle, "trainer")
        XCTAssertEqual(info.account.nickname, "Ash")
        XCTAssertEqual(info.account.totalCards, "250")
        XCTAssertEqual(info.account.metadata["plan"], "pro")
    }

    // MARK: - Collection

    func testMapCollection() {
        var proto = TcgCollection()
        proto.id = "col1"
        proto.name = "Binder"
        proto.isDefault = true
        proto.color = "#FF0000"
        proto.isPublic = true
        proto.ordering = 3

        let collection = WasmActor.mapCollection(proto)
        XCTAssertEqual(collection.id, "col1")
        XCTAssertEqual(collection.name, "Binder")
        XCTAssertTrue(collection.isDefault)
        XCTAssertEqual(collection.color, "#FF0000")
        XCTAssertTrue(collection.isPublic)
        XCTAssertEqual(collection.ordering, 3)
    }

    // MARK: - CollectionSummary

    func testMapCollectionSummary() {
        var value = TcgMoney()
        value.amount = "9999.00"
        value.currency = "USD"

        var proto = TcgCollectionSummaryResponse()
        proto.totalCards = "250"
        proto.totalSealed = "4"
        proto.totalGraded = "12"
        proto.totalValue = value

        let summary = WasmActor.mapCollectionSummary(proto)
        XCTAssertEqual(summary.totalCards, "250")
        XCTAssertEqual(summary.totalSealed, "4")
        XCTAssertEqual(summary.totalGraded, "12")
        XCTAssertEqual(summary.totalValue.amount, "9999.00")
    }

    // MARK: - CollectionItems

    func testMapCollectionItem() {
        var card = TcgCard()
        card.id = "c1"
        card.name = "Charizard"

        var variant = TcgVariant()
        variant.id = "v1"
        variant.finish = .holo

        var paid = TcgMoney()
        paid.amount = "80.00"

        var item = TcgCollectionItem()
        item.id = "h1"
        item.card = card
        item.variant = variant
        item.quantity = 2
        item.condition = .nearMint
        item.paidPrice = paid
        item.acquiredAt = "2026-01-01"
        item.note = "mint"

        var proto = TcgCollectionItemsResponse()
        proto.items = [item]

        let items = WasmActor.mapCollectionItem(proto.items[0])
        XCTAssertEqual(items.id, "h1")
        XCTAssertEqual(items.card.name, "Charizard")
        XCTAssertEqual(items.variant.finish, .holo)
        XCTAssertEqual(items.quantity, 2)
        XCTAssertEqual(items.condition, .nearMint)
        XCTAssertEqual(items.paidPrice.amount, "80.00")
        XCTAssertEqual(items.acquiredAt, "2026-01-01")
        XCTAssertEqual(items.note, "mint")
    }

    // MARK: - AddCards (public input -> proto for JSON serialization)

    func testMapAddCardItem() {
        let input = WasmClient.TCG.AddCardItem(
            cardID: "c1",
            variantID: "v1",
            quantity: 3,
            condition: .lightlyPlayed,
            finish: .foil,
            paidPrice: "42.50"
        )

        let proto = WasmActor.mapAddCardItem(input)
        XCTAssertEqual(proto.cardID, "c1")
        XCTAssertEqual(proto.variantID, "v1")
        XCTAssertEqual(proto.quantity, 3)
        XCTAssertEqual(proto.condition, .lightlyPlayed)
        XCTAssertEqual(proto.finish, .foil)
        XCTAssertEqual(proto.paidPrice, "42.50")

        let json = try? proto.jsonUTF8Data()
        XCTAssertNotNil(json)
    }

    func testMapAddCardItemUnsetDefaults() {
        let input = WasmClient.TCG.AddCardItem(cardID: "c2")
        let proto = WasmActor.mapAddCardItem(input)
        XCTAssertEqual(proto.cardID, "c2")
        XCTAssertFalse(proto.hasVariantID)
        XCTAssertEqual(proto.condition, .unspecified)
        XCTAssertEqual(proto.finish, .unspecified)
        XCTAssertFalse(proto.hasPaidPrice)
    }
}
