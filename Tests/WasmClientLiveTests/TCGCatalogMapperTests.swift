import SwiftProtobuf
import XCTest

@testable import WasmClient
@testable import WasmClientLive

final class TCGCatalogMapperTests: XCTestCase {

    // MARK: - Enum mapping

    func testMapGame() {
        XCTAssertEqual(WasmActor.mapGame(.pokemon), .pokemon)
        XCTAssertEqual(WasmActor.mapGame(.magicTheGathering), .magicTheGathering)
        XCTAssertEqual(WasmActor.mapGame(.generic), .generic)
        XCTAssertEqual(WasmActor.mapGame(.unspecified).rawValue, "")
    }

    func testMapFinish() {
        XCTAssertEqual(WasmActor.mapFinish(.foil), .foil)
        XCTAssertEqual(WasmActor.mapFinish(.reverseHolo), .reverseHolo)
        XCTAssertEqual(WasmActor.mapFinish(.unspecified).rawValue, "")
    }

    // MARK: - Card (nested money, variants, metadata)

    func testMapCard() {
        var variant = TcgVariant()
        variant.id = "v1"
        variant.finish = .holo
        variant.grade = "PSA 9"

        var price = TcgMoney()
        price.amount = "100.00"
        price.currency = "USD"

        var metadata = Google_Protobuf_Struct()
        metadata.fields = ["rarity": Google_Protobuf_Value(stringValue: "Rare")]

        var proto = TcgCard()
        proto.id = "c1"
        proto.name = "Charizard"
        proto.game = .pokemon
        proto.setName = "Base Set"
        proto.marketPrice = price
        proto.isCard = true
        proto.variants = [variant]
        proto.metadata = metadata

        let card = WasmActor.mapCard(proto)
        XCTAssertEqual(card.id, "c1")
        XCTAssertEqual(card.name, "Charizard")
        XCTAssertEqual(card.game, .pokemon)
        XCTAssertEqual(card.marketPrice.amount, "100.00")
        XCTAssertEqual(card.variants.first?.finish, .holo)
        XCTAssertEqual(card.variants.first?.grade, "PSA 9")
        XCTAssertEqual(card.metadata["rarity"], "Rare")
    }

    // MARK: - Scan

    func testMapScan() {
        var card = TcgCard()
        card.id = "c1"

        var match = TcgCardMatch()
        match.card = card
        match.confidence = 0.88

        var proto = TcgScanResponse()
        proto.scansRemaining = 5
        proto.matches = [match]

        let result = WasmActor.mapScan(proto)
        XCTAssertEqual(result.scansRemaining, 5)
        XCTAssertEqual(result.matches.first?.card.id, "c1")
        XCTAssertEqual(result.matches.first?.confidence, 0.88)
    }

    // MARK: - CatalogDetail (price history, grade prices, population)

    func testMapCatalogDetail() {
        var point = TcgPricePoint()
        point.at = "2026-01-01"
        var pointPrice = TcgMoney()
        pointPrice.amount = "90.00"
        point.price = pointPrice

        var grade = TcgGradePrice()
        grade.gradeLabel = "PSA 10"

        var pop = TcgGradePopulation()
        pop.gradeLabel = "PSA 10"
        pop.count = 1200
        pop.at = "2026-01-01"

        var proto = TcgCatalogDetailResponse()
        var card = TcgCard()
        card.id = "c1"
        proto.card = card
        proto.priceHistory = [point]
        proto.gradedPrices = [grade]
        proto.population = [pop]
        proto.ownedCount = 3

        let detail = WasmActor.mapCatalogDetail(proto)
        XCTAssertEqual(detail.card.id, "c1")
        XCTAssertEqual(detail.priceHistory.first?.price.amount, "90.00")
        XCTAssertEqual(detail.gradedPrices.first?.gradeLabel, "PSA 10")
        XCTAssertEqual(detail.population.first?.count, 1200)
        XCTAssertEqual(detail.ownedCount, 3)
    }

    // MARK: - SoldListings

    func testMapSoldListings() {
        var listing = TcgSoldListing()
        listing.id = "l1"
        listing.marketplace = "eBay"
        listing.bidCount = 4
        var price = TcgMoney()
        price.amount = "120.00"
        listing.price = price

        var proto = TcgSoldListingsResponse()
        proto.searchURL = "https://ebay.com/sold"
        proto.listings = [listing]
        proto.hasMore_p = true

        let result = WasmActor.mapSoldListings(proto)
        XCTAssertEqual(result.searchURL, "https://ebay.com/sold")
        XCTAssertEqual(result.listings.first?.marketplace, "eBay")
        XCTAssertEqual(result.listings.first?.bidCount, 4)
        XCTAssertEqual(result.listings.first?.price.amount, "120.00")
        XCTAssertTrue(result.hasMore)
    }

    // MARK: - CatalogBrowse

    func testMapCatalogBrowse() {
        var card = TcgCard()
        card.id = "c1"
        card.game = .magicTheGathering

        var proto = TcgCatalogBrowseResponse()
        proto.cards = [card]
        proto.page = 2
        proto.total = 42

        let result = WasmActor.mapCatalogBrowse(proto)
        XCTAssertEqual(result.cards.first?.game, .magicTheGathering)
        XCTAssertEqual(result.page, 2)
        XCTAssertEqual(result.total, 42)
    }

    // MARK: - SearchFilters (nested categories + mutex)

    func testMapSearchFilters() {
        var filter = TcgSearchFilter()
        filter.id = "f1"
        filter.name = "Pokemon"
        filter.game = .pokemon

        var category = TcgSearchFilterCategory()
        category.title = "Category"
        category.filters = [filter]

        var mutex = TcgFilterMutexGroup()
        mutex.filterIds = ["owned", "not_owned"]

        var sort = TcgSortOption()
        sort.id = "price"
        sort.displayName = "Price"

        var proto = TcgSearchFiltersResponse()
        proto.filters = [filter]
        proto.sortOptions = [sort]
        proto.categories = [category]
        proto.mutexGroups = [mutex]

        let result = WasmActor.mapSearchFilters(proto)
        XCTAssertEqual(result.filters.first?.game, .pokemon)
        XCTAssertEqual(result.sortOptions.first?.displayName, "Price")
        XCTAssertEqual(result.categories.first?.filters.first?.id, "f1")
        XCTAssertEqual(result.mutexGroups.first?.filterIds, ["owned", "not_owned"])
    }

    // MARK: - ListSets

    func testMapListSets() {
        var set = TcgCardSet()
        set.id = "s1"
        set.name = "Base Set"
        set.cardCount = 102

        var language = TcgSetLanguage()
        language.code = "en"
        language.description_p = "English"
        language.orderNumber = 1

        var category = TcgCategoryDetails()
        category.name = "Pokemon"

        var proto = TcgListSetsResponse()
        proto.sets = [set]
        proto.languages = [language]
        proto.category = category
        proto.currency = "USD"

        let result = WasmActor.mapListSets(proto)
        XCTAssertEqual(result.sets.first?.cardCount, 102)
        XCTAssertEqual(result.languages.first?.description, "English")
        XCTAssertEqual(result.category.name, "Pokemon")
        XCTAssertEqual(result.currency, "USD")
    }
}
