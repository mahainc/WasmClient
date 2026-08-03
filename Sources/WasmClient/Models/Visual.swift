import Foundation

// MARK: - Visual / Media

extension WasmClient {
    public enum Visual {}
}

extension WasmClient.Visual {

    public struct SearchResult: Sendable, Equatable {
        public let total: Int
        public let totalPages: Int
        public let results: [Photo]

        public init(
            total: Int = 0,
            totalPages: Int = 0,
            results: [Photo] = []
        ) {
            self.total = total
            self.totalPages = totalPages
            self.results = results
        }
    }

    public struct Photo: Sendable, Equatable, Identifiable {
        public let id: String
        public let description: String
        public let altDescription: String
        public let width: Int
        public let height: Int
        public let color: String
        public let blurHash: String
        public let urls: URLs
        public let userName: String
        public let userProfileImage: String
        public let linkHTML: String
        public let linkDownload: String
        public let likes: Int

        public init(
            id: String = "",
            description: String = "",
            altDescription: String = "",
            width: Int = 0,
            height: Int = 0,
            color: String = "",
            blurHash: String = "",
            urls: URLs = URLs(),
            userName: String = "",
            userProfileImage: String = "",
            linkHTML: String = "",
            linkDownload: String = "",
            likes: Int = 0
        ) {
            self.id = id
            self.description = description
            self.altDescription = altDescription
            self.width = width
            self.height = height
            self.color = color
            self.blurHash = blurHash
            self.urls = urls
            self.userName = userName
            self.userProfileImage = userProfileImage
            self.linkHTML = linkHTML
            self.linkDownload = linkDownload
            self.likes = likes
        }
    }

    public struct URLs: Sendable, Equatable {
        public let raw: String
        public let full: String
        public let regular: String
        public let small: String
        public let thumb: String

        public init(
            raw: String = "",
            full: String = "",
            regular: String = "",
            small: String = "",
            thumb: String = ""
        ) {
            self.raw = raw
            self.full = full
            self.regular = regular
            self.small = small
            self.thumb = thumb
        }
    }
}

// MARK: - Provider Enumeration

extension WasmClient {
    public func searchPhotoProviders() async throws -> [ActionInfo] {
        try await availableActions()
            .filter { $0.actionID == ActionID.searchPhotos.rawValue }
    }

    public func photoVisualSearchProviders() async throws -> [ActionInfo] {
        try await availableActions()
            .filter { $0.actionID == ActionID.photoVisualSearch.rawValue }
    }

    public func listMediaProviders() async throws -> [ActionInfo] {
        try await availableActions()
            .filter { $0.actionID == ActionID.listMedia.rawValue }
    }
}

// MARK: - First-Provider Conveniences

extension WasmClient {
    // These drop the `provider:` parameter that `@DependencyEndpoint` already
    // generates and route to the first available provider (empty string).
    public func searchPhotos(
        query: String,
        page: Int = 1,
        perPage: Int = 20
    ) async throws -> WasmClient.Visual.SearchResult {
        try await searchPhotos(query, "", page, perPage)
    }

    public func photoVisualSearch(
        imageURL: String,
        page: Int = 1,
        perPage: Int = 20
    ) async throws -> WasmClient.Visual.SearchResult {
        try await photoVisualSearch(imageURL, "", page, perPage)
    }

    public func listMedia(
        query: String = "",
        page: Int = 1,
        perPage: Int = 20
    ) async throws -> WasmClient.Visual.SearchResult {
        try await listMedia(query, "", page, perPage)
    }
}
