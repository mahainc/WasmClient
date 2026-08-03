@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Visual / Media

extension WasmActor {

    func searchPhotos(
        query: String,
        provider: String,
        page: Int,
        perPage: Int
    ) async throws -> WasmClient.Visual.SearchResult {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.searchPhotos.rawValue,
            preferredProvider: provider.isEmpty ? nil : provider,
            logger: logger
        )
        await instance.ensureBrowserCookies(for: action)
        var args: [String: Google_Protobuf_Value] = [
            "query": Google_Protobuf_Value(stringValue: query)
        ]
        if page > 1 {
            args["page"] = Google_Protobuf_Value(numberValue: Double(page))
        }
        if perPage != 20 {
            args["per_page"] = Google_Protobuf_Value(numberValue: Double(perPage))
        }
        return try await runVisualSearch(instance: instance, action: action, args: args)
    }

    func photoVisualSearch(
        imageURL: String,
        provider: String,
        page: Int,
        perPage: Int
    ) async throws -> WasmClient.Visual.SearchResult {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.photoVisualSearch.rawValue,
            preferredProvider: provider.isEmpty ? nil : provider,
            logger: logger
        )
        await instance.ensureBrowserCookies(for: action)
        var args: [String: Google_Protobuf_Value] = [
            "file": Google_Protobuf_Value(stringValue: imageURL)
        ]
        if page > 1 {
            args["page"] = Google_Protobuf_Value(numberValue: Double(page))
        }
        if perPage != 20 {
            args["per_page"] = Google_Protobuf_Value(numberValue: Double(perPage))
        }
        return try await runVisualSearch(instance: instance, action: action, args: args)
    }

    func listMedia(
        query: String,
        provider: String,
        page: Int,
        perPage: Int
    ) async throws -> WasmClient.Visual.SearchResult {
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
    ) async throws -> WasmClient.Visual.SearchResult {
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

    private func mapPhotoSearchResult(_ proto: VisualPhotoSearchResult) -> WasmClient.Visual.SearchResult {
        WasmClient.Visual.SearchResult(
            total: Int(proto.total),
            totalPages: Int(proto.totalPages),
            results: proto.results.map(mapPhoto)
        )
    }

    private func mapPhoto(_ proto: VisualPhoto) -> WasmClient.Visual.Photo {
        WasmClient.Visual.Photo(
            id: proto.id,
            description: proto.description_p,
            altDescription: proto.altDescription,
            width: Int(proto.width),
            height: Int(proto.height),
            color: proto.color,
            blurHash: proto.blurHash,
            urls: proto.hasUrls ? mapPhotoUrls(proto.urls) : WasmClient.Visual.URLs(),
            userName: proto.hasUser ? proto.user.name : "",
            userProfileImage: proto.hasUser ? (proto.user.profileImage) : "",
            linkHTML: proto.hasLinks ? (proto.links.html) : "",
            linkDownload: proto.hasLinks ? (proto.links.download) : "",
            likes: Int(proto.likes)
        )
    }

    private func mapPhotoUrls(_ proto: VisualPhotoUrls) -> WasmClient.Visual.URLs {
        WasmClient.Visual.URLs(
            raw: proto.raw,
            full: proto.full,
            regular: proto.regular,
            small: proto.small,
            thumb: proto.thumb
        )
    }
}
