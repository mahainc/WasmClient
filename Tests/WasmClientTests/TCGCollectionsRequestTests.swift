import XCTest

@testable import WasmClient

final class TCGCollectionsRequestTests: XCTestCase {

    // MARK: - Wire constants

    func testServiceMethodRawValues() {
        XCTAssertEqual(
            WasmClient.TCG.ServiceMethod.accountInfo.rawValue, "asyncify.tcg.TcgService/AccountInfo"
        )
        XCTAssertEqual(
            WasmClient.TCG.ServiceMethod.listCollections.rawValue,
            "asyncify.tcg.TcgService/ListCollections"
        )
        XCTAssertEqual(
            WasmClient.TCG.ServiceMethod.createCollection.rawValue,
            "asyncify.tcg.TcgService/CreateCollection"
        )
        XCTAssertEqual(
            WasmClient.TCG.ServiceMethod.updateCollection.rawValue,
            "asyncify.tcg.TcgService/UpdateCollection"
        )
        XCTAssertEqual(
            WasmClient.TCG.ServiceMethod.deleteCollection.rawValue,
            "asyncify.tcg.TcgService/DeleteCollection"
        )
        XCTAssertEqual(
            WasmClient.TCG.ServiceMethod.collectionSummary.rawValue,
            "asyncify.tcg.TcgService/CollectionSummary"
        )
        XCTAssertEqual(
            WasmClient.TCG.ServiceMethod.collectionItems.rawValue,
            "asyncify.tcg.TcgService/CollectionItems"
        )
        XCTAssertEqual(WasmClient.TCG.ServiceMethod.addCards.rawValue, "asyncify.tcg.TcgService/AddCards")
    }

    func testConditionRawValues() {
        XCTAssertEqual(WasmClient.TCG.Condition.nearMint.rawValue, "NEAR_MINT")
        XCTAssertEqual(WasmClient.TCG.Condition.lightlyPlayed.rawValue, "LIGHTLY_PLAYED")
        XCTAssertEqual(WasmClient.TCG.Condition.moderatelyPlayed.rawValue, "MODERATELY_PLAYED")
        XCTAssertEqual(WasmClient.TCG.Condition.heavilyPlayed.rawValue, "HEAVILY_PLAYED")
        XCTAssertEqual(WasmClient.TCG.Condition.damaged.rawValue, "DAMAGED")
    }

    // MARK: - Model defaults

    func testDefaults() {
        XCTAssertEqual(WasmClient.TCG.AccountInfo().account, WasmClient.TCG.Account())
        XCTAssertEqual(WasmClient.TCG.Collection().ordering, 0)
        XCTAssertEqual(WasmClient.TCG.CollectionSummary().totalCards, "")
        XCTAssertTrue(WasmClient.TCG.CollectionItems().items.isEmpty)
        XCTAssertFalse(WasmClient.TCG.AddCardsResult().ok)
    }

    // MARK: - Mocks

    func testNoopReturnsEmpty() async throws {
        let info = try await WasmClient.noop.tcgAccountInfo()
        XCTAssertEqual(info, WasmClient.TCG.AccountInfo())
        let collections = try await WasmClient.noop.tcgListCollections()
        XCTAssertTrue(collections.isEmpty)
        let items = try await WasmClient.noop.tcgCollectionItems("", nil, nil)
        XCTAssertEqual(items, WasmClient.TCG.CollectionItems())
        let added = try await WasmClient.noop.tcgAddCards("", [])
        XCTAssertEqual(added, WasmClient.TCG.AddCardsResult())
    }

    func testHappyReturnsPopulated() async throws {
        let info = try await WasmClient.happy.tcgAccountInfo()
        XCTAssertEqual(info.account.handle, "trainer")

        let collections = try await WasmClient.happy.tcgListCollections()
        XCTAssertEqual(collections.first?.name, "Binder")
        XCTAssertTrue(collections.first?.isDefault ?? false)

        let created = try await WasmClient.happy.tcgCreateCollection("Wishlist", true)
        XCTAssertEqual(created.first?.name, "Wishlist")
        XCTAssertTrue(created.first?.isPublic ?? false)

        let summary = try await WasmClient.happy.tcgCollectionSummary()
        XCTAssertEqual(summary.totalValue.amount, "9999.00")

        let items = try await WasmClient.happy.tcgCollectionItems("col1", nil, nil)
        XCTAssertEqual(items.items.first?.quantity, 2)
        XCTAssertEqual(items.items.first?.condition, .nearMint)

        let added = try await WasmClient.happy.tcgAddCards("col1", [])
        XCTAssertTrue(added.ok)
    }
}
