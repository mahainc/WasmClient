@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Music

extension WasmActor {

    func musicDiscover(
        category: String,
        continuation: String?
    ) async throws -> WasmClient.Music.TrackList {
        var args: [String: Google_Protobuf_Value] = [
            "category": Google_Protobuf_Value(stringValue: category)
        ]
        if let continuation, !continuation.isEmpty {
            args["continuation"] = Google_Protobuf_Value(stringValue: continuation)
        }
        return try await runMusicList(actionID: .discover, args: args)
    }

    func musicDetails(trackID: String) async throws -> WasmClient.Music.TrackDetail {
        let result: MusicTrackDetails = try await runMusic(
            actionID: .details,
            args: ["id": Google_Protobuf_Value(stringValue: trackID)]
        )
        return mapTrackDetails(result)
    }

    func musicTracks(
        listID: String,
        continuation: String?
    ) async throws -> WasmClient.Music.TrackList {
        var args: [String: Google_Protobuf_Value] = [
            "id": Google_Protobuf_Value(stringValue: listID)
        ]
        if let continuation, !continuation.isEmpty {
            args["continuation"] = Google_Protobuf_Value(stringValue: continuation)
        }
        return try await runMusicList(actionID: .tracks, args: args)
    }

    func musicSearch(
        query: String,
        continuation: String?
    ) async throws -> WasmClient.Music.TrackList {
        var args: [String: Google_Protobuf_Value] = [
            "query": Google_Protobuf_Value(stringValue: query)
        ]
        if let continuation, !continuation.isEmpty {
            args["continuation"] = Google_Protobuf_Value(stringValue: continuation)
        }
        return try await runMusicList(actionID: .search, args: args)
    }

    func musicLyrics(trackID: String) async throws -> [WasmClient.Music.LyricSegment] {
        let result: MusicTranscript = try await runMusic(
            actionID: .lyrics,
            args: ["id": Google_Protobuf_Value(stringValue: trackID)]
        )
        return result.segments.map { seg in
            WasmClient.Music.LyricSegment(
                text: seg.text,
                offset: Int(seg.offset),
                duration: Int(seg.duration)
            )
        }
    }

    func musicRelated(
        trackID: String,
        continuation: String?
    ) async throws -> WasmClient.Music.TrackList {
        var args: [String: Google_Protobuf_Value] = [
            "id": Google_Protobuf_Value(stringValue: trackID)
        ]
        if let continuation, !continuation.isEmpty {
            args["continuation"] = Google_Protobuf_Value(stringValue: continuation)
        }
        return try await runMusicList(actionID: .related, args: args)
    }

    func musicSuggestions(query: String) async throws -> [String] {
        let result: MusicListSuggestions = try await runMusic(
            actionID: .musicSuggestion,
            args: ["query": Google_Protobuf_Value(stringValue: query)]
        )
        return result.suggestions
    }

    // MARK: - Music Helpers

    /// Resolves `actionID` and runs it, decoding the response into `T`. Mirrors
    /// `runInpaint` — the shared submit path for every one-shot music action.
    private func runMusic<T: SwiftProtobuf.Message>(
        actionID: WasmClient.ActionID,
        args: [String: Google_Protobuf_Value]
    ) async throws -> T {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(actionID: actionID.rawValue, logger: logger)
        return try await instance.run(action: action, args: args)
    }

    private func runMusicList(
        actionID: WasmClient.ActionID,
        args: [String: Google_Protobuf_Value]
    ) async throws -> WasmClient.Music.TrackList {
        let result: MusicListTracks = try await runMusic(actionID: actionID, args: args)
        return mapTrackList(result)
    }

    // MARK: - Music Mapping

    private func mapTrackList(_ proto: MusicListTracks) -> WasmClient.Music.TrackList {
        WasmClient.Music.TrackList(
            items: proto.items.map(mapTrackItem),
            continuation: proto.hasContinuation ? proto.continuation : ""
        )
    }

    private func mapTrackItem(_ proto: MusicTrack) -> WasmClient.Music.TrackItem {
        WasmClient.Music.TrackItem(
            id: proto.id,
            title: proto.title,
            kind: proto.kind,
            authorName: proto.hasAuthor ? proto.author.name : "",
            thumbnail: proto.hasThumbnail ? proto.thumbnail : ""
        )
    }

    private func mapTrackDetails(_ proto: MusicTrackDetails) -> WasmClient.Music.TrackDetail {
        WasmClient.Music.TrackDetail(
            id: proto.id,
            title: proto.title,
            description: proto.description_p,
            authorName: proto.hasAuthor ? proto.author.name : "",
            authorThumbnail: proto.hasAuthor && proto.author.hasThumbnail ? proto.author.thumbnail : "",
            thumbnail: proto.hasThumbnail ? proto.thumbnail : "",
            duration: proto.duration,
            views: Int(proto.views),
            dashManifestURL: proto.hasDashManifestURL ? proto.dashManifestURL : "",
            hlsManifestURL: proto.hasHlsManifestURL ? proto.hlsManifestURL : "",
            formats: proto.formats.map { fmt in
                WasmClient.Music.Format(
                    id: fmt.id,
                    url: fmt.url,
                    quality: fmt.hasQuality ? fmt.quality : "",
                    mimeType: fmt.hasMimeType ? fmt.mimeType : ""
                )
            },
            relatedTracks: proto.relatedTracks.map(mapTrackItem)
        )
    }
}
