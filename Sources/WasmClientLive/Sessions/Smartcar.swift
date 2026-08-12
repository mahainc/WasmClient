@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Connect & Accounts

extension WasmActor {

    /// Fetch the provider's OAuth Connect configuration so the app can launch
    /// hosted Connect without hardcoding backend identity.
    func smartcarConnectConfig(
        mode: WasmClient.Smartcar.ConnectMode
    ) async throws -> WasmClient.Smartcar.ConnectConfig {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !mode.rawValue.isEmpty {
            args["mode"] = Google_Protobuf_Value(stringValue: mode.rawValue)
        }
        let response: SmartcarConnectConfigResponse = try await instance.run(
            method: WasmClient.SmartcarMethod.connectConfig.rawValue,
            args: args
        )
        return Self.mapConnectConfig(response)
    }

    /// Parse one hosted-Connect WebView observation; the guest caches the
    /// credential when it detects the provider's terminal token payload.
    func smartcarHostedConnectEvent(
        url: String,
        bodyText: String
    ) async throws -> WasmClient.Smartcar.HostedConnectDecision {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !url.isEmpty {
            args["url"] = Google_Protobuf_Value(stringValue: url)
        }
        if !bodyText.isEmpty {
            args["body_text"] = Google_Protobuf_Value(stringValue: bodyText)
        }
        let response: SmartcarHostedConnectEventResponse = try await instance.run(
            method: WasmClient.SmartcarMethod.hostedConnectEvent.rawValue,
            args: args
        )
        return Self.mapHostedConnectDecision(response)
    }

    func smartcarAccounts() async throws -> WasmClient.Smartcar.AccountList {
        let instance = try await readyEngine()
        let response: SmartcarAccountList = try await instance.run(
            method: WasmClient.SmartcarMethod.accounts.rawValue,
            args: [:]
        )
        return Self.mapAccountList(response)
    }

    func smartcarSwitchAccount(
        userID: String
    ) async throws -> WasmClient.Smartcar.AccountList {
        try await smartcarAccountMutation(userID: userID, method: .switchAccount)
    }

    func smartcarDeleteAccount(
        userID: String
    ) async throws -> WasmClient.Smartcar.AccountList {
        try await smartcarAccountMutation(userID: userID, method: .deleteAccount)
    }

    private func smartcarAccountMutation(
        userID: String,
        method: WasmClient.SmartcarMethod
    ) async throws -> WasmClient.Smartcar.AccountList {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !userID.isEmpty {
            args["user_id"] = Google_Protobuf_Value(stringValue: userID)
        }
        let response: SmartcarAccountList = try await instance.run(method: method.rawValue, args: args)
        return Self.mapAccountList(response)
    }

    func smartcarAllVehicles(
        vehicleID: String,
        make: String
    ) async throws -> [WasmClient.Smartcar.Vehicle] {
        let instance = try await readyEngine()
        let response: SmartcarVehicleList = try await instance.run(
            method: WasmClient.SmartcarMethod.allVehicles.rawValue,
            args: Self.vehicleArgs(vehicleID: vehicleID, make: make)
        )
        return response.vehicles.map(Self.mapVehicle)
    }
}

// MARK: - Universal Reads

extension WasmActor {

    func smartcarGetOdometer(
        vehicleID: String,
        make: String
    ) async throws -> WasmClient.Smartcar.Odometer {
        let response: SmartcarOdometer = try await smartcarRead(.getOdometer, vehicleID: vehicleID, make: make)
        return WasmClient.Smartcar.Odometer(distanceKm: response.hasDistanceKm ? response.distanceKm : nil)
    }

    func smartcarGetBatteryLevel(
        vehicleID: String,
        make: String
    ) async throws -> WasmClient.Smartcar.BatteryLevel {
        let response: SmartcarBatteryLevel = try await smartcarRead(.getBatteryLevel, vehicleID: vehicleID, make: make)
        return Self.mapBatteryLevel(response)
    }

    func smartcarGetChargeLimit(
        vehicleID: String,
        make: String
    ) async throws -> WasmClient.Smartcar.ChargeLimit {
        let response: SmartcarChargeLimit = try await smartcarRead(.getChargeLimit, vehicleID: vehicleID, make: make)
        return WasmClient.Smartcar.ChargeLimit(limit: response.hasLimit ? response.limit : nil)
    }

    func smartcarGetNominalCapacity(
        vehicleID: String,
        make: String
    ) async throws -> WasmClient.Smartcar.NominalCapacity {
        let response: SmartcarNominalCapacity = try await smartcarRead(
            .getNominalCapacity,
            vehicleID: vehicleID,
            make: make
        )
        return WasmClient.Smartcar.NominalCapacity(capacityKwh: response.hasCapacityKwh ? response.capacityKwh : nil)
    }

    func smartcarGetLockStatus(
        vehicleID: String,
        make: String
    ) async throws -> WasmClient.Smartcar.LockStatus {
        let response: SmartcarLockStatus = try await smartcarRead(.getLockStatus, vehicleID: vehicleID, make: make)
        return Self.mapLockStatus(response)
    }

    func smartcarGetTiresPressure(
        vehicleID: String,
        make: String
    ) async throws -> WasmClient.Smartcar.TirePressure {
        let response: SmartcarTirePressure = try await smartcarRead(.getTiresPressure, vehicleID: vehicleID, make: make)
        return Self.mapTirePressure(response)
    }

    func smartcarGetOilLife(
        vehicleID: String,
        make: String
    ) async throws -> WasmClient.Smartcar.EngineOil {
        let response: SmartcarEngineOil = try await smartcarRead(.getOilLife, vehicleID: vehicleID, make: make)
        return WasmClient.Smartcar.EngineOil(lifeRemaining: response.hasLifeRemaining ? response.lifeRemaining : nil)
    }

    func smartcarGetPermissions(
        vehicleID: String,
        make: String
    ) async throws -> WasmClient.Smartcar.Permissions {
        let response: SmartcarPermissions = try await smartcarRead(.getPermissions, vehicleID: vehicleID, make: make)
        return WasmClient.Smartcar.Permissions(permissions: response.permissions)
    }

    func smartcarGetSpeedometer(
        vehicleID: String,
        make: String
    ) async throws -> WasmClient.Smartcar.Speedometer {
        let response: SmartcarSpeedometer = try await smartcarRead(.getSpeedometer, vehicleID: vehicleID, make: make)
        return WasmClient.Smartcar.Speedometer(speedKph: response.hasSpeedKph ? response.speedKph : nil)
    }
}

// MARK: - Vendor-scoped (Tesla) Reads

extension WasmActor {

    func smartcarTeslaVehicleStatus(
        vehicleID: String,
        make: String
    ) async throws -> WasmClient.Smartcar.VehicleStatus {
        let response: SmartcarVehicleStatus = try await smartcarRead(
            .teslaVehicleStatus,
            vehicleID: vehicleID,
            make: make
        )
        return WasmClient.Smartcar.VehicleStatus(status: response.hasStatus ? response.status : nil)
    }

    func smartcarTeslaVehicleAttributes(
        vehicleID: String,
        make: String
    ) async throws -> WasmClient.Smartcar.Vehicle {
        let response: SmartcarVehicle = try await smartcarRead(
            .teslaVehicleAttributes,
            vehicleID: vehicleID,
            make: make
        )
        return Self.mapVehicle(response)
    }

    func smartcarTeslaBatteryStatus(
        vehicleID: String,
        make: String
    ) async throws -> WasmClient.Smartcar.BatteryLevel {
        let response: SmartcarBatteryLevel = try await smartcarRead(
            .teslaBatteryStatus,
            vehicleID: vehicleID,
            make: make
        )
        return Self.mapBatteryLevel(response)
    }

    func smartcarTeslaChargeStatus(
        vehicleID: String,
        make: String
    ) async throws -> WasmClient.Smartcar.ChargeStatus {
        let response: SmartcarChargeStatus = try await smartcarRead(
            .teslaChargeStatus,
            vehicleID: vehicleID,
            make: make
        )
        return WasmClient.Smartcar.ChargeStatus(
            isPluggedIn: response.hasIsPluggedIn ? response.isPluggedIn : nil,
            state: response.hasState ? response.state : nil
        )
    }

    func smartcarTeslaInteriorTemperature(
        vehicleID: String,
        make: String
    ) async throws -> WasmClient.Smartcar.Temperature {
        let response: SmartcarTemperature = try await smartcarRead(
            .teslaInteriorTemperature,
            vehicleID: vehicleID,
            make: make
        )
        return WasmClient.Smartcar.Temperature(celsius: response.hasCelsius ? response.celsius : nil)
    }

    func smartcarTeslaExteriorTemperature(
        vehicleID: String,
        make: String
    ) async throws -> WasmClient.Smartcar.Temperature {
        let response: SmartcarTemperature = try await smartcarRead(
            .teslaExteriorTemperature,
            vehicleID: vehicleID,
            make: make
        )
        return WasmClient.Smartcar.Temperature(celsius: response.hasCelsius ? response.celsius : nil)
    }

    func smartcarTeslaGetCabinClimate(
        vehicleID: String,
        make: String
    ) async throws -> WasmClient.Smartcar.CabinClimate {
        let response: SmartcarCabinClimate = try await smartcarRead(
            .teslaGetCabinClimate,
            vehicleID: vehicleID,
            make: make
        )
        return WasmClient.Smartcar.CabinClimate(
            on: response.hasOn ? response.on : nil,
            temperatureCelsius: response.hasTemperatureCelsius ? response.temperatureCelsius : nil
        )
    }

    func smartcarTeslaGetDefroster(
        vehicleID: String,
        make: String
    ) async throws -> WasmClient.Smartcar.ToggleState {
        let response: SmartcarToggleState = try await smartcarRead(
            .teslaGetDefroster,
            vehicleID: vehicleID,
            make: make
        )
        return WasmClient.Smartcar.ToggleState(on: response.hasOn ? response.on : nil)
    }

    func smartcarTeslaGetSteeringWheel(
        vehicleID: String,
        make: String
    ) async throws -> WasmClient.Smartcar.ToggleState {
        let response: SmartcarToggleState = try await smartcarRead(
            .teslaGetSteeringWheel,
            vehicleID: vehicleID,
            make: make
        )
        return WasmClient.Smartcar.ToggleState(on: response.hasOn ? response.on : nil)
    }
}

// MARK: - Controls

extension WasmActor {

    func smartcarSetChargeLimit(
        vehicleID: String,
        action: WasmClient.Smartcar.ChargeAction
    ) async throws -> WasmClient.Smartcar.ControlResponse {
        try await smartcarControl(.setChargeLimit, vehicleID: vehicleID, action: action.rawValue)
    }

    func smartcarSetCabinClimate(
        vehicleID: String,
        action: WasmClient.Smartcar.ClimateAction,
        temperatureCelsius: Double
    ) async throws -> WasmClient.Smartcar.ControlResponse {
        let instance = try await readyEngine()
        var args = Self.controlArgs(vehicleID: vehicleID, action: action.rawValue)
        args["temperature_celsius"] = Google_Protobuf_Value(numberValue: temperatureCelsius)
        let response: SmartcarControlResponse = try await instance.run(
            method: WasmClient.SmartcarMethod.setCabinClimate.rawValue,
            args: args
        )
        return Self.mapControlResponse(response)
    }

    func smartcarSetDefroster(
        vehicleID: String,
        action: WasmClient.Smartcar.DefrosterAction
    ) async throws -> WasmClient.Smartcar.ControlResponse {
        try await smartcarControl(.setDefroster, vehicleID: vehicleID, action: action.rawValue)
    }

    func smartcarSetSteeringWheel(
        vehicleID: String,
        action: WasmClient.Smartcar.HeaterAction
    ) async throws -> WasmClient.Smartcar.ControlResponse {
        try await smartcarControl(.setSteeringWheel, vehicleID: vehicleID, action: action.rawValue)
    }

    func smartcarSetSecurity(
        vehicleID: String,
        action: WasmClient.Smartcar.SecurityAction
    ) async throws -> WasmClient.Smartcar.ControlResponse {
        try await smartcarControl(.setSecurity, vehicleID: vehicleID, action: action.rawValue)
    }

    private func smartcarControl(
        _ method: WasmClient.SmartcarMethod,
        vehicleID: String,
        action: String
    ) async throws -> WasmClient.Smartcar.ControlResponse {
        let instance = try await readyEngine()
        let response: SmartcarControlResponse = try await instance.run(
            method: method.rawValue,
            args: Self.controlArgs(vehicleID: vehicleID, action: action)
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
        logger("lookupVin: dispatch method=\(WasmClient.SmartcarMethod.lookupVin.rawValue) vin=\(vin)")
        let vehicle: SmartcarVehicle = try await instance.run(
            method: WasmClient.SmartcarMethod.lookupVin.rawValue,
            args: args
        )
        return Self.mapVehicle(vehicle)
    }
}

// MARK: - Dispatch helpers

extension WasmActor {

    /// Runs one vehicle-scoped read that takes only `vehicle_id` + `make`.
    private func smartcarRead<Response: SwiftProtobuf.Message>(
        _ method: WasmClient.SmartcarMethod,
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
        action: String
    ) -> [String: Google_Protobuf_Value] {
        var args: [String: Google_Protobuf_Value] = [:]
        if !vehicleID.isEmpty {
            args["vehicle_id"] = Google_Protobuf_Value(stringValue: vehicleID)
        }
        if !action.isEmpty {
            args["action"] = Google_Protobuf_Value(stringValue: action)
        }
        return args
    }
}

// MARK: - Mapping

extension WasmActor {

    static func mapVehicle(_ vehicle: SmartcarVehicle) -> WasmClient.Smartcar.Vehicle {
        WasmClient.Smartcar.Vehicle(
            vin: vehicle.vehicleID,
            make: vehicle.make,
            model: vehicle.model,
            year: vehicle.year,
            extra: vehicle.hasExtra ? mapExtra(vehicle.extra) : [:]
        )
    }

    private static func mapConnectConfig(
        _ response: SmartcarConnectConfigResponse
    ) -> WasmClient.Smartcar.ConnectConfig {
        WasmClient.Smartcar.ConnectConfig(
            applicationID: response.applicationID,
            redirectURI: response.redirectUri,
            scope: response.scope,
            mode: WasmClient.Smartcar.ConnectMode(rawValue: response.mode.argString),
            connectURL: response.connectURL
        )
    }

    private static func mapHostedConnectDecision(
        _ response: SmartcarHostedConnectEventResponse
    ) -> WasmClient.Smartcar.HostedConnectDecision {
        WasmClient.Smartcar.HostedConnectDecision(
            action: WasmClient.Smartcar.HostedConnectAction(rawValue: response.action.actionString),
            userID: response.userID,
            error: response.error
        )
    }

    private static func mapAccountList(_ list: SmartcarAccountList) -> WasmClient.Smartcar.AccountList {
        WasmClient.Smartcar.AccountList(
            accounts: list.accounts.map { WasmClient.Smartcar.Account(userID: $0.userID, label: $0.label) }
        )
    }

    private static func mapBatteryLevel(_ battery: SmartcarBatteryLevel) -> WasmClient.Smartcar.BatteryLevel {
        WasmClient.Smartcar.BatteryLevel(
            percentRemaining: battery.hasPercentRemaining ? battery.percentRemaining : nil,
            rangeKm: battery.hasRangeKm ? battery.rangeKm : nil
        )
    }

    private static func mapLockStatus(_ lock: SmartcarLockStatus) -> WasmClient.Smartcar.LockStatus {
        WasmClient.Smartcar.LockStatus(
            isLocked: lock.hasIsLocked ? lock.isLocked : nil,
            doors: lock.doors.map(mapClosure),
            windows: lock.windows.map(mapClosure),
            sunroof: lock.sunroof.map(mapClosure),
            storage: lock.storage.map(mapClosure),
            chargingPort: lock.chargingPort.map(mapClosure)
        )
    }

    private static func mapClosure(_ closure: SmartcarClosureStatus) -> WasmClient.Smartcar.ClosureStatus {
        WasmClient.Smartcar.ClosureStatus(type: closure.type, status: closure.status)
    }

    private static func mapTirePressure(_ tires: SmartcarTirePressure) -> WasmClient.Smartcar.TirePressure {
        WasmClient.Smartcar.TirePressure(
            frontLeftKpa: tires.hasFrontLeftKpa ? tires.frontLeftKpa : nil,
            frontRightKpa: tires.hasFrontRightKpa ? tires.frontRightKpa : nil,
            backLeftKpa: tires.hasBackLeftKpa ? tires.backLeftKpa : nil,
            backRightKpa: tires.hasBackRightKpa ? tires.backRightKpa : nil
        )
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
    /// Lowercased decision string matching `HostedConnectAction` rawValues.
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
