@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - News

extension WasmActor {

    /// FlowKit method id for the `news.list` rpc. News is dispatched by method
    /// NAME (it appears in a registered action's `methods`), not by a top-level
    /// UUID action id.
    private static let newsListMethod = "asyncify.news.NewsService/List"

    /// Fetch the news feed for a category. The binary FlowKit xcframework does
    /// not vend the generated `News.list` accessor's FFI helpers
    /// (`argsFromRequestFlatteningBase` / `run(method:)`), so we resolve the
    /// registered news action ourselves — finding the WaTAction whose `methods`
    /// contains the news method (which carries a real `provider`, satisfying the
    /// backend's required `provider_id`) — then `run(action:args:)`, which
    /// decodes the `NewsResponse` proto directly. Each row maps to a pure
    /// `News.Item` (tags/summary lifted out of the metadata struct).
    func newsList(
        category: WasmClient.News.Category,
        limit: Int?,
        offset: Int?,
        q: String?,
        tags: [String],
        sort: WasmClient.News.Sort,
        params: [String: String]
    ) async throws -> [WasmClient.News.Item] {
        let instance = try await readyEngine()

        guard let action = try await resolveNewsAction() else {
            logger("[news] no registered action exposes \(Self.newsListMethod)")
            throw WasmClient.Error.noProviderFound(action: Self.newsListMethod)
        }

        // CRITICAL: the engine's request flattener (argsFromRequestFlatteningBase
        // in flow-kit-example) sends EVERY arg as a STRING, with proto enums as
        // their SCREAMING_SNAKE wire name (NEWS_CATEGORY_HEALTH / NEWS_SORT_RECENT)
        // and limit/offset as stringified numbers. Sending category as "health"
        // or limit as a numberValue makes the wasm news call hang. Verified by
        // dumping the working example's flattened args 2026-06-29.
        func str(_ s: String) -> Google_Protobuf_Value { Google_Protobuf_Value(stringValue: s) }
        var args: [String: Google_Protobuf_Value] = [
            "category": str(category.protoName)
        ]
        if let limit { args["limit"] = str("\(limit)") }
        if let offset { args["offset"] = str("\(offset)") }
        if let q, !q.isEmpty { args["q"] = str(q) }
        if !tags.isEmpty {
            args["tags"] = Google_Protobuf_Value(
                listValue: Google_Protobuf_ListValue(values: tags.map(str))
            )
        }
        if sort != .unspecified {
            args["sort"] = str(sort.protoName)
        }
        for (key, value) in params {
            args[key] = str(value)
        }

        logger("[news] list category=\(category.protoName) provider=\(action.provider.prefix(12)) tags=\(tags)")
        // Dispatch by method-string actionId with an empty providerId — exactly
        // like flow-kit-example's generated `News.listTask`. The args MUST be the
        // string-encoded form built above; sending category as "health" or
        // limit as a number traps the wasm runtime.
        let task = try await instance.create(
            providerId: "", actionId: Self.newsListMethod, args: args
        )
        logger("[news] task status=\(task.status) hasValue=\(task.hasValue)")
        guard task.status == .completed, task.hasValue else {
            let detail = task.metadata.fields["error"]?.stringValue ?? "\(task.status)"
            logger("[news] FAILED detail=\(detail)")
            throw WasmClient.Error.taskFailed(status: detail)
        }
        let proto = try NewsNewsResponse(unpackingAny: task.value)
        logger("[news] decoded items=\(proto.items.count) vocab=\(proto.tags.count)")
        return proto.items.map(Self.mapNewsItem)
    }

    /// Find the registered action whose `methods` includes the news method.
    /// Triggers action discovery first (lazy), matching the lsWebpage path.
    private func resolveNewsAction() async throws -> WaTAction? {
        try await delegate.ensureActionsLoaded(logger: logger)
        var all = delegate.allActions()
        // The first discovery can land mid bundle-reload and miss late-registering
        // actions (news, chat, calories). If news isn't present yet, re-poll once.
        if !all.contains(where: { $0.methods.contains(Self.newsListMethod) || $0.id == Self.newsListMethod }) {
            logger("[news] not in \(all.count) actions; refreshing…")
            try? await delegate.refreshActions(logger: logger)
            all = delegate.allActions()
        }
        // News is dispatched by method NAME — find the action whose `methods`
        // lists it. Fall back to id == method in case a build registers it that
        // way.
        return all.first { $0.methods.contains(Self.newsListMethod) }
            ?? all.first { $0.id == Self.newsListMethod }
    }

    // MARK: - Mapping (proto → pure model)

    private static func mapNewsItem(_ p: NewsNewsItem) -> WasmClient.News.Item {
        WasmClient.News.Item(
            id: p.id,
            title: p.title,
            url: p.url,
            imageURL: p.imageURL,
            source: p.source,
            author: p.author,
            publishedAt: p.publishedAt,
            category: p.category,
            hits: p.hits,
            tags: p.hasMetadata ? newsTags(from: p.metadata) : [],
            summary: p.hasMetadata ? newsSummary(from: p.metadata) : ""
        )
    }

    /// Pull the `tags` string list out of the row's `metadata` struct
    /// (per-row tag assignment lives there, not at row level).
    private static func newsTags(from metadata: Google_Protobuf_Struct) -> [String] {
        guard let list = metadata.fields["tags"]?.listValue else { return [] }
        return list.values.compactMap { $0.stringValue.isEmpty ? nil : $0.stringValue }
    }

    private static func newsSummary(from metadata: Google_Protobuf_Struct) -> String {
        metadata.fields["summary"]?.stringValue ?? ""
    }
}
