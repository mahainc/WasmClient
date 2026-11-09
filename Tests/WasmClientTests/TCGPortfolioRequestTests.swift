import XCTest

@testable import WasmClient

final class TCGPortfolioRequestTests: XCTestCase {

    // MARK: - Wire constants

    func testServiceMethodRawValues() {
        XCTAssertEqual(
            WasmClient.TCG.ServiceMethod.portfolioPerformance.rawValue,
            "asyncify.tcg.TcgService/PortfolioPerformance"
        )
        XCTAssertEqual(
            WasmClient.TCG.ServiceMethod.valueOverTime.rawValue,
            "asyncify.tcg.TcgService/ValueOverTime"
        )
        XCTAssertEqual(
            WasmClient.TCG.ServiceMethod.topMovers.rawValue,
            "asyncify.tcg.TcgService/TopMovers"
        )
        XCTAssertEqual(
            WasmClient.TCG.ServiceMethod.performanceBreakdown.rawValue,
            "asyncify.tcg.TcgService/PerformanceBreakdown"
        )
        XCTAssertEqual(
            WasmClient.TCG.ServiceMethod.profitLoss.rawValue,
            "asyncify.tcg.TcgService/ProfitLoss"
        )
    }

    // MARK: - Analytics enum argString

    func testAnalyticsWindowRawValues() {
        XCTAssertEqual(WasmClient.TCG.AnalyticsWindow.allTime.rawValue, "ALL_TIME")
        XCTAssertEqual(WasmClient.TCG.AnalyticsWindow.oneDay.rawValue, "1D")
        XCTAssertEqual(WasmClient.TCG.AnalyticsWindow.oneWeek.rawValue, "1W")
        XCTAssertEqual(WasmClient.TCG.AnalyticsWindow.oneMonth.rawValue, "1M")
        XCTAssertEqual(WasmClient.TCG.AnalyticsWindow.threeMonths.rawValue, "3M")
        XCTAssertEqual(WasmClient.TCG.AnalyticsWindow.sixMonths.rawValue, "6M")
        XCTAssertEqual(WasmClient.TCG.AnalyticsWindow.oneYear.rawValue, "1Y")
        XCTAssertEqual(WasmClient.TCG.AnalyticsWindow.max.rawValue, "MAX")
    }

    func testBreakdownFacetRawValues() {
        XCTAssertEqual(WasmClient.TCG.BreakdownFacet.bySet.rawValue, "BY_SET")
        XCTAssertEqual(WasmClient.TCG.BreakdownFacet.byRarity.rawValue, "BY_RARITY")
        XCTAssertEqual(WasmClient.TCG.BreakdownFacet.byGame.rawValue, "BY_GAME")
        XCTAssertEqual(WasmClient.TCG.BreakdownFacet.byFinish.rawValue, "BY_FINISH")
    }

    func testMoverDirectionRawValues() {
        XCTAssertEqual(WasmClient.TCG.MoverDirection.up.rawValue, "UP")
        XCTAssertEqual(WasmClient.TCG.MoverDirection.down.rawValue, "DOWN")
        XCTAssertEqual(WasmClient.TCG.MoverDirection.flat.rawValue, "FLAT")
    }

    // MARK: - Model defaults

    func testDefaults() {
        XCTAssertEqual(WasmClient.TCG.PortfolioPerformance().cardCount, 0)
        XCTAssertEqual(WasmClient.TCG.PortfolioPerformance().marketValue, WasmClient.TCG.Money())
        XCTAssertTrue(WasmClient.TCG.ValueOverTime().marketSeries.isEmpty)
        XCTAssertFalse(WasmClient.TCG.ValueOverTime().pnlSeriesIsDerived)
        XCTAssertTrue(WasmClient.TCG.TopMovers().movers.isEmpty)
        XCTAssertTrue(WasmClient.TCG.PerformanceBreakdown().groups.isEmpty)
        XCTAssertTrue(WasmClient.TCG.ProfitLoss().rows.isEmpty)
        XCTAssertEqual(WasmClient.TCG.ProfitLoss().summary, WasmClient.TCG.ProfitLossSummary())
    }

    func testIdentifiableIDs() {
        XCTAssertEqual(WasmClient.TCG.ValuePoint(at: "2026-01-01").id, "2026-01-01")
        XCTAssertEqual(WasmClient.TCG.BreakdownGroup(label: "Base Set").id, "Base Set")
        XCTAssertEqual(WasmClient.TCG.ProfitLossRow(categoryID: "pokemon").id, "pokemon")
    }

    // MARK: - Mocks

    func testNoopReturnsEmpty() async throws {
        let perf = try await WasmClient.noop.tcgPortfolioPerformance("", nil, nil, .allTime)
        XCTAssertEqual(perf, WasmClient.TCG.PortfolioPerformance())
        let series = try await WasmClient.noop.tcgValueOverTime("", .allTime, nil, nil)
        XCTAssertEqual(series, WasmClient.TCG.ValueOverTime())
        let movers = try await WasmClient.noop.tcgTopMovers("", .allTime, nil, nil, nil)
        XCTAssertEqual(movers, WasmClient.TCG.TopMovers())
        let breakdown = try await WasmClient.noop.tcgPerformanceBreakdown("", .bySet, .allTime, nil, nil)
        XCTAssertEqual(breakdown, WasmClient.TCG.PerformanceBreakdown())
        let pnl = try await WasmClient.noop.tcgProfitLoss("", nil)
        XCTAssertEqual(pnl, WasmClient.TCG.ProfitLoss())
    }

    func testHappyReturnsPopulated() async throws {
        let perf = try await WasmClient.happy.tcgPortfolioPerformance("col1", "USD", nil, .oneMonth)
        XCTAssertEqual(perf.cardCount, 12)
        XCTAssertEqual(perf.window, .oneMonth)
        XCTAssertEqual(perf.gain.amount, "371.47")

        let series = try await WasmClient.happy.tcgValueOverTime("col1", .oneYear, nil, nil)
        XCTAssertEqual(series.marketSeries.count, 2)
        XCTAssertEqual(series.window, .oneYear)
        XCTAssertTrue(series.peakIsCurrent)

        let movers = try await WasmClient.happy.tcgTopMovers("col1", .oneWeek, 5, nil, nil)
        XCTAssertEqual(movers.movers.count, 1)
        XCTAssertEqual(movers.movers.first?.card.name, "Charizard")
        XCTAssertEqual(movers.window, .oneWeek)

        let breakdown = try await WasmClient.happy.tcgPerformanceBreakdown("col1", .byGame, .threeMonths, nil, nil)
        XCTAssertEqual(breakdown.groups.count, 1)
        XCTAssertEqual(breakdown.groups.first?.direction, .up)
        XCTAssertEqual(breakdown.facet, .byGame)

        let pnl = try await WasmClient.happy.tcgProfitLoss("col1", "USD")
        XCTAssertEqual(pnl.currency, "USD")
        XCTAssertEqual(pnl.rows.count, 1)
        XCTAssertEqual(pnl.summary.roiPercentage, "371.475")
    }
}
