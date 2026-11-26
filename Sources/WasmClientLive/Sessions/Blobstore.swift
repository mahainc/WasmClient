@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Blobstore

extension WasmActor {

    func uploadImage(imageData: Data) async throws -> String {
        let filename = "\(UUID().uuidString).jpg"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try imageData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        return try await upload(fileURI: tempURL.absoluteString, filename: filename)
    }

    func uploadFile(
        filePath: String,
        filename: String
    ) async throws -> String {
        try await upload(fileURI: filePath, filename: filename)
    }

    // MARK: - Upload Helper

    /// Resolves the shared `upload` action and returns the non-empty result URL,
    /// or throws. Both entry points differ only in how they source `fileURI`.
    private func upload(
        fileURI: String,
        filename: String
    ) async throws -> String {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(actionID: WasmClient.ActionID.upload.rawValue, logger: logger)
        let args: [String: Google_Protobuf_Value] = [
            "file": Google_Protobuf_Value(stringValue: fileURI),
            "filename": Google_Protobuf_Value(stringValue: filename),
        ]
        let task = try await instance.create(action: action, args: args)
        guard task.status == .completed, task.hasValue else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
        let result = try BlobstoreUploadResult(unpackingAny: task.value)
        guard !result.url.isEmpty else {
            throw WasmClient.Error.uploadFailed("Empty URL returned")
        }
        return result.url
    }
}
