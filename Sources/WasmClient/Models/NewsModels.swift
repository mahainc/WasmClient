import Foundation

// MARK: - News Namespace

extension WasmClient {
    /// Namespace for the category-agnostic news feed (the wasm `news.list`
    /// action, backed by the backend `/mobile/news` route). Pure-Swift mirror
    /// of the `asyncify.news` proto — no SwiftProtobuf surface leaks into the
    /// interface, matching `LiveScore`.
    public enum News {}
}

// MARK: - Category

extension WasmClient.News {
    /// Vertical the feed is sourced from. Serialized on the wire as the
    /// lowercase token (`argString`) so the backend's `NewsRequest.category:
    /// String` deserializes one-to-one.
    public enum Category: Int, Sendable, Equatable {
        case unspecified = 0
        case soccer = 1
        case health = 2

        /// Rust wire-format string the backend expects.
        public var argString: String {
            switch self {
            case .unspecified: ""
            case .soccer: "soccer"
            case .health: "health"
            }
        }

        /// Proto SCREAMING_SNAKE wire name — this is what the engine's request
        /// flattener actually sends (`NEWS_CATEGORY_HEALTH`), NOT `argString`.
        public var protoName: String {
            switch self {
            case .unspecified: ""
            case .soccer: "NEWS_CATEGORY_SOCCER"
            case .health: "NEWS_CATEGORY_HEALTH"
            }
        }
    }
}

// MARK: - Sort

extension WasmClient.News {
    /// Sort mode forwarded as the request body's `sort` string. `recent`
    /// (published_at DESC, default) or `trending` (trailing-7-day resolves).
    public enum Sort: Int, Sendable, Equatable {
        case unspecified = 0
        case recent = 1
        case trending = 2

        public var argString: String {
            switch self {
            case .unspecified: ""
            case .recent: "recent"
            case .trending: "trending"
            }
        }

        /// Proto SCREAMING_SNAKE wire name (`NEWS_SORT_RECENT`) — what the
        /// engine's request flattener sends.
        public var protoName: String {
            switch self {
            case .unspecified: ""
            case .recent: "NEWS_SORT_RECENT"
            case .trending: "NEWS_SORT_TRENDING"
            }
        }
    }
}

// MARK: - Item

extension WasmClient.News {
    /// One article row returned by `news.list`. `tags` + `summary` are lifted
    /// out of the proto row's `metadata` struct during mapping so consumers
    /// never touch `Google_Protobuf_Struct`.
    public struct Item: Sendable, Equatable, Identifiable {
        public let id: String
        public let title: String
        /// Backend shortlink URL (resolves to the source permalink).
        public let url: String
        /// Lead image URL; empty when the article has none.
        public let imageURL: String
        /// Source slug (e.g. `"runners-world"`).
        public let source: String
        public let author: String
        /// RFC 3339 UTC publication timestamp (e.g. `"2026-06-25T07:40:40Z"`).
        public let publishedAt: String
        /// Category slug echoed from the request (`"health"`).
        public let category: String
        public let hits: Int64
        /// Closed-vocabulary tags from `metadata.tags` (health verticals).
        public let tags: [String]
        /// `metadata.summary`; empty when the row has no summary.
        public let summary: String

        public init(
            id: String,
            title: String,
            url: String,
            imageURL: String = "",
            source: String = "",
            author: String = "",
            publishedAt: String = "",
            category: String = "",
            hits: Int64 = 0,
            tags: [String] = [],
            summary: String = ""
        ) {
            self.id = id
            self.title = title
            self.url = url
            self.imageURL = imageURL
            self.source = source
            self.author = author
            self.publishedAt = publishedAt
            self.category = category
            self.hits = hits
            self.tags = tags
            self.summary = summary
        }
    }
}
