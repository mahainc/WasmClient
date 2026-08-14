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

// MARK: - Connection (OAuth hosted Connect)

extension WasmClient.Smartcar {
    public enum Connection {}
}

extension WasmClient.Smartcar.Connection {
    /// Launch mode for Smartcar Connect. `rawValue` IS the wire arg string
    /// (`connectConfig` sends it lowercased); unknown values round-trip.
    public struct Mode: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static let unspecified = Mode(rawValue: "")
        public static let live = Mode(rawValue: "live")
        public static let test = Mode(rawValue: "test")
        public static let simulated = Mode(rawValue: "simulated")
    }

    /// OAuth Connect configuration returned by the guest so the app can launch
    /// hosted Connect without hardcoding backend identity.
    public struct Config: Sendable, Equatable {
        public var applicationID: String
        public var redirectURI: String
        public var scope: [String]
        public var mode: Mode
        public var connectURL: String

        public init(
            applicationID: String = "",
            redirectURI: String = "",
            scope: [String] = [],
            mode: Mode = .unspecified,
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
    public struct Action: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static let `continue` = Action(rawValue: "continue")
        public static let cancel = Action(rawValue: "cancel")
        public static let complete = Action(rawValue: "complete")
        public static let error = Action(rawValue: "error")
    }

    /// Guest decision for one hosted-Connect observation. On `.complete`,
    /// `userID` carries the cached credential; on `.error`, `error` is set.
    public struct Decision: Sendable, Equatable {
        public var action: Action
        public var userID: String
        public var error: String

        public init(
            action: Action = .continue,
            userID: String = "",
            error: String = ""
        ) {
            self.action = action
            self.userID = userID
            self.error = error
        }
    }
}

// MARK: - Accounts

extension WasmClient.Smartcar {

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
    /// A vehicle-control action whose `rawValue` IS the wire arg string. The
    /// phantom `Tag` makes each control's vocabulary a distinct type.
    public struct RawAction<Tag>: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }

    public enum ChargeTag {}
    public enum ClimateTag {}
    public enum DefrosterTag {}
    public enum HeaterTag {}
    public enum SecurityTag {}

    /// EV charge session toggle.
    public typealias ChargeAction = RawAction<ChargeTag>
    /// Cabin-climate command. `SET` applies `temperatureCelsius`.
    public typealias ClimateAction = RawAction<ClimateTag>
    /// Front-defroster command.
    public typealias DefrosterAction = RawAction<DefrosterTag>
    /// Steering-wheel heater toggle.
    public typealias HeaterAction = RawAction<HeaterTag>
    /// Vehicle lock command.
    public typealias SecurityAction = RawAction<SecurityTag>
}

extension WasmClient.Smartcar.RawAction where Tag == WasmClient.Smartcar.ChargeTag {
    public static let start = Self(rawValue: "START")
    public static let stop = Self(rawValue: "STOP")
}

extension WasmClient.Smartcar.RawAction where Tag == WasmClient.Smartcar.ClimateTag {
    public static let start = Self(rawValue: "START")
    public static let stop = Self(rawValue: "STOP")
    public static let set = Self(rawValue: "SET")
}

extension WasmClient.Smartcar.RawAction where Tag == WasmClient.Smartcar.DefrosterTag {
    public static let open = Self(rawValue: "OPEN")
    public static let close = Self(rawValue: "CLOSE")
}

extension WasmClient.Smartcar.RawAction where Tag == WasmClient.Smartcar.HeaterTag {
    public static let start = Self(rawValue: "START")
    public static let stop = Self(rawValue: "STOP")
}

extension WasmClient.Smartcar.RawAction where Tag == WasmClient.Smartcar.SecurityTag {
    public static let lock = Self(rawValue: "LOCK")
    public static let unlock = Self(rawValue: "UNLOCK")
}

// MARK: - Control Response

extension WasmClient.Smartcar {

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
