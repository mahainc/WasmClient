@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - News

extension WasmActor {
    func newsList(request: WasmClient.News.Request) async throws -> WasmClient.News.Feed {
        let instance = try await readyEngine()

        let args = Self.newsArgs(from: request)
        let method = WasmClient.News.ServiceMethod.list.rawValue
        logger("newsList: dispatch method=\(method) category=\(request.category.rawValue)")

        let resp: NewsNewsResponse = try await instance.run(method: method, args: args)
        logger("newsList: decoded \(resp.items.count) item(s), nextOffset=\(resp.nextOffset)")
        return Self.mapNewsFeed(resp)
    }

    // MARK: - Arg building

    // Mirrors news.fk.pb.swift's `argsFromRequest`: category/sort go on the wire as
    // their backend tokens, limit/offset as numbers, tags as a comma-joined string,
    // and params as a verbatim struct.
    static func newsArgs(
        from request: WasmClient.News.Request
    ) -> [String: Google_Protobuf_Value] {
        var args: [String: Google_Protobuf_Value] = [:]
        if !request.category.rawValue.isEmpty {
            args["category"] = Google_Protobuf_Value(stringValue: request.category.rawValue)
        }
        if let limit = request.limit {
            args["limit"] = Google_Protobuf_Value(numberValue: Double(limit))
        }
        if let offset = request.offset {
            args["offset"] = Google_Protobuf_Value(numberValue: Double(offset))
        }
        if let query = request.query, !query.isEmpty {
            args["q"] = Google_Protobuf_Value(stringValue: query)
        }
        if !request.tags.isEmpty {
            args["tags"] = Google_Protobuf_Value(stringValue: request.tags.joined(separator: ","))
        }
        if let sort = request.sort, !sort.rawValue.isEmpty {
            args["sort"] = Google_Protobuf_Value(stringValue: sort.rawValue)
        }
        if !request.params.isEmpty {
            var fields = Google_Protobuf_Struct()
            for (key, value) in request.params {
                fields.fields[key] = Google_Protobuf_Value(stringValue: value)
            }
            args["params"] = Google_Protobuf_Value(structValue: fields)
        }
        return args
    }

    // MARK: - Mapping

    static func mapNewsFeed(_ proto: NewsNewsResponse) -> WasmClient.News.Feed {
        WasmClient.News.Feed(
            items: proto.items.map(mapNewsItem),
            nextOffset: Int(proto.nextOffset),
            tagsVocabulary: proto.tags
        )
    }

    private static func mapNewsItem(_ proto: NewsNewsItem) -> WasmClient.News.Item {
        WasmClient.News.Item(
            id: proto.id,
            title: proto.title,
            url: proto.url,
            imageURL: proto.imageURL,
            source: proto.source,
            author: proto.author,
            publishedAt: proto.publishedAt,
            category: proto.category,
            hits: Int(proto.hits),
            metadata: mapNewsMetadata(proto.hasMetadata ? proto.metadata : nil)
        )
    }

    private static func mapNewsMetadata(
        _ metadata: Google_Protobuf_Struct?
    ) -> [String: String] {
        guard let metadata else { return [:] }
        var result: [String: String] = [:]
        for (key, value) in metadata.fields {
            result[key] = value.stringValue
        }
        return result
    }
}
