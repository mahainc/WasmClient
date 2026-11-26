@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Connect & Accounts

extension WasmActor {

    /// Fetch the provider's OAuth Connect configuration so the app can launch
    /// hosted Connect without hardcoding backend identity.
    func smartcarConnectConfig(
        mode: WasmClient.Smartcar.Connection.Mode
    ) async throws -> WasmClient.Smartcar.Connection.Config {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !mode.rawValue.isEmpty {
            args["mode"] = Google_Protobuf_Value(stringValue: mode.rawValue)
        }
        let response: SmartcarConnectConfigResponse = try await instance.run(
            method: WasmClient.Smartcar.Method.connectConfig.rawValue,
            args: args
        )
        return Self.mapConnectConfig(response)
    }

    /// Parse one hosted-Connect WebView observation; the guest caches the
    /// credential when it detects the provider's terminal token payload.
    func smartcarHostedConnectEvent(
        url: String,
        bodyText: String,
        vehicleID: String,
        contour: String
    ) async throws -> WasmClient.Smartcar.Connection.Decision {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !url.isEmpty {
            args["url"] = Google_Protobuf_Value(stringValue: url)
        }
        if !bodyText.isEmpty {
            args["body_text"] = Google_Protobuf_Value(stringValue: bodyText)
        }
        if !vehicleID.isEmpty {
            args["vehicle_id"] = Google_Protobuf_Value(stringValue: vehicleID)
        }
        if !contour.isEmpty {
            args["contour"] = Google_Protobuf_Value(stringValue: contour)
        }
        let response: SmartcarHostedConnectEventResponse = try await instance.run(
            method: WasmClient.Smartcar.Method.hostedConnectEvent.rawValue,
            args: args
        )
        return Self.mapHostedConnectDecision(response)
    }

    func smartcarAccounts() async throws -> [WasmClient.Smartcar.Account] {
        let instance = try await readyEngine()
        let response: SmartcarAccountList = try await instance.run(
            method: WasmClient.Smartcar.Method.accounts.rawValue,
            args: [:]
        )
        return Self.mapAccountList(response)
    }

    func smartcarSwitchAccount(
        userID: String
    ) async throws -> [WasmClient.Smartcar.Account] {
        try await smartcarAccountMutation(userID: userID, method: .switchAccount)
    }

    func smartcarDeleteAccount(
        userID: String
    ) async throws -> [WasmClient.Smartcar.Account] {
        try await smartcarAccountMutation(userID: userID, method: .deleteAccount)
    }

    private func smartcarAccountMutation(
        userID: String,
        method: WasmClient.Smartcar.Method
    ) async throws -> [WasmClient.Smartcar.Account] {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !userID.isEmpty {
            args["user_id"] = Google_Protobuf_Value(stringValue: userID)
        }
        let response: SmartcarAccountList = try await instance.run(method: method.rawValue, args: args)
        return Self.mapAccountList(response)
    }

    /// Fetch the bundled showroom catalog (makes/models + marketing imagery) so
    /// the app can present a make/model picker without a network call.
    func smartcarCatalog() async throws -> WasmClient.Smartcar.Catalog {
        let instance = try await readyEngine()
        let response: SmartcarCarCatalog = try await instance.run(
            method: WasmClient.Smartcar.Method.getCarCatalog.rawValue,
            args: [:]
        )
        return Self.mapCatalog(response)
    }

    func smartcarAllVehicles(
        vehicleID: String,
        make: String
    ) async throws -> [WasmClient.Smartcar.Vehicle] {
        let instance = try await readyEngine()
        let response: SmartcarVehicleList = try await instance.run(
            method: WasmClient.Smartcar.Method.allVehicles.rawValue,
            args: Self.vehicleArgs(vehicleID: vehicleID, make: make)
        )
        return response.vehicles.map(Self.mapVehicle)
    }
}

// MARK: - Typed Reads (permission gate source)

extension WasmActor {

    func smartcarGetPermissions(
        vehicleID: String,
        make: String
    ) async throws -> [WasmClient.Smartcar.Permission] {
        let response: SmartcarPermissions = try await runVehicleRead(.getPermissions, vehicleID: vehicleID, make: make)
        return response.permissions.map(WasmClient.Smartcar.Permission.init(rawValue:))
    }
}

// MARK: - Generic Reads & Controls

extension WasmActor {

    /// Any vehicle-scoped GET method → a lossless value map. Decodes into the
    /// method's concrete proto (the proven `run` path) and reflects it to
    /// `[String: Value]`, so nested arrays/objects survive and keys are the
    /// proto's deterministic camelCase json names. An unmapped method falls back
    /// to a best-effort `Struct` decode, so a brand-new read still returns data.
    func smartcarRead(
        method: WasmClient.Smartcar.Method,
        vehicleID: String,
        make: String
    ) async throws -> [String: WasmClient.Smartcar.Value] {
        switch method {
            case .getOdometer:
                return try await readReflected(SmartcarOdometer.self, method: method, vehicleID: vehicleID, make: make)
            case .getBatteryLevel, .teslaBatteryStatus:
                return try await readReflected(
                    SmartcarBatteryLevel.self,
                    method: method,
                    vehicleID: vehicleID,
                    make: make
                )
            case .getChargeLimit:
                return try await readReflected(
                    SmartcarChargeLimit.self,
                    method: method,
                    vehicleID: vehicleID,
                    make: make
                )
            case .getNominalCapacity:
                return try await readReflected(
                    SmartcarNominalCapacity.self,
                    method: method,
                    vehicleID: vehicleID,
                    make: make
                )
            case .getLockStatus:
                return try await readReflected(
                    SmartcarLockStatus.self,
                    method: method,
                    vehicleID: vehicleID,
                    make: make
                )
            case .getTiresPressure:
                return try await readReflected(
                    SmartcarTirePressure.self,
                    method: method,
                    vehicleID: vehicleID,
                    make: make
                )
            case .getOilLife:
                return try await readReflected(SmartcarEngineOil.self, method: method, vehicleID: vehicleID, make: make)
            case .getSpeedometer:
                return try await readReflected(
                    SmartcarSpeedometer.self,
                    method: method,
                    vehicleID: vehicleID,
                    make: make
                )
            case .teslaVehicleStatus:
                return try await readReflected(
                    SmartcarVehicleStatus.self,
                    method: method,
                    vehicleID: vehicleID,
                    make: make
                )
            case .teslaChargeStatus:
                return try await readReflected(
                    SmartcarChargeStatus.self,
                    method: method,
                    vehicleID: vehicleID,
                    make: make
                )
            case .teslaInteriorTemperature, .teslaExteriorTemperature:
                return try await readReflected(
                    SmartcarTemperature.self,
                    method: method,
                    vehicleID: vehicleID,
                    make: make
                )
            case .teslaGetCabinClimate:
                return try await readReflected(
                    SmartcarCabinClimate.self,
                    method: method,
                    vehicleID: vehicleID,
                    make: make
                )
            case .teslaGetDefroster, .teslaGetSteeringWheel:
                return try await readReflected(
                    SmartcarToggleState.self,
                    method: method,
                    vehicleID: vehicleID,
                    make: make
                )
            default:
                let instance = try await readyEngine()
                let response: Google_Protobuf_Struct = try await instance.run(
                    method: method.rawValue,
                    args: Self.vehicleArgs(vehicleID: vehicleID, make: make)
                )
                return Self.mapValues(response)
        }
    }

    /// Decodes a read into its concrete proto, then reflects it to a value map
    /// via a JSON round-trip — keeping nested fields and yielding deterministic
    /// camelCase keys, independent of how the engine encodes the wire response.
    private func readReflected<Response: SwiftProtobuf.Message>(
        _ type: Response.Type,
        method: WasmClient.Smartcar.Method,
        vehicleID: String,
        make: String
    ) async throws -> [String: WasmClient.Smartcar.Value] {
        let typed: Response = try await runVehicleRead(method, vehicleID: vehicleID, make: make)
        let json = try typed.jsonUTF8Data()
        return Self.mapValues(try Google_Protobuf_Struct(jsonUTF8Data: json))
    }

    /// Any SET/command method + wire args → the backend's control acknowledgement.
    func smartcarControl(
        method: WasmClient.Smartcar.Method,
        vehicleID: String,
        args: [String: WasmClient.Smartcar.Value]
    ) async throws -> WasmClient.Smartcar.ControlResponse {
        let instance = try await readyEngine()
        let response: SmartcarControlResponse = try await instance.run(
            method: method.rawValue,
            args: Self.controlArgs(vehicleID: vehicleID, extra: args)
        )
        return Self.mapControlResponse(response)
    }
}

// MARK: - Look Up VIN

extension WasmActor {

    /// Decodes a 17-character VIN via the wasm `LookupVin` RPC (public NHTSA
    /// vPIC — no connected Smartcar account). VIN-shape validation is left to
    /// the caller; an empty `vin` is dispatched at the engine-side default.
    func lookupVin(vin: String) async throws -> WasmClient.Smartcar.Vehicle {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !vin.isEmpty {
            args["vin"] = Google_Protobuf_Value(stringValue: vin)
        }
        logger("lookupVin: dispatch method=\(WasmClient.Smartcar.Method.lookupVin.rawValue) vin=\(vin)")
        let vehicle: SmartcarVehicle = try await instance.run(
            method: WasmClient.Smartcar.Method.lookupVin.rawValue,
            args: args
        )
        return Self.mapVehicle(vehicle)
    }
}

// MARK: - Dispatch helpers

extension WasmActor {

    /// Runs one vehicle-scoped read that takes only `vehicle_id` + `make`,
    /// decoding into a specific proto (used by the kept typed reads).
    private func runVehicleRead<Response: SwiftProtobuf.Message>(
        _ method: WasmClient.Smartcar.Method,
        vehicleID: String,
        make: String
    ) async throws -> Response {
        let instance = try await readyEngine()
        return try await instance.run(
            method: method.rawValue,
            args: Self.vehicleArgs(vehicleID: vehicleID, make: make)
        )
    }

    private static func vehicleArgs(
        vehicleID: String,
        make: String
    ) -> [String: Google_Protobuf_Value] {
        var args: [String: Google_Protobuf_Value] = [:]
        if !vehicleID.isEmpty {
            args["vehicle_id"] = Google_Protobuf_Value(stringValue: vehicleID)
        }
        if !make.isEmpty {
            args["make"] = Google_Protobuf_Value(stringValue: make)
        }
        return args
    }

    private static func controlArgs(
        vehicleID: String,
        extra: [String: WasmClient.Smartcar.Value]
    ) -> [String: Google_Protobuf_Value] {
        var args: [String: Google_Protobuf_Value] = [:]
        if !vehicleID.isEmpty {
            args["vehicle_id"] = Google_Protobuf_Value(stringValue: vehicleID)
        }
        for (key, value) in extra {
            args[key] = wireValue(value)
        }
        return args
    }
}

// MARK: - Mapping

extension WasmActor {

    static func mapVehicle(_ vehicle: SmartcarVehicle) -> WasmClient.Smartcar.Vehicle {
        WasmClient.Smartcar.Vehicle(
            identifier: vehicle.vehicleID,
            make: vehicle.make,
            model: vehicle.model,
            year: vehicle.year,
            extra: vehicle.hasExtra ? mapExtra(vehicle.extra) : [:],
            previewImage: vehicle.previewImage,
            previewContour: vehicle.previewContour,
            previewError: vehicle.previewError
        )
    }

    static func mapCatalog(_ catalog: SmartcarCarCatalog) -> WasmClient.Smartcar.Catalog {
        WasmClient.Smartcar.Catalog(
            makes: catalog.dataCar.map(mapCatalogMake),
            path: catalog.path
        )
    }

    private static func mapCatalogMake(_ make: SmartcarCarMake) -> WasmClient.Smartcar.Catalog.Make {
        WasmClient.Smartcar.Catalog.Make(
            company: make.company,
            logo: make.logo,
            models: make.carModels.map(mapCatalogModel)
        )
    }

    private static func mapCatalogModel(_ model: SmartcarCarModel) -> WasmClient.Smartcar.Catalog.Model {
        WasmClient.Smartcar.Catalog.Model(
            name: model.name,
            year: model.yearManufacture,
            image: model.image,
            fuelConsumption: model.fuelConsumption,
            speedBoost: model.speedBoost
        )
    }

    private static func mapPreview(_ preview: SmartcarVehiclePreview) -> WasmClient.Smartcar.Connection.Preview {
        WasmClient.Smartcar.Connection.Preview(
            vehicleID: preview.vehicleID,
            contour: preview.contour,
            image: preview.image,
            vehicle: preview.hasVehicle ? mapVehicle(preview.vehicle) : .init()
        )
    }

    private static func mapConnectConfig(
        _ response: SmartcarConnectConfigResponse
    ) -> WasmClient.Smartcar.Connection.Config {
        WasmClient.Smartcar.Connection.Config(
            applicationID: response.applicationID,
            redirectURI: response.redirectUri,
            scope: response.scope,
            mode: WasmClient.Smartcar.Connection.Mode(rawValue: response.mode.argString),
            connectURL: response.connectURL
        )
    }

    private static func mapHostedConnectDecision(
        _ response: SmartcarHostedConnectEventResponse
    ) -> WasmClient.Smartcar.Connection.Decision {
        WasmClient.Smartcar.Connection.Decision(
            action: WasmClient.Smartcar.Connection.Action(rawValue: response.action.actionString),
            userID: response.userID,
            error: response.error,
            preview: response.hasPreview ? mapPreview(response.preview) : nil,
            previewError: response.previewError
        )
    }

    private static func mapAccountList(_ list: SmartcarAccountList) -> [WasmClient.Smartcar.Account] {
        list.accounts.map { WasmClient.Smartcar.Account(userID: $0.userID, label: $0.label) }
    }

    private static func mapControlResponse(_ response: SmartcarControlResponse) -> WasmClient.Smartcar.ControlResponse {
        WasmClient.Smartcar.ControlResponse(
            action: response.action,
            data: response.hasData ? mapExtra(response.data) : [:]
        )
    }

    /// Flattens an open-ended `Struct` into `[String: String]`, keeping only
    /// entries that carry a scalar value.
    private static func mapExtra(_ structValue: Google_Protobuf_Struct) -> [String: String] {
        structValue.fields.reduce(into: [:]) { result, entry in
            if let scalar = scalarString(entry.value) {
                result[entry.key] = scalar
            }
        }
    }

    private static func scalarString(_ value: Google_Protobuf_Value) -> String? {
        switch value.kind {
            case .stringValue(let string):
                return string
            case .numberValue(let number):
                return String(number)
            case .boolValue(let bool):
                return String(bool)
            default:
                return nil
        }
    }

    /// Maps a generic read response `Struct` into the public `[String: Value]`.
    private static func mapValues(_ structValue: Google_Protobuf_Struct) -> [String: WasmClient.Smartcar.Value] {
        structValue.fields.reduce(into: [:]) { result, entry in
            result[entry.key] = mapValue(entry.value)
        }
    }

    private static func mapValue(_ value: Google_Protobuf_Value) -> WasmClient.Smartcar.Value {
        switch value.kind {
            case .stringValue(let string):
                return .string(string)
            case .numberValue(let number):
                return .number(number)
            case .boolValue(let bool):
                return .bool(bool)
            case .listValue(let list):
                return .array(list.values.map(mapValue))
            case .structValue(let structValue):
                return .object(mapValues(structValue))
            case .nullValue, .none:
                return .null
        }
    }

    private static func wireValue(_ value: WasmClient.Smartcar.Value) -> Google_Protobuf_Value {
        switch value {
            case .string(let string):
                return Google_Protobuf_Value(stringValue: string)
            case .number(let number):
                return Google_Protobuf_Value(numberValue: number)
            case .bool(let bool):
                return Google_Protobuf_Value(boolValue: bool)
            case .array(let values):
                var wire = Google_Protobuf_Value()
                wire.listValue.values = values.map(wireValue)
                return wire
            case .object(let fields):
                var wire = Google_Protobuf_Value()
                wire.structValue.fields = fields.mapValues(wireValue)
                return wire
            case .null:
                var value = Google_Protobuf_Value()
                value.nullValue = .nullValue
                return value
        }
    }
}

// MARK: - Wire-name bridges for generated proto enums

extension SmartcarConnectMode {
    /// Lowercased Connect-mode arg string (`connectConfig` wire form).
    var argString: String {
        switch self {
            case .live:
                return "live"
            case .test:
                return "test"
            case .simulated:
                return "simulated"
            default:
                return ""
        }
    }
}

extension SmartcarHostedConnectAction {
    /// Lowercased decision string matching `Connection.Action` rawValues.
    var actionString: String {
        switch self {
            case .continue:
                return "continue"
            case .cancel:
                return "cancel"
            case .complete:
                return "complete"
            case .error:
                return "error"
            default:
                return "continue"
        }
    }
}
