import XCTest

@testable import WasmClient

final class NewsRequestTests: XCTestCase {

    // MARK: - Wire constants

    func testCategoryRawValues() {
        XCTAssertEqual(WasmClient.News.Category.soccer.rawValue, "soccer")
        XCTAssertEqual(WasmClient.News.Category.health.rawValue, "health")
        XCTAssertEqual(WasmClient.News.Category.plantCare.rawValue, "plant-care")
    }

    func testSortRawValues() {
        XCTAssertEqual(WasmClient.News.Sort.recent.rawValue, "recent")
        XCTAssertEqual(WasmClient.News.Sort.trending.rawValue, "trending")
    }

    func testServiceMethodListRawValue() {
        XCTAssertEqual(
            WasmClient.News.ServiceMethod.list.rawValue,
            "asyncify.news.NewsService/List"
        )
    }

    func testUnknownCategoryRoundTrips() {
        let custom = WasmClient.News.Category(rawValue: "crypto")
        XCTAssertEqual(custom.rawValue, "crypto")
    }

    // MARK: - Model defaults

    func testRequestDefaults() {
        let request = WasmClient.News.Request(category: .soccer)
        XCTAssertEqual(request.category, .soccer)
        XCTAssertNil(request.limit)
        XCTAssertNil(request.offset)
        XCTAssertNil(request.query)
        XCTAssertTrue(request.tags.isEmpty)
        XCTAssertNil(request.sort)
        XCTAssertTrue(request.params.isEmpty)
    }

    func testFeedDefaults() {
        let feed = WasmClient.News.Feed()
        XCTAssertTrue(feed.items.isEmpty)
        XCTAssertEqual(feed.nextOffset, 0)
        XCTAssertTrue(feed.tagsVocabulary.isEmpty)
    }

    // MARK: - Mocks

    func testNoopReturnsEmptyFeed() async throws {
        let feed = try await WasmClient.noop.newsList(
            WasmClient.News.Request(category: .health)
        )
        XCTAssertEqual(feed, WasmClient.News.Feed())
    }

    func testHappyReturnsPopulatedFeedEchoingCategory() async throws {
        let feed = try await WasmClient.happy.newsList(
            WasmClient.News.Request(category: .plantCare)
        )
        XCTAssertEqual(feed.items.count, 1)
        XCTAssertEqual(feed.items.first?.category, "plant-care")
        XCTAssertEqual(feed.nextOffset, 1)
    }
}
