@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Home Decor

extension WasmActor {

    /// Generate a home decor design from a typed `HomeDecor.Request`. Resolves
    /// the `ActionID` from `request.processType`, builds wire args via
    /// `HomeDecor.Request.toWireArgs()`, polls until terminal, and returns the
    /// enriched result. `onProgress` is invoked when the engine reports a new
    /// progress fraction in `task.metadata.fields["progress"]`.
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

    /// Generate a home decor design. Polls automatically if the task returns `.processing`,
    /// matching flow-kit-example's pattern of passing the original task to `status()`.
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

    /// Poll a home decor task by ID. Pass the same actionID used for `homeDesign`.
    func homeDesignStatus(taskID: String, actionID: String) async throws -> WasmClient.HomeDecor.Result {
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

    func homeDecorStyles(processType: WasmClient.HomeDecor.ProcessType) async throws -> [WasmClient.HomeDecor.RoomStyle] {
        try await enumArg(processType: processType, argKey: "room_style", decode: WasmClient.HomeDecor.RoomStyle.init(wireName:))
    }

    func homeDecorRoomTypes(processType: WasmClient.HomeDecor.ProcessType) async throws -> [WasmClient.HomeDecor.RoomType] {
        try await enumArg(processType: processType, argKey: "room_type", decode: WasmClient.HomeDecor.RoomType.init(wireName:))
    }

    func homeDecorColorPalettes(processType: WasmClient.HomeDecor.ProcessType) async throws -> [WasmClient.HomeDecor.ColorPalette] {
        try await enumArg(processType: processType, argKey: "color", decode: WasmClient.HomeDecor.ColorPalette.init(wireName:))
    }

    func homeDecorSurfaceTypes(processType: WasmClient.HomeDecor.ProcessType) async throws -> [WasmClient.HomeDecor.SurfaceType] {
        try await enumArg(processType: processType, argKey: "surface_type", decode: WasmClient.HomeDecor.SurfaceType.init(wireName:))
    }

    func homeDecorStyleSelections(processType: WasmClient.HomeDecor.ProcessType) async throws -> [WasmClient.HomeDecor.StyleSelection] {
        try await enumArg(processType: processType, argKey: "style_selection", decode: WasmClient.HomeDecor.StyleSelection.init(wireName:))
    }

    private func enumArg<T>(
        processType: WasmClient.HomeDecor.ProcessType,
        argKey: String,
        decode: (String) -> T?
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
        return parsed.compactMap(decode)
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
        if let p = lastProgress, let onProgress {
            await onProgress(p)
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
                if let p = Self.extractProgress(task), p != lastProgress {
                    lastProgress = p
                    if let onProgress { await onProgress(p) }
                }
            }
        }

        return mapHomedecorResult(task: task, provider: action.provider)
    }

    // MARK: - Homedecor Mapping

    private func mapHomedecorResult(task: WaTTask, provider: String) -> WasmClient.HomeDecor.Result {
        let status: WasmClient.TaskStatus
        var imageURL = ""
        var inputImageURL = ""
        var processType: WasmClient.HomeDecor.ProcessType? = nil
        var roomStyle: WasmClient.HomeDecor.RoomStyle? = nil
        var roomType: WasmClient.HomeDecor.RoomType? = nil
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
            if case .stringValue(let s) = value.kind {
                metadata[key] = s
            } else if case .numberValue(let n) = value.kind {
                metadata[key] = String(n)
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
        case .numberValue(let d): return d
        case .stringValue(let s): return Double(s)
        default: return nil
        }
    }

    // MARK: - Proto → SDK Enum Mapping

    private static func mapProcessType(_ proto: HomedecorProcessType) -> WasmClient.HomeDecor.ProcessType? {
        switch proto {
        case .unspecified: return nil
        case .interior: return .interior
        case .exterior: return .exterior
        case .garden: return .garden
        case .paint: return .paint
        case .replace: return .replace
        case .floor: return .floor
        case .reference: return .reference
        case .staging: return .staging
        case .declutter: return .declutter
        case .floorPlan: return .floorPlan
        case .planToImage: return .planToImage
        case .UNRECOGNIZED: return nil
        }
    }

    private static func mapRoomType(_ proto: HomedecorRoomType) -> WasmClient.HomeDecor.RoomType? {
        switch proto {
        case .unspecified: return nil
        case .livingRoom: return .livingRoom
        case .bedroom: return .bedroom
        case .kitchen: return .kitchen
        case .diningRoom: return .diningRoom
        case .bathroom: return .bathroom
        case .office: return .office
        case .homeOffice: return .homeOffice
        case .studyRoom: return .studyRoom
        case .attic: return .attic
        case .coffeeShop: return .coffeeShop
        case .gamingRoom: return .gamingRoom
        case .restaurant: return .restaurant
        case .toilet: return .toilet
        case .balcony: return .balcony
        case .hall: return .hall
        case .gardenRoom: return .gardenRoom
        case .deck: return .deck
        case .entryway: return .entryway
        case .laundryRoom: return .laundryRoom
        case .apartment: return .apartment
        case .residential: return .residential
        case .house: return .house
        case .retail: return .retail
        case .villa: return .villa
        case .underStairSpace: return .underStairSpace
        case .officeBuilding: return .officeBuilding
        case .tower: return .tower
        case .ranch: return .ranch
        case .swimmingPool: return .swimmingPool
        case .yard: return .yard
        case .otherRoom: return .otherRoom
        case .UNRECOGNIZED: return nil
        }
    }

    private static func mapRoomStyle(_ proto: HomedecorRoomStyle) -> WasmClient.HomeDecor.RoomStyle? {
        switch proto {
        case .unspecified: return nil
        case .modern: return .modern
        case .tropical: return .tropical
        case .minimalist: return .minimalist
        case .bohemian: return .bohemian
        case .rustic: return .rustic
        case .vintage: return .vintage
        case .baroque: return .baroque
        case .mediterranean: return .mediterranean
        case .cyberpunk: return .cyberpunk
        case .biophilic: return .biophilic
        case .ancientEgyptian: return .ancientEgyptian
        case .airbnb: return .airbnb
        case .discotheque: return .discotheque
        case .soho: return .soho
        case .rainbow: return .rainbow
        case .luxury: return .luxury
        case .techno: return .techno
        case .gamer: return .gamer
        case .cozy: return .cozy
        case .coastal: return .coastal
        case .japandi: return .japandi
        case .cottagecore: return .cottagecore
        case .skiChalet: return .skiChalet
        case .gothic: return .gothic
        case .creepy: return .creepy
        case .medieval: return .medieval
        case .eighties: return .eighties
        case .cartoon: return .cartoon
        case .wood: return .wood
        case .chocolate: return .chocolate
        case .italianate: return .italianate
        case .brutalist: return .brutalist
        case .artDeco: return .artDeco
        case .chinese: return .chinese
        case .japanese: return .japanese
        case .cottage: return .cottage
        case .spanish: return .spanish
        case .morocco: return .morocco
        case .midcentury: return .midcentury
        case .middleEastern: return .middleEastern
        case .farmhouse: return .farmhouse
        case .french: return .french
        case .christmas: return .christmas
        case .industrial: return .industrial
        case .scandinavian: return .scandinavian
        case .noStyle: return .noStyle
        case .zen: return .zen
        case .halloween: return .halloween
        case .concrete: return .concrete
        case .retro: return .retro
        case .beachHouse: return .beachHouse
        case .isle: return .isle
        case .stValentinesDay: return .stValentinesDay
        case .UNRECOGNIZED: return nil
        }
    }
}
