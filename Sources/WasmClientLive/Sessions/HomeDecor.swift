@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Home Decor

extension WasmActor {

    func homeDesignRequest(
        _ request: WasmClient.HomeDecor.Request,
        onProgress: (@Sendable (Double) async -> Void)?
    ) async throws -> WasmClient.HomeDecor.Result {
        guard let actionID = request.processType.actionID else {
            throw WasmClient.Error.noProviderFound(action: "homedecor.unspecified")
        }
        let instance = try await readyEngine()
        let action = try await delegate.resolveNextAction(actionID: actionID.rawValue, logger: logger)

        var protoArgs: [String: Google_Protobuf_Value] = [:]
        for (key, value) in request.toWireArgs() where !value.isEmpty {
            protoArgs[key] = Google_Protobuf_Value(stringValue: value)
        }

        return try await runHomedecor(
            instance: instance,
            action: action,
            protoArgs: protoArgs,
            onProgress: onProgress
        )
    }

    func homeDesign(
        actionID: String,
        args: [String: String]
    ) async throws -> WasmClient.HomeDecor.Result {
        let instance = try await readyEngine()
        let action = try await delegate.resolveNextAction(actionID: actionID, logger: logger)

        var protoArgs: [String: Google_Protobuf_Value] = [:]
        for (key, value) in args where !value.isEmpty {
            protoArgs[key] = Google_Protobuf_Value(stringValue: value)
        }

        return try await runHomedecor(
            instance: instance,
            action: action,
            protoArgs: protoArgs,
            onProgress: nil
        )
    }

    func homeDesignStatus(
        taskID: String,
        actionID: String
    ) async throws -> WasmClient.HomeDecor.Result {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(actionID: actionID, logger: logger)
        guard let engine = instance as? TaskWasmEngine else {
            throw WasmClient.Error.engineNotReady
        }
        var taskRef = WaTTask()
        taskRef.id = taskID
        taskRef.provider = action.provider
        let updated = try await engine.status(task: taskRef)
        return mapHomedecorResult(task: updated, provider: action.provider)
    }

    // MARK: - Schema Helpers

    func homeDecorStyles(
        processType: WasmClient.HomeDecor.ProcessType
    ) async throws -> [WasmClient.HomeDecor.RoomStyle] {
        try await enumArg(
            processType: processType,
            argKey: "room_style",
            decode: WasmClient.HomeDecor.RoomStyle.init(wireName:)
        )
    }

    func homeDecorRoomTypes(
        processType: WasmClient.HomeDecor.ProcessType
    ) async throws -> [WasmClient.HomeDecor.RoomType] {
        try await enumArg(
            processType: processType,
            argKey: "room_type",
            decode: WasmClient.HomeDecor.RoomType.init(wireName:)
        )
    }

    func homeDecorColorPalettes(
        processType: WasmClient.HomeDecor.ProcessType
    ) async throws -> [WasmClient.HomeDecor.ColorPalette] {
        try await enumArg(
            processType: processType,
            argKey: "color",
            decode: WasmClient.HomeDecor.ColorPalette.init(wireName:)
        )
    }

    func homeDecorSurfaceTypes(
        processType: WasmClient.HomeDecor.ProcessType
    ) async throws -> [WasmClient.HomeDecor.SurfaceType] {
        try await enumArg(
            processType: processType,
            argKey: "surface_type",
            decode: WasmClient.HomeDecor.SurfaceType.init(wireName:)
        )
    }

    func homeDecorStyleSelections(
        processType: WasmClient.HomeDecor.ProcessType
    ) async throws -> [WasmClient.HomeDecor.StyleSelection] {
        try await enumArg(
            processType: processType,
            argKey: "style_selection",
            decode: WasmClient.HomeDecor.StyleSelection.init(wireName:)
        )
    }

    private func enumArg<T>(
        processType: WasmClient.HomeDecor.ProcessType,
        argKey: String,
        decode: (String) -> T
    ) async throws -> [T] {
        guard let actionID = processType.actionID else { return [] }
        _ = try await readyEngine()
        let action = try await delegate.resolveAction(actionID: actionID.rawValue, logger: logger)

        guard let arg = action.args[argKey] else {
            logger("homedecor schema: no '\(argKey)' arg on action \(actionID.rawValue)")
            return []
        }
        guard arg.hasValidator else { return [] }
        guard case .string(let stringValidator) = arg.validator.data else { return [] }
        guard stringValidator.hasRegex else { return [] }

        let parsed = Self.parseRegexAlternatives(stringValidator.regex) ?? []
        return parsed.map(decode)
    }

    // MARK: - Shared Submit + Poll

    private func runHomedecor(
        instance: TaskWasmProtocol,
        action: WaTAction,
        protoArgs: [String: Google_Protobuf_Value],
        onProgress: (@Sendable (Double) async -> Void)?
    ) async throws -> WasmClient.HomeDecor.Result {
        var task = try await instance.create(action: action, args: protoArgs)

        // Initial progress tick (if engine sent one in the create response).
        var lastProgress = Self.extractProgress(task)
        if let progress = lastProgress, let onProgress {
            await onProgress(progress)
        }

        if task.status == .processing {
            guard let engine = instance as? TaskWasmEngine else {
                throw WasmClient.Error.engineNotReady
            }
            let deadline = Date().addingTimeInterval(120)
            while task.status == .processing, Date() < deadline {
                try await Task.sleep(nanoseconds: 3_000_000_000)
                task = try await engine.status(task: task)
                logger("homedecor poll: status=\(task.status) id=\(task.id)")
                if let progress = Self.extractProgress(task), progress != lastProgress {
                    lastProgress = progress
                    if let onProgress { await onProgress(progress) }
                }
            }
        }

        return mapHomedecorResult(task: task, provider: action.provider)
    }

    // MARK: - Homedecor Mapping

    private func mapHomedecorResult(
        task: WaTTask,
        provider: String
    ) -> WasmClient.HomeDecor.Result {
        let status: WasmClient.TaskStatus
        var imageURL = ""
        var inputImageURL = ""
        var processType: WasmClient.HomeDecor.ProcessType?
        var roomStyle: WasmClient.HomeDecor.RoomStyle?
        var roomType: WasmClient.HomeDecor.RoomType?
        var metadata: [String: String] = [:]

        switch task.status {
            case .completed:
                status = .completed
                if task.hasValue {
                    let proto: HomedecorGenerateResult? =
                        (try? HomedecorGenerateResult(unpackingAny: task.value))
                        ?? (try? HomedecorGenerateResult(serializedBytes: task.value.value))
                    if let res = proto {
                        if res.hasResult { imageURL = res.result.url }
                        if res.hasInput { inputImageURL = res.input.url }
                        processType = Self.mapProcessType(res.processType)
                        roomStyle = Self.mapRoomStyle(res.roomStyle)
                        roomType = Self.mapRoomType(res.roomType)
                    }
                }
            case .processing:
                status = .processing
            default:
                let errorMsg = task.metadata.fields["error"]?.stringValue ?? "\(task.status)"
                status = .failed(errorMsg)
        }

        for (key, value) in task.metadata.fields {
            if case .stringValue(let string) = value.kind {
                metadata[key] = string
            } else if case .numberValue(let number) = value.kind {
                metadata[key] = String(number)
            }
        }

        let progress = Self.extractProgress(task) ?? (status == .completed ? 1.0 : 0.0)

        return WasmClient.HomeDecor.Result(
            status: status,
            imageURL: imageURL,
            inputImageURL: inputImageURL,
            taskID: task.id,
            metadata: metadata,
            processType: processType,
            roomStyle: roomStyle,
            roomType: roomType,
            progress: progress,
            provider: provider
        )
    }

    private static func extractProgress(_ task: WaTTask) -> Double? {
        guard let field = task.metadata.fields["progress"] else { return nil }
        switch field.kind {
            case .numberValue(let double): return double
            case .stringValue(let string): return Double(string)
            default: return nil
        }
    }

    // MARK: - Proto → SDK Mapping

    private static func mapProcessType(_ proto: HomedecorProcessType) -> WasmClient.HomeDecor.ProcessType? {
        processTypesByProtoRawValue[proto.rawValue]
    }

    private static func mapRoomType(_ proto: HomedecorRoomType) -> WasmClient.HomeDecor.RoomType? {
        roomTypesByProtoRawValue[proto.rawValue]
    }

    private static func mapRoomStyle(_ proto: HomedecorRoomStyle) -> WasmClient.HomeDecor.RoomStyle? {
        roomStylesByProtoRawValue[proto.rawValue]
    }

    private static let processTypesByProtoRawValue: [Int: WasmClient.HomeDecor.ProcessType] = [
        1: .interior,
        2: .exterior,
        3: .garden,
        4: .paint,
        5: .replace,
        6: .floor,
        7: .reference,
        8: .staging,
        9: .declutter,
        10: .floorPlan,
        11: .planToImage,
    ]

    private static let roomTypesByProtoRawValue: [Int: WasmClient.HomeDecor.RoomType] = [
        1: .livingRoom,
        2: .bedroom,
        3: .kitchen,
        4: .diningRoom,
        5: .bathroom,
        6: .office,
        7: .homeOffice,
        8: .studyRoom,
        9: .attic,
        10: .coffeeShop,
        11: .gamingRoom,
        12: .restaurant,
        13: .toilet,
        14: .balcony,
        15: .hall,
        16: .gardenRoom,
        17: .deck,
        18: .apartment,
        19: .residential,
        20: .house,
        21: .retail,
        22: .villa,
        23: .underStairSpace,
        24: .officeBuilding,
        25: .entryway,
        26: .laundryRoom,
        27: .tower,
        28: .ranch,
        29: .swimmingPool,
        30: .yard,
        31: .otherRoom,
    ]

    private static let roomStylesByProtoRawValue: [Int: WasmClient.HomeDecor.RoomStyle] = [
        1: .modern,
        2: .tropical,
        3: .minimalist,
        4: .bohemian,
        5: .rustic,
        6: .vintage,
        7: .baroque,
        8: .mediterranean,
        9: .cyberpunk,
        10: .biophilic,
        11: .ancientEgyptian,
        12: .airbnb,
        13: .discotheque,
        14: .soho,
        15: .rainbow,
        16: .luxury,
        17: .techno,
        18: .gamer,
        19: .cozy,
        20: .coastal,
        21: .japandi,
        22: .cottagecore,
        23: .skiChalet,
        24: .gothic,
        25: .creepy,
        26: .medieval,
        27: .eighties,
        28: .cartoon,
        29: .wood,
        30: .chocolate,
        31: .italianate,
        32: .brutalist,
        33: .artDeco,
        34: .chinese,
        35: .japanese,
        36: .cottage,
        37: .spanish,
        38: .morocco,
        39: .midcentury,
        40: .middleEastern,
        41: .farmhouse,
        42: .french,
        43: .christmas,
        44: .industrial,
        45: .scandinavian,
        46: .noStyle,
        47: .zen,
        48: .halloween,
        49: .concrete,
        50: .retro,
        51: .beachHouse,
        52: .isle,
        53: .stValentinesDay,
    ]
}
