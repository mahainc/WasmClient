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

// MARK: - Connect & Accounts

extension WasmClient.Smartcar {
    /// Launch mode for Smartcar Connect. `rawValue` IS the wire arg string
    /// (`connectConfig` sends it lowercased); unknown values round-trip.
    public struct ConnectMode: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static let unspecified = ConnectMode(rawValue: "")
        public static let live = ConnectMode(rawValue: "live")
        public static let test = ConnectMode(rawValue: "test")
        public static let simulated = ConnectMode(rawValue: "simulated")
    }

    /// OAuth Connect configuration returned by the guest so the app can launch
    /// hosted Connect without hardcoding backend identity.
    public struct ConnectConfig: Sendable, Equatable {
        public var applicationID: String
        public var redirectURI: String
        public var scope: [String]
        public var mode: ConnectMode
        public var connectURL: String

        public init(
            applicationID: String = "",
            redirectURI: String = "",
            scope: [String] = [],
            mode: ConnectMode = .unspecified,
            connectURL: String = ""
        ) {
            self.applicationID = applicationID
            self.redirectURI = redirectURI
            self.scope = scope
            self.mode = mode
            self.connectURL = connectURL
        }
    }

    /// What the native hosted-Connect WebView should do next, decided by the
    /// guest after parsing one URL/body observation.
    public struct HostedConnectAction: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static let `continue` = HostedConnectAction(rawValue: "continue")
        public static let cancel = HostedConnectAction(rawValue: "cancel")
        public static let complete = HostedConnectAction(rawValue: "complete")
        public static let error = HostedConnectAction(rawValue: "error")
    }

    /// Guest decision for one hosted-Connect observation. On `.complete`,
    /// `userID` carries the cached credential; on `.error`, `error` is set.
    public struct HostedConnectDecision: Sendable, Equatable {
        public var action: HostedConnectAction
        public var userID: String
        public var error: String

        public init(
            action: HostedConnectAction = .continue,
            userID: String = "",
            error: String = ""
        ) {
            self.action = action
            self.userID = userID
            self.error = error
        }
    }

    /// One locally cached connected account. The first account in `AccountList`
    /// is the active one that reads/controls use.
    public struct Account: Sendable, Equatable, Identifiable {
        public var id: String {
            userID
        }

        public var userID: String
        public var label: String

        public init(
            userID: String = "",
            label: String = ""
        ) {
            self.userID = userID
            self.label = label
        }
    }

    public struct AccountList: Sendable, Equatable {
        public var accounts: [Account]

        public init(accounts: [Account] = []) {
            self.accounts = accounts
        }
    }
}

// MARK: - Universal Reads

extension WasmClient.Smartcar {
    /// Total distance traveled. `nil` means the vehicle did not report it.
    public struct Odometer: Sendable, Equatable {
        public var distanceKm: Double?

        public init(distanceKm: Double? = nil) {
            self.distanceKm = distanceKm
        }
    }

    /// EV battery state of charge and estimated range.
    public struct BatteryLevel: Sendable, Equatable {
        public var percentRemaining: Double?
        public var rangeKm: Double?

        public init(
            percentRemaining: Double? = nil,
            rangeKm: Double? = nil
        ) {
            self.percentRemaining = percentRemaining
            self.rangeKm = rangeKm
        }
    }

    /// Configured EV charge target as a fraction in [0, 1].
    public struct ChargeLimit: Sendable, Equatable {
        public var limit: Double?

        public init(limit: Double? = nil) {
            self.limit = limit
        }
    }

    /// EV charge status: cable plugged-in flag and charging-state label.
    public struct ChargeStatus: Sendable, Equatable {
        public var isPluggedIn: Bool?
        public var state: String?

        public init(
            isPluggedIn: Bool? = nil,
            state: String? = nil
        ) {
            self.isPluggedIn = isPluggedIn
            self.state = state
        }
    }

    /// Rated (nominal) EV battery capacity, in kilowatt-hours.
    public struct NominalCapacity: Sendable, Equatable {
        public var capacityKwh: Double?

        public init(capacityKwh: Double? = nil) {
            self.capacityKwh = capacityKwh
        }
    }

    /// Tire pressures by corner, in kilopascals.
    public struct TirePressure: Sendable, Equatable {
        public var frontLeftKpa: Double?
        public var frontRightKpa: Double?
        public var backLeftKpa: Double?
        public var backRightKpa: Double?

        public init(
            frontLeftKpa: Double? = nil,
            frontRightKpa: Double? = nil,
            backLeftKpa: Double? = nil,
            backRightKpa: Double? = nil
        ) {
            self.frontLeftKpa = frontLeftKpa
            self.frontRightKpa = frontRightKpa
            self.backLeftKpa = backLeftKpa
            self.backRightKpa = backRightKpa
        }
    }

    /// One closure's open/close state (door, window, sunroof, storage, port).
    public struct ClosureStatus: Sendable, Equatable {
        public var type: String
        public var status: String

        public init(
            type: String = "",
            status: String = ""
        ) {
            self.type = type
            self.status = status
        }
    }

    /// Lock status. The default backend may report only `isLocked`, leaving the
    /// closure arrays empty.
    public struct LockStatus: Sendable, Equatable {
        public var isLocked: Bool?
        public var doors: [ClosureStatus]
        public var windows: [ClosureStatus]
        public var sunroof: [ClosureStatus]
        public var storage: [ClosureStatus]
        public var chargingPort: [ClosureStatus]

        public init(
            isLocked: Bool? = nil,
            doors: [ClosureStatus] = [],
            windows: [ClosureStatus] = [],
            sunroof: [ClosureStatus] = [],
            storage: [ClosureStatus] = [],
            chargingPort: [ClosureStatus] = []
        ) {
            self.isLocked = isLocked
            self.doors = doors
            self.windows = windows
            self.sunroof = sunroof
            self.storage = storage
            self.chargingPort = chargingPort
        }
    }

    /// Remaining engine-oil life as a fraction in [0, 1] (ICE/hybrid only).
    public struct EngineOil: Sendable, Equatable {
        public var lifeRemaining: Double?

        public init(lifeRemaining: Double? = nil) {
            self.lifeRemaining = lifeRemaining
        }
    }

    /// Current vehicle speed, in kilometers per hour.
    public struct Speedometer: Sendable, Equatable {
        public var speedKph: Double?

        public init(speedKph: Double? = nil) {
            self.speedKph = speedKph
        }
    }
}

// MARK: - Permissions (capability)

extension WasmClient.Smartcar {
    /// A Smartcar scope string granted to a vehicle. `rawValue` IS the wire
    /// scope; unknown scopes from a newer backend round-trip losslessly.
    public struct Scope: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static let readOdometer = Scope(rawValue: "read_odometer")
        public static let readBattery = Scope(rawValue: "read_battery")
        public static let readCharge = Scope(rawValue: "read_charge")
        public static let readTires = Scope(rawValue: "read_tires")
        public static let readEngineOil = Scope(rawValue: "read_engine_oil")
        public static let readSpeedometer = Scope(rawValue: "read_speedometer")
        public static let readSecurity = Scope(rawValue: "read_security")
        public static let readVehicleInfo = Scope(rawValue: "read_vehicle_info")
        public static let controlCharge = Scope(rawValue: "control_charge")
        public static let controlClimate = Scope(rawValue: "control_climate")
        public static let controlSecurity = Scope(rawValue: "control_security")
    }

    /// Scopes the backend reports as granted for one vehicle — the answer to
    /// "what can this connected vehicle read/control".
    public struct Permissions: Sendable, Equatable {
        public var permissions: [String]

        public init(permissions: [String] = []) {
            self.permissions = permissions
        }

        public func contains(_ scope: Scope) -> Bool {
            permissions.contains(scope.rawValue)
        }
    }
}

// MARK: - Vendor-scoped (Tesla) Reads

extension WasmClient.Smartcar {
    /// A single temperature reading, in degrees Celsius.
    public struct Temperature: Sendable, Equatable {
        public var celsius: Double?

        public init(celsius: Double? = nil) {
            self.celsius = celsius
        }
    }

    /// Cabin climate (HVAC) on/off state and current target temperature.
    public struct CabinClimate: Sendable, Equatable {
        public var on: Bool?
        public var temperatureCelsius: Double?

        public init(
            on: Bool? = nil,
            temperatureCelsius: Double? = nil
        ) {
            self.on = on
            self.temperatureCelsius = temperatureCelsius
        }
    }

    /// A vendor-scoped on/off accessory state (defroster, steering-wheel heater).
    public struct ToggleState: Sendable, Equatable {
        public var on: Bool?

        public init(on: Bool? = nil) {
            self.on = on
        }
    }

    /// Free-form vehicle status label, passed through as reported.
    public struct VehicleStatus: Sendable, Equatable {
        public var status: String?

        public init(status: String? = nil) {
            self.status = status
        }
    }
}

// MARK: - Controls

extension WasmClient.Smartcar {
    /// EV charge session toggle. `rawValue` IS the wire arg string.
    public struct ChargeAction: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static let start = ChargeAction(rawValue: "START")
        public static let stop = ChargeAction(rawValue: "STOP")
    }

    /// Cabin-climate command. `SET` applies `temperatureCelsius`.
    public struct ClimateAction: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static let start = ClimateAction(rawValue: "START")
        public static let stop = ClimateAction(rawValue: "STOP")
        public static let set = ClimateAction(rawValue: "SET")
    }

    /// Front-defroster command.
    public struct DefrosterAction: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static let open = DefrosterAction(rawValue: "OPEN")
        public static let close = DefrosterAction(rawValue: "CLOSE")
    }

    /// Steering-wheel heater toggle.
    public struct HeaterAction: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static let start = HeaterAction(rawValue: "START")
        public static let stop = HeaterAction(rawValue: "STOP")
    }

    /// Vehicle lock command.
    public struct SecurityAction: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static let lock = SecurityAction(rawValue: "LOCK")
        public static let unlock = SecurityAction(rawValue: "UNLOCK")
    }

    /// Result of a control command: the action the backend echoes after
    /// applying it, plus any extra fields it returned.
    public struct ControlResponse: Sendable, Equatable {
        public var action: String
        public var data: [String: String]

        public init(
            action: String = "",
            data: [String: String] = [:]
        ) {
            self.action = action
            self.data = data
        }
    }
}
