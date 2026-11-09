import Foundation

// MARK: - News Namespace

extension WasmClient {
    public enum News {}
}

// MARK: - Category

extension WasmClient.News {
    // `rawValue` IS the backend category token (the `argString` wire form).
    // Unknown verticals from a newer backend round-trip losslessly.
    public struct Category: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }

        public static let soccer = Category(rawValue: "soccer")
        public static let health = Category(rawValue: "health")
        public static let plantCare = Category(rawValue: "plant-care")
    }
}

// MARK: - Sort

extension WasmClient.News {
    // `rawValue` IS the backend `sort` token; empty = backend default (`recent`).
    public struct Sort: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }

        public static let recent = Sort(rawValue: "recent")
        public static let trending = Sort(rawValue: "trending")
    }
}

// MARK: - ServiceMethod

extension WasmClient.News {
    // FlowKit service RPC method name (mirrors news.fk.pb.swift).
    public struct ServiceMethod: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }

        public static let list = ServiceMethod(rawValue: "asyncify.news.NewsService/List")
    }
}

// MARK: - Request

extension WasmClient.News {
    public struct Request: Sendable, Equatable {
        public let category: Category
        public let limit: Int?
        public let offset: Int?
        public let query: String?
        public let tags: [String]
        public let sort: Sort?
        public let params: [String: String]

        public init(
            category: Category,
            limit: Int? = nil,
            offset: Int? = nil,
            query: String? = nil,
            tags: [String] = [],
            sort: Sort? = nil,
            params: [String: String] = [:]
        ) {
            self.category = category
            self.limit = limit
            self.offset = offset
            self.query = query
            self.tags = tags
            self.sort = sort
            self.params = params
        }
    }
}

// MARK: - Item

extension WasmClient.News {
    public struct Item: Sendable, Equatable, Identifiable {
        public let id: String
        public let title: String
        public let url: String
        public let imageURL: String
        public let source: String
        public let author: String
        public let publishedAt: String
        public let category: String
        public let hits: Int
        public let metadata: [String: String]

        public init(
            id: String = "",
            title: String = "",
            url: String = "",
            imageURL: String = "",
            source: String = "",
            author: String = "",
            publishedAt: String = "",
            category: String = "",
            hits: Int = 0,
            metadata: [String: String] = [:]
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
            self.metadata = metadata
        }
    }
}

// MARK: - Feed (response)

extension WasmClient.News {
    public struct Feed: Sendable, Equatable {
        public let items: [Item]
        public let nextOffset: Int
        public let tagsVocabulary: [String]

        public init(
            items: [Item] = [],
            nextOffset: Int = 0,
            tagsVocabulary: [String] = []
        ) {
            self.items = items
            self.nextOffset = nextOffset
            self.tagsVocabulary = tagsVocabulary
        }
    }
}
