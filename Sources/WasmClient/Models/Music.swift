import Foundation

// MARK: - Music

extension WasmClient {
    public enum Music {}
}

extension WasmClient.Music {

    public struct TrackDetail: Sendable, Equatable, Identifiable {
        public let id: String
        public let title: String
        public let description: String
        public let authorName: String
        public let authorThumbnail: String
        public let thumbnail: String
        public let duration: Double
        public let views: Int
        public let dashManifestURL: String
        public let hlsManifestURL: String
        public let formats: [Format]
        public let relatedTracks: [TrackItem]

        public init(
            id: String = "",
            title: String = "",
            description: String = "",
            authorName: String = "",
            authorThumbnail: String = "",
            thumbnail: String = "",
            duration: Double = 0,
            views: Int = 0,
            dashManifestURL: String = "",
            hlsManifestURL: String = "",
            formats: [Format] = [],
            relatedTracks: [TrackItem] = []
        ) {
            self.id = id
            self.title = title
            self.description = description
            self.authorName = authorName
            self.authorThumbnail = authorThumbnail
            self.thumbnail = thumbnail
            self.duration = duration
            self.views = views
            self.dashManifestURL = dashManifestURL
            self.hlsManifestURL = hlsManifestURL
            self.formats = formats
            self.relatedTracks = relatedTracks
        }
    }

    public struct Format: Sendable, Equatable, Identifiable {
        public let id: String
        public let url: String
        public let quality: String
        public let mimeType: String

        public init(
            id: String = "",
            url: String = "",
            quality: String = "",
            mimeType: String = ""
        ) {
            self.id = id
            self.url = url
            self.quality = quality
            self.mimeType = mimeType
        }
    }

    public struct TrackItem: Sendable, Equatable, Identifiable {
        public let id: String
        public let title: String
        public let kind: String
        public let authorName: String
        public let thumbnail: String

        public init(
            id: String = "",
            title: String = "",
            kind: String = "",
            authorName: String = "",
            thumbnail: String = ""
        ) {
            self.id = id
            self.title = title
            self.kind = kind
            self.authorName = authorName
            self.thumbnail = thumbnail
        }
    }

    public struct TrackList: Sendable, Equatable {
        public let items: [TrackItem]
        public let continuation: String

        public init(
            items: [TrackItem] = [],
            continuation: String = ""
        ) {
            self.items = items
            self.continuation = continuation
        }
    }

    public struct LyricSegment: Sendable, Equatable {
        public let text: String
        public let offset: Int
        public let duration: Int

        public init(
            text: String = "",
            offset: Int = 0,
            duration: Int = 0
        ) {
            self.text = text
            self.offset = offset
            self.duration = duration
        }
    }
}
