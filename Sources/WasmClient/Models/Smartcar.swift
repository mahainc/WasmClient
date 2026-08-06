import Foundation

// MARK: - Smart Car Namespace

extension WasmClient {
    public enum Smartcar {}
}

extension WasmClient.Smartcar {
    /// One vehicle decoded from a VIN via the public NHTSA vPIC service.
    ///
    /// `vin` maps from the wire `SmartcarVehicle.vehicleID`; `extra` flattens the
    /// backend's open-ended `Struct` of raw vPIC fields into `[String: String]`.
    public struct Vehicle: Sendable, Equatable, Identifiable {
        public var id: String {
            vin
        }

        public var vin: String
        public var make: String
        public var model: String
        public var year: String
        public var extra: [String: String]

        public init(
            vin: String = "",
            make: String = "",
            model: String = "",
            year: String = "",
            extra: [String: String] = [:]
        ) {
            self.vin = vin
            self.make = make
            self.model = model
            self.year = year
            self.extra = extra
        }
    }
}
