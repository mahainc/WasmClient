@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Visual / Media

extension WasmActor {

    /// Search photos by text query.
    func searchPhotos(
        query: String,
        provider: String,
        page: Int,
        perPage: Int
    ) async throws -> WasmClient.PhotoSearchResult {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.searchPhotos.rawValue,
            preferredProvider: provider.isEmpty ? nil : provider,
            logger: logger
        )
        await instance.ensureBrowserCookies(for: action)
        var args: [String: Google_Protobuf_Value] = [
            "query": Google_Protobuf_Value(stringValue: query),
        ]
        if page > 1 {
            args["page"] = Google_Protobuf_Value(numberValue: Double(page))
        }
        if perPage != 20 {
            args["per_page"] = Google_Protobuf_Value(numberValue: Double(perPage))
        }
        return try await runVisualSearch(instance: instance, action: action, args: args)
    }

    /// Visual search: find similar photos given an image URL.
    func photoVisualSearch(
        imageURL: String,
        provider: String,
        page: Int,
        perPage: Int
    ) async throws -> WasmClient.PhotoSearchResult {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.photoVisualSearch.rawValue,
            preferredProvider: provider.isEmpty ? nil : provider,
            logger: logger
        )
        await instance.ensureBrowserCookies(for: action)
        var args: [String: Google_Protobuf_Value] = [
            "file": Google_Protobuf_Value(stringValue: imageURL),
        ]
        if page > 1 {
            args["page"] = Google_Protobuf_Value(numberValue: Double(page))
        }
        if perPage != 20 {
            args["per_page"] = Google_Protobuf_Value(numberValue: Double(perPage))
        }
        return try await runVisualSearch(instance: instance, action: action, args: args)
    }

    /// List media (editorial/trending). Pass empty query for editorial content.
    func listMedia(
        query: String,
        provider: String,
        page: Int,
        perPage: Int
    ) async throws -> WasmClient.PhotoSearchResult {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.listMedia.rawValue,
            preferredProvider: provider.isEmpty ? nil : provider,
            logger: logger
        )
        var args: [String: Google_Protobuf_Value] = [:]
        if !query.isEmpty {
            args["query"] = Google_Protobuf_Value(stringValue: query)
        }
        if page > 1 {
            args["page"] = Google_Protobuf_Value(numberValue: Double(page))
        }
        if perPage != 20 {
            args["per_page"] = Google_Protobuf_Value(numberValue: Double(perPage))
        }
        return try await runVisualSearch(instance: instance, action: action, args: args)
    }

    // MARK: - Visual Helpers

    private func runVisualSearch(
        instance: TaskWasmProtocol,
        action: WaTAction,
        args: [String: Google_Protobuf_Value]
    ) async throws -> WasmClient.PhotoSearchResult {
        let task = try await instance.create(action: action, args: args)
        guard task.status == .completed else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
        guard task.hasValue else {
            throw WasmClient.Error.missingValue
        }
        let result = try VisualPhotoSearchResult(unpackingAny: task.value)
        return mapPhotoSearchResult(result)
    }

    // MARK: - Visual Mapping

    private func mapPhotoSearchResult(_ proto: VisualPhotoSearchResult) -> WasmClient.PhotoSearchResult {
        WasmClient.PhotoSearchResult(
            total: Int(proto.total),
            totalPages: Int(proto.totalPages),
            results: proto.results.map(mapPhoto)
        )
    }

    private func mapPhoto(_ proto: VisualPhoto) -> WasmClient.Photo {
        WasmClient.Photo(
            id: proto.id,
            description: proto.description_p,
            altDescription: proto.altDescription,
            width: Int(proto.width),
            height: Int(proto.height),
            color: proto.color,
            blurHash: proto.blurHash,
            urls: proto.hasUrls ? mapPhotoUrls(proto.urls) : WasmClient.PhotoUrls(),
            userName: proto.hasUser ? proto.user.name : "",
            userProfileImage: proto.hasUser ? (proto.user.profileImage) : "",
            linkHTML: proto.hasLinks ? (proto.links.html) : "",
            linkDownload: proto.hasLinks ? (proto.links.download) : "",
            likes: Int(proto.likes)
        )
    }

    private func mapPhotoUrls(_ proto: VisualPhotoUrls) -> WasmClient.PhotoUrls {
        WasmClient.PhotoUrls(
            raw: proto.raw,
            full: proto.full,
            regular: proto.regular,
            small: proto.small,
            thumb: proto.thumb
        )
    }
}
