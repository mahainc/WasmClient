@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Music

extension WasmActor {

    /// Discover music tracks by category.
    func musicDiscover(category: String, continuation: String?) async throws -> WasmClient.MusicTrackList {
        var args: [String: Google_Protobuf_Value] = [
            "category": Google_Protobuf_Value(stringValue: category),
        ]
        if let continuation, !continuation.isEmpty {
            args["continuation"] = Google_Protobuf_Value(stringValue: continuation)
        }
        return try await runMusicList(actionID: .discover, args: args)
    }

    /// Get detailed info for a music track.
    func musicDetails(trackID: String) async throws -> WasmClient.MusicTrackDetail {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.details.rawValue, logger: logger
        )
        let args: [String: Google_Protobuf_Value] = [
            "id": Google_Protobuf_Value(stringValue: trackID),
        ]
        let result: MusicTrackDetails = try await instance.run(action: action, args: args)
        return mapTrackDetails(result)
    }

    /// List tracks.
    func musicTracks(listID: String, continuation: String?) async throws -> WasmClient.MusicTrackList {
        var args: [String: Google_Protobuf_Value] = [
            "id": Google_Protobuf_Value(stringValue: listID),
        ]
        if let continuation, !continuation.isEmpty {
            args["continuation"] = Google_Protobuf_Value(stringValue: continuation)
        }
        return try await runMusicList(actionID: .tracks, args: args)
    }

    /// Search music by query.
    func musicSearch(query: String, continuation: String?) async throws -> WasmClient.MusicTrackList {
        var args: [String: Google_Protobuf_Value] = [
            "query": Google_Protobuf_Value(stringValue: query),
        ]
        if let continuation, !continuation.isEmpty {
            args["continuation"] = Google_Protobuf_Value(stringValue: continuation)
        }
        return try await runMusicList(actionID: .search, args: args)
    }

    /// Get lyrics for a track.
    func musicLyrics(trackID: String) async throws -> [WasmClient.MusicLyricSegment] {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.lyrics.rawValue, logger: logger
        )
        let args: [String: Google_Protobuf_Value] = [
            "id": Google_Protobuf_Value(stringValue: trackID),
        ]
        let result: MusicTranscript = try await instance.run(action: action, args: args)
        return result.segments.map { seg in
            WasmClient.MusicLyricSegment(
                text: seg.text,
                offset: Int(seg.offset),
                duration: Int(seg.duration)
            )
        }
    }

    /// Get related tracks.
    func musicRelated(trackID: String, continuation: String?) async throws -> WasmClient.MusicTrackList {
        var args: [String: Google_Protobuf_Value] = [
            "id": Google_Protobuf_Value(stringValue: trackID),
        ]
        if let continuation, !continuation.isEmpty {
            args["continuation"] = Google_Protobuf_Value(stringValue: continuation)
        }
        return try await runMusicList(actionID: .related, args: args)
    }

    /// Get music search suggestions.
    func musicSuggestions(query: String) async throws -> [String] {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.musicSuggestion.rawValue, logger: logger
        )
        let args: [String: Google_Protobuf_Value] = [
            "query": Google_Protobuf_Value(stringValue: query),
        ]
        let result: MusicListSuggestions = try await instance.run(action: action, args: args)
        return result.suggestions
    }

    // MARK: - Music Helpers

    private func runMusicList(
        actionID: WasmClient.ActionID,
        args: [String: Google_Protobuf_Value]
    ) async throws -> WasmClient.MusicTrackList {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(actionID: actionID.rawValue, logger: logger)
        let result: MusicListTracks = try await instance.run(action: action, args: args)
        return mapTrackList(result)
    }

    // MARK: - Music Mapping

    private func mapTrackList(_ proto: MusicListTracks) -> WasmClient.MusicTrackList {
        WasmClient.MusicTrackList(
            items: proto.items.map(mapTrackItem),
            continuation: proto.hasContinuation ? proto.continuation : ""
        )
    }

    private func mapTrackItem(_ proto: MusicTrack) -> WasmClient.MusicTrackItem {
        WasmClient.MusicTrackItem(
            id: proto.id,
            title: proto.title,
            kind: proto.kind,
            authorName: proto.hasAuthor ? proto.author.name : "",
            thumbnail: proto.hasThumbnail ? proto.thumbnail : ""
        )
    }

    private func mapTrackDetails(_ proto: MusicTrackDetails) -> WasmClient.MusicTrackDetail {
        WasmClient.MusicTrackDetail(
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
                WasmClient.MusicFormat(
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
