import Foundation

// MARK: - Music

extension WasmClient {

    /// A music track with details, streaming URLs, and related tracks.
    public struct MusicTrackDetail: Sendable, Equatable, Identifiable {
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
        public let formats: [MusicFormat]
        public let relatedTracks: [MusicTrackItem]

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
            formats: [MusicFormat] = [],
            relatedTracks: [MusicTrackItem] = []
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

    /// A streaming format for a music track.
    public struct MusicFormat: Sendable, Equatable, Identifiable {
        public let id: String
        public let url: String
        public let quality: String
        public let mimeType: String

        public init(id: String = "", url: String = "", quality: String = "", mimeType: String = "") {
            self.id = id
            self.url = url
            self.quality = quality
            self.mimeType = mimeType
        }
    }

    /// A music track item (used in lists and search results).
    public struct MusicTrackItem: Sendable, Equatable, Identifiable {
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

    /// A paginated list of music tracks.
    public struct MusicTrackList: Sendable, Equatable {
        public let items: [MusicTrackItem]
        public let continuation: String

        public init(items: [MusicTrackItem] = [], continuation: String = "") {
            self.items = items
            self.continuation = continuation
        }
    }

    /// A lyric transcript segment.
    public struct MusicLyricSegment: Sendable, Equatable {
        public let text: String
        public let offset: Int
        public let duration: Int

        public init(text: String = "", offset: Int = 0, duration: Int = 0) {
            self.text = text
            self.offset = offset
            self.duration = duration
        }
    }
}
