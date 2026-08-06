@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

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

// MARK: - Mapping

extension WasmActor {

    private static func mapVehicle(_ vehicle: SmartcarVehicle) -> WasmClient.Smartcar.Vehicle {
        WasmClient.Smartcar.Vehicle(
            vin: vehicle.vehicleID,
            make: vehicle.make,
            model: vehicle.model,
            year: vehicle.year,
            extra: vehicle.hasExtra ? mapExtra(vehicle.extra) : [:]
        )
    }

    /// Flattens the open-ended `Struct` of raw vPIC fields into `[String: String]`,
    /// keeping only entries that carry a scalar value.
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
