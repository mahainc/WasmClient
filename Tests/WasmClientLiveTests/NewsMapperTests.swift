import SwiftProtobuf
import XCTest

@testable import WasmClient
@testable import WasmClientLive

final class NewsMapperTests: XCTestCase {

    // MARK: - Request → wire args

    func testArgsOmitsUnsetOptionalFields() {
        let args = WasmActor.newsArgs(
            from: WasmClient.News.Request(category: .soccer)
        )
        XCTAssertEqual(args["category"]?.stringValue, "soccer")
        XCTAssertNil(args["limit"])
        XCTAssertNil(args["offset"])
        XCTAssertNil(args["q"])
        XCTAssertNil(args["tags"])
        XCTAssertNil(args["sort"])
        XCTAssertNil(args["params"])
    }

    func testArgsIncludesAllProvidedFields() {
        let args = WasmActor.newsArgs(
            from: WasmClient.News.Request(
                category: .health,
                limit: 30,
                offset: 60,
                query: "sleep",
                tags: ["diet", "fitness"],
                sort: .trending,
                params: ["team_id": "42"]
            )
        )
        XCTAssertEqual(args["category"]?.stringValue, "health")
        XCTAssertEqual(args["limit"]?.numberValue, 30)
        XCTAssertEqual(args["offset"]?.numberValue, 60)
        XCTAssertEqual(args["q"]?.stringValue, "sleep")
        XCTAssertEqual(args["tags"]?.stringValue, "diet,fitness")
        XCTAssertEqual(args["sort"]?.stringValue, "trending")
        XCTAssertEqual(args["params"]?.structValue.fields["team_id"]?.stringValue, "42")
    }

    func testArgsOmitsEmptyQueryAndTags() {
        let args = WasmActor.newsArgs(
            from: WasmClient.News.Request(category: .soccer, query: "", tags: [])
        )
        XCTAssertNil(args["q"])
        XCTAssertNil(args["tags"])
    }

    // MARK: - Proto → public mapping

    func testMapFeedMapsItemsAndCursor() {
        var item = NewsNewsItem()
        item.id = "a1"
        item.title = "Title"
        item.url = "https://example.com/s/a1"
        item.imageURL = "https://example.com/a1.jpg"
        item.source = "src"
        item.author = "Author"
        item.publishedAt = "2026-06-25T07:40:40Z"
        item.category = "soccer"
        item.hits = 7

        var response = NewsNewsResponse()
        response.items = [item]
        response.nextOffset = 30
        response.tags = ["calories", "nutrition"]

        let feed = WasmActor.mapNewsFeed(response)
        XCTAssertEqual(feed.items.count, 1)
        XCTAssertEqual(feed.items.first?.id, "a1")
        XCTAssertEqual(feed.items.first?.title, "Title")
        XCTAssertEqual(feed.items.first?.hits, 7)
        XCTAssertEqual(feed.items.first?.metadata, [:])
        XCTAssertEqual(feed.nextOffset, 30)
        XCTAssertEqual(feed.tagsVocabulary, ["calories", "nutrition"])
    }

    func testMapItemReadsMetadataStruct() {
        var metadata = Google_Protobuf_Struct()
        metadata.fields["summary"] = Google_Protobuf_Value(stringValue: "A summary")

        var item = NewsNewsItem()
        item.id = "a2"
        item.metadata = metadata

        var response = NewsNewsResponse()
        response.items = [item]

        let feed = WasmActor.mapNewsFeed(response)
        XCTAssertEqual(feed.items.first?.metadata, ["summary": "A summary"])
    }

    func testMapEmptyResponse() {
        let feed = WasmActor.mapNewsFeed(NewsNewsResponse())
        XCTAssertTrue(feed.items.isEmpty)
        XCTAssertEqual(feed.nextOffset, 0)
        XCTAssertTrue(feed.tagsVocabulary.isEmpty)
    }
}
