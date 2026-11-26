import SwiftProtobuf
import XCTest

@testable import WasmClient
@testable import WasmClientLive

final class TCGPortfolioMapperTests: XCTestCase {

    private func money(_ amount: String, _ currency: String = "USD") -> TcgMoney {
        var m = TcgMoney()
        m.amount = amount
        m.currency = currency
        return m
    }

    // MARK: - Enum mapping

    func testMapWindow() {
        XCTAssertEqual(WasmActor.mapWindow(.unspecified), .allTime)
        XCTAssertEqual(WasmActor.mapWindow(.oneDay), .oneDay)
        XCTAssertEqual(WasmActor.mapWindow(.max), .max)
        XCTAssertEqual(WasmActor.mapWindow(.UNRECOGNIZED(99)), .threeMonths)
    }

    func testMapFacet() {
        XCTAssertEqual(WasmActor.mapFacet(.unspecified), .bySet)
        XCTAssertEqual(WasmActor.mapFacet(.byRarity), .byRarity)
        XCTAssertEqual(WasmActor.mapFacet(.byFinish), .byFinish)
        XCTAssertEqual(WasmActor.mapFacet(.UNRECOGNIZED(99)), .bySet)
    }

    func testMapMoverDirection() {
        XCTAssertEqual(WasmActor.mapMoverDirection(.up), .up)
        XCTAssertEqual(WasmActor.mapMoverDirection(.down), .down)
        XCTAssertEqual(WasmActor.mapMoverDirection(.flat), .flat)
        XCTAssertEqual(WasmActor.mapMoverDirection(.unspecified), WasmClient.TCG.MoverDirection(rawValue: ""))
    }

    // MARK: - PortfolioPerformance

    func testMapPortfolioPerformance() {
        var proto = TcgPortfolioPerformanceResponse()
        proto.costBasis = money("100.00")
        proto.marketValue = money("471.47")
        proto.gain = money("371.47")
        proto.roiPercentage = "371.475"
        proto.cardCount = 12
        proto.window = .oneMonth

        let result = WasmActor.mapPortfolioPerformance(proto)
        XCTAssertEqual(result.costBasis.amount, "100.00")
        XCTAssertEqual(result.marketValue.amount, "471.47")
        XCTAssertEqual(result.gain.amount, "371.47")
        XCTAssertEqual(result.roiPercentage, "371.475")
        XCTAssertEqual(result.cardCount, 12)
        XCTAssertEqual(result.window, .oneMonth)
    }

    // MARK: - ValueOverTime

    func testMapValueOverTime() {
        var p1 = TcgValuePoint()
        p1.at = "2026-01-01"
        p1.value = money("400.00")
        var p2 = TcgValuePoint()
        p2.at = "2026-02-01"
        p2.value = money("471.47")

        var card = TcgCard()
        card.id = "c1"
        card.name = "Charizard"
        var section = TcgCarouselSection()
        section.title = "Top Gainers"
        section.sortID = "trendingToday"
        section.cards = [card]
        section.kind = .trending

        var proto = TcgValueOverTimeResponse()
        proto.marketSeries = [p1, p2]
        proto.peakValue = money("471.47")
        proto.peakAt = "2026-02-01"
        proto.peakIsCurrent = true
        proto.window = .oneYear
        proto.unrealizedPnlSeries = [p1]
        proto.pnlSeriesIsDerived = true
        proto.carousel = [section]

        let result = WasmActor.mapValueOverTime(proto)
        XCTAssertEqual(result.marketSeries.count, 2)
        XCTAssertEqual(result.marketSeries.first?.at, "2026-01-01")
        XCTAssertEqual(result.peakValue.amount, "471.47")
        XCTAssertEqual(result.peakAt, "2026-02-01")
        XCTAssertTrue(result.peakIsCurrent)
        XCTAssertEqual(result.window, .oneYear)
        XCTAssertEqual(result.unrealizedPnlSeries.count, 1)
        XCTAssertTrue(result.pnlSeriesIsDerived)
        XCTAssertEqual(result.carousel.count, 1)
        XCTAssertEqual(result.carousel.first?.title, "Top Gainers")
        XCTAssertEqual(result.carousel.first?.cards.first?.name, "Charizard")
        XCTAssertEqual(result.carousel.first?.kind, .trending)
    }

    // MARK: - TopMovers

    func testMapTopMovers() {
        var card = TcgCard()
        card.id = "c1"
        card.name = "Charizard"

        var mover = TcgMover()
        mover.card = card
        mover.currentPrice = money("471.47")
        mover.windowOpenPrice = money("400.00")
        mover.priceChange = money("71.47")
        mover.changePercentage = "17.868"

        var proto = TcgTopMoversResponse()
        proto.movers = [mover]
        proto.window = .oneWeek

        let result = WasmActor.mapTopMovers(proto)
        XCTAssertEqual(result.movers.count, 1)
        XCTAssertEqual(result.movers.first?.card.name, "Charizard")
        XCTAssertEqual(result.movers.first?.changePercentage, "17.868")
        XCTAssertEqual(result.window, .oneWeek)
    }

    // MARK: - PerformanceBreakdown

    func testMapPerformanceBreakdown() {
        var group = TcgBreakdownGroup()
        group.label = "Base Set"
        group.cardCount = 5
        group.marketValue = money("300.00")
        group.changePercentage = "12.5"
        group.direction = .up
        group.barFill = 1.0

        var proto = TcgPerformanceBreakdownResponse()
        proto.groups = [group]
        proto.facet = .byGame
        proto.window = .threeMonths

        let result = WasmActor.mapPerformanceBreakdown(proto)
        XCTAssertEqual(result.groups.count, 1)
        XCTAssertEqual(result.groups.first?.label, "Base Set")
        XCTAssertEqual(result.groups.first?.cardCount, 5)
        XCTAssertEqual(result.groups.first?.direction, .up)
        XCTAssertEqual(result.groups.first?.barFill, 1.0)
        XCTAssertEqual(result.facet, .byGame)
        XCTAssertEqual(result.window, .threeMonths)
    }

    // MARK: - ProfitLoss

    func testMapProfitLoss() {
        var summary = TcgProfitLossSummary()
        summary.costBasis = money("100.00")
        summary.marketValue = money("471.47")
        summary.gain = money("371.47")
        summary.roiPercentage = "371.475"

        var row = TcgProfitLossRow()
        row.game = .pokemon
        row.categoryID = "pokemon"
        row.categoryName = "Pokémon"
        row.costBasis = money("100.00")
        row.marketValue = money("471.47")
        row.gain = money("371.47")
        row.roiPercentage = "371.475"

        var proto = TcgProfitLossResponse()
        proto.currency = "USD"
        proto.summary = summary
        proto.rows = [row]

        let result = WasmActor.mapProfitLoss(proto)
        XCTAssertEqual(result.currency, "USD")
        XCTAssertEqual(result.summary.roiPercentage, "371.475")
        XCTAssertEqual(result.rows.count, 1)
        XCTAssertEqual(result.rows.first?.game, .pokemon)
        XCTAssertEqual(result.rows.first?.categoryName, "Pokémon")
        XCTAssertEqual(result.rows.first?.id, "pokemon")
    }
}
