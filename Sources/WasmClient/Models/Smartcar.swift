import Foundation

// MARK: - Smart Car Namespace

extension WasmClient {
    public enum Smartcar {}
}

extension WasmClient.Smartcar {
    /// One vehicle: from a VIN decode (`lookupVin`) or a connected account.
    /// `identifier` is the VIN for a decode, the Smartcar vehicle UUID otherwise.
    public struct Vehicle: Sendable, Equatable, Identifiable {
        public var id: String {
            identifier
        }

        public var identifier: String
        public var make: String
        public var model: String
        public var year: String
        public var extra: [String: String]

        public init(
            identifier: String = "",
            make: String = "",
            model: String = "",
            year: String = "",
            extra: [String: String] = [:]
        ) {
            self.identifier = identifier
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

    /// One locally cached connected account. The first account in the returned
    /// `[Account]` is the active one that reads/controls use.
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
}

// MARK: - Generic Reading Value

extension WasmClient.Smartcar {
    /// One field value in a generic read payload (`[String: Value]`). A closed,
    /// fully recursive JSON variant (scalars + nested array/object), so an `enum`
    /// — unlike the open wire vocabularies Scope/method. Recursive cases keep a
    /// read lossless when a make returns nested data (e.g. lock closure arrays).
    public enum Value: Sendable, Equatable, Hashable {
        case string(String)
        case number(Double)
        case bool(Bool)
        case array([Value])
        case object([String: Value])
        case null

        public var stringValue: String? {
            if case .string(let value) = self { value } else { nil }
        }

        public var doubleValue: Double? {
            if case .number(let value) = self { value } else { nil }
        }

        public var boolValue: Bool? {
            if case .bool(let value) = self { value } else { nil }
        }

        public var arrayValue: [Value]? {
            if case .array(let value) = self { value } else { nil }
        }

        public var objectValue: [String: Value]? {
            if case .object(let value) = self { value } else { nil }
        }
    }
}

// MARK: - Capability (permission ↔ read/control method)

extension WasmClient.Smartcar {
    /// Pairs a permission with the wire methods that set it and read it back.
    public struct Capability: Sendable, Equatable {
        public let permission: Permission
        public let controlMethod: Method
        public let readMethod: Method

        public init(
            permission: Permission,
            controlMethod: Method,
            readMethod: Method
        ) {
            self.permission = permission
            self.controlMethod = controlMethod
            self.readMethod = readMethod
        }

        public static let charge = Capability(
            permission: .controlCharge,
            controlMethod: .setChargeLimit,
            readMethod: .getChargeLimit
        )
        public static let security = Capability(
            permission: .controlSecurity,
            controlMethod: .setSecurity,
            readMethod: .getLockStatus
        )
        public static let cabinClimate = Capability(
            permission: .controlClimate,
            controlMethod: .setCabinClimate,
            readMethod: .teslaGetCabinClimate
        )
        public static let defroster = Capability(
            permission: .controlClimate,
            controlMethod: .setDefroster,
            readMethod: .teslaGetDefroster
        )
        public static let steeringWheel = Capability(
            permission: .controlClimate,
            controlMethod: .setSteeringWheel,
            readMethod: .teslaGetSteeringWheel
        )
    }
}

// MARK: - Permission (granted vehicle capability)

extension WasmClient.Smartcar {
    /// A Smartcar scope granted to a vehicle. `rawValue` IS the wire scope;
    /// unknown scopes from a newer backend round-trip losslessly. The granted set
    /// is a plain `[Permission]` — membership is `Array.contains(_:)`.
    public struct Permission: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static let readOdometer = Permission(rawValue: "read_odometer")
        public static let readBattery = Permission(rawValue: "read_battery")
        public static let readCharge = Permission(rawValue: "read_charge")
        public static let readTires = Permission(rawValue: "read_tires")
        public static let readEngineOil = Permission(rawValue: "read_engine_oil")
        public static let readSpeedometer = Permission(rawValue: "read_speedometer")
        public static let readSecurity = Permission(rawValue: "read_security")
        public static let readVehicleInfo = Permission(rawValue: "read_vehicle_info")
        public static let controlCharge = Permission(rawValue: "control_charge")
        public static let controlClimate = Permission(rawValue: "control_climate")
        public static let controlSecurity = Permission(rawValue: "control_security")
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
