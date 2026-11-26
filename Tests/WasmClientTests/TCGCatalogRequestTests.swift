import XCTest

@testable import WasmClient

final class TCGCatalogRequestTests: XCTestCase {

    // MARK: - Wire constants

    func testServiceMethodRawValues() {
        XCTAssertEqual(WasmClient.TCG.ServiceMethod.scan.rawValue, "asyncify.tcg.TcgService/Scan")
        XCTAssertEqual(
            WasmClient.TCG.ServiceMethod.catalogDetail.rawValue, "asyncify.tcg.TcgService/CatalogDetail"
        )
        XCTAssertEqual(
            WasmClient.TCG.ServiceMethod.soldListings.rawValue, "asyncify.tcg.TcgService/SoldListings"
        )
        XCTAssertEqual(
            WasmClient.TCG.ServiceMethod.catalogBrowse.rawValue, "asyncify.tcg.TcgService/CatalogBrowse"
        )
        XCTAssertEqual(WasmClient.TCG.ServiceMethod.trending.rawValue, "asyncify.tcg.TcgService/Trending")
        XCTAssertEqual(
            WasmClient.TCG.ServiceMethod.searchFilters.rawValue, "asyncify.tcg.TcgService/SearchFilters"
        )
        XCTAssertEqual(WasmClient.TCG.ServiceMethod.listSets.rawValue, "asyncify.tcg.TcgService/ListSets")
    }

    func testGameRawValues() {
        XCTAssertEqual(WasmClient.TCG.Game.pokemon.rawValue, "POKEMON")
        XCTAssertEqual(WasmClient.TCG.Game.pokemonJP.rawValue, "POKEMON_JP")
        XCTAssertEqual(WasmClient.TCG.Game.magicTheGathering.rawValue, "MTG")
        XCTAssertEqual(WasmClient.TCG.Game.onePiece.rawValue, "ONE_PIECE")
        XCTAssertEqual(WasmClient.TCG.Game.lorcana.rawValue, "LORCANA")
        XCTAssertEqual(WasmClient.TCG.Game.yugioh.rawValue, "YUGIOH")
        XCTAssertEqual(WasmClient.TCG.Game.generic.rawValue, "GENERIC")
    }

    func testFinishRawValues() {
        XCTAssertEqual(WasmClient.TCG.Finish.normal.rawValue, "NORMAL")
        XCTAssertEqual(WasmClient.TCG.Finish.reverseHolo.rawValue, "REVERSE_HOLO")
        XCTAssertEqual(WasmClient.TCG.Finish.parallel.rawValue, "PARALLEL")
    }

    // MARK: - Model defaults

    func testDefaults() {
        XCTAssertTrue(WasmClient.TCG.ScanResult().matches.isEmpty)
        XCTAssertEqual(WasmClient.TCG.CatalogDetail().ownedCount, 0)
        XCTAssertFalse(WasmClient.TCG.SoldListings().hasMore)
        XCTAssertTrue(WasmClient.TCG.CatalogBrowse().cards.isEmpty)
        XCTAssertTrue(WasmClient.TCG.ListSets().sets.isEmpty)
    }

    // MARK: - Mocks

    func testNoopReturnsEmpty() async throws {
        let scan = try await WasmClient.noop.tcgScan("", .pokemon)
        XCTAssertEqual(scan, WasmClient.TCG.ScanResult())
        let browse = try await WasmClient.noop.tcgCatalogBrowse(nil, nil, .pokemon, nil, nil, nil, [], nil)
        XCTAssertEqual(browse, WasmClient.TCG.CatalogBrowse())
        let filters = try await WasmClient.noop.tcgSearchFilters()
        XCTAssertEqual(filters, WasmClient.TCG.SearchFilters())
    }

    func testHappyReturnsPopulated() async throws {
        let scan = try await WasmClient.happy.tcgScan("img", .pokemon)
        XCTAssertEqual(scan.matches.first?.card.name, "Charizard")

        let detail = try await WasmClient.happy.tcgCatalogDetail("c1", nil)
        XCTAssertEqual(detail.card.id, "c1")
        XCTAssertEqual(detail.ownedCount, 2)

        let sold = try await WasmClient.happy.tcgSoldListings("c1", nil, nil, nil, nil)
        XCTAssertEqual(sold.listings.first?.marketplace, "eBay")
        XCTAssertTrue(sold.hasMore)

        let sets = try await WasmClient.happy.tcgListSets(nil, .pokemon, nil, "EUR", nil)
        XCTAssertEqual(sets.sets.first?.name, "Base Set")
        XCTAssertEqual(sets.currency, "EUR")
    }
}
