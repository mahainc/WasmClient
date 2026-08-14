import XCTest

@testable import WasmClient

final class SmartcarTests: XCTestCase {

    // MARK: - Wire method names

    func testServiceMethodWireStrings() {
        XCTAssertEqual(
            WasmClient.Smartcar.Method.connectConfig.rawValue,
            "asyncify.smartcar.SmartcarService/ConnectConfig"
        )
        XCTAssertEqual(
            WasmClient.Smartcar.Method.getPermissions.rawValue,
            "asyncify.smartcar.SmartcarService/GetPermissions"
        )
        XCTAssertEqual(
            WasmClient.Smartcar.Method.allVehicles.rawValue,
            "asyncify.smartcar.SmartcarService/AllVehicles"
        )
        XCTAssertEqual(
            WasmClient.Smartcar.Method.setSecurity.rawValue,
            "asyncify.smartcar.SmartcarService/SetSecurity"
        )
        XCTAssertEqual(
            WasmClient.Smartcar.Method.teslaBatteryStatus.rawValue,
            "asyncify.smartcar.SmartcarService/TeslaBatteryStatus"
        )
    }

    // MARK: - Wire-mapped action / mode raw values

    func testConnectionModeRawValues() {
        XCTAssertEqual(WasmClient.Smartcar.Connection.Mode.unspecified.rawValue, "")
        XCTAssertEqual(WasmClient.Smartcar.Connection.Mode.live.rawValue, "live")
        XCTAssertEqual(WasmClient.Smartcar.Connection.Mode.test.rawValue, "test")
        XCTAssertEqual(WasmClient.Smartcar.Connection.Mode.simulated.rawValue, "simulated")
    }

    func testControlActionRawValues() {
        XCTAssertEqual(WasmClient.Smartcar.ChargeAction.start.rawValue, "START")
        XCTAssertEqual(WasmClient.Smartcar.ClimateAction.set.rawValue, "SET")
        XCTAssertEqual(WasmClient.Smartcar.DefrosterAction.open.rawValue, "OPEN")
        XCTAssertEqual(WasmClient.Smartcar.HeaterAction.stop.rawValue, "STOP")
        XCTAssertEqual(WasmClient.Smartcar.SecurityAction.unlock.rawValue, "UNLOCK")
    }

    func testConnectionActionRawValues() {
        XCTAssertEqual(WasmClient.Smartcar.Connection.Action.complete.rawValue, "complete")
        XCTAssertEqual(WasmClient.Smartcar.Connection.Action.error.rawValue, "error")
    }

    // MARK: - Permissions capability

    func testGrantedPermissionsContainKnownScope() {
        let permissions: [WasmClient.Smartcar.Permission] = [.readOdometer, .readBattery]

        XCTAssertTrue(permissions.contains(.readOdometer))
        XCTAssertTrue(permissions.contains(.readBattery))
        XCTAssertFalse(permissions.contains(.readTires))
        XCTAssertFalse(permissions.contains(.controlSecurity))
    }

    func testPermissionRawValues() {
        XCTAssertEqual(WasmClient.Smartcar.Permission.readOdometer.rawValue, "read_odometer")
        XCTAssertEqual(WasmClient.Smartcar.Permission.controlClimate.rawValue, "control_climate")
    }

    // MARK: - Generic value

    func testValueAccessorsUnwrapMatchingCase() {
        XCTAssertEqual(WasmClient.Smartcar.Value.number(0.8).doubleValue, 0.8)
        XCTAssertEqual(WasmClient.Smartcar.Value.string("LOCK").stringValue, "LOCK")
        XCTAssertEqual(WasmClient.Smartcar.Value.bool(true).boolValue, true)
        XCTAssertNil(WasmClient.Smartcar.Value.string("x").doubleValue)
        XCTAssertNil(WasmClient.Smartcar.Value.null.boolValue)
    }

    func testValueCarriesNestedArrayAndObject() {
        let nested = WasmClient.Smartcar.Value.array([
            .object(["type": .string("frontLeft"), "status": .string("OPEN")])
        ])
        XCTAssertEqual(nested.arrayValue?.count, 1)
        XCTAssertEqual(nested.arrayValue?.first?.objectValue?["status"]?.stringValue, "OPEN")
        XCTAssertNil(nested.stringValue)
        XCTAssertNil(WasmClient.Smartcar.Value.string("x").arrayValue)
    }

    // MARK: - Capability table

    func testCapabilityPairsPermissionWithMethods() {
        XCTAssertEqual(WasmClient.Smartcar.Capability.charge.permission, .controlCharge)
        XCTAssertEqual(WasmClient.Smartcar.Capability.charge.controlMethod, .setChargeLimit)
        XCTAssertEqual(WasmClient.Smartcar.Capability.charge.readMethod, .getChargeLimit)
        XCTAssertEqual(WasmClient.Smartcar.Capability.security.readMethod, .getLockStatus)
    }

    // MARK: - Error

    func testMissingPermissionErrorNamesPermission() {
        let error = WasmClient.Error.missingPermission(permission: "control_charge")
        XCTAssertEqual(error, .missingPermission(permission: "control_charge"))
        XCTAssertTrue(error.errorDescription?.contains("control_charge") ?? false)
    }

    // MARK: - Mocks

    func testNoopReturnsEmptyValues() async throws {
        let client = WasmClient.noop

        let vehicles = try await client.smartcarAllVehicles("", "")
        XCTAssertTrue(vehicles.isEmpty)

        let permissions = try await client.smartcarGetPermissions("", "")
        XCTAssertTrue(permissions.isEmpty)

        let reading = try await client.smartcarRead(.getBatteryLevel, "", "")
        XCTAssertTrue(reading.isEmpty)
    }

    func testHappyMockConnectsAndReportsCapability() async throws {
        let client = WasmClient.happy

        let config = try await client.smartcarConnectConfig(.unspecified)
        XCTAssertEqual(config.mode, .test)
        XCTAssertFalse(config.connectURL.isEmpty)

        let decision = try await client.smartcarHostedConnectEvent(
            "scmock://exchange?code=abc",
            ""
        )
        XCTAssertEqual(decision.action, .complete)
        XCTAssertEqual(decision.userID, "mock-user-id")

        let vehicles = try await client.smartcarAllVehicles("", "")
        XCTAssertEqual(vehicles.first?.make, "TESLA")

        let permissions = try await client.smartcarGetPermissions("veh-1", "TESLA")
        XCTAssertTrue(permissions.contains(.readBattery))

        let battery = try await client.smartcarRead(.getBatteryLevel, "veh-1", "TESLA")
        XCTAssertEqual(battery["percentRemaining"]?.doubleValue, 0.72)
    }

    func testHappyMockControlEchoesAction() async throws {
        let client = WasmClient.happy

        let response = try await client.smartcarControl(
            .setSecurity,
            "veh-1",
            ["action": .string("LOCK")]
        )
        XCTAssertEqual(response.action, "LOCK")
    }

    func testLockStatusReadExposesNestedClosureArrays() async throws {
        let client = WasmClient.happy

        let lock = try await client.smartcarRead(.getLockStatus, "veh-1", "TESLA")
        XCTAssertEqual(lock["isLocked"]?.boolValue, true)

        let doors = lock["doors"]?.arrayValue
        XCTAssertEqual(doors?.count, 2)
        XCTAssertEqual(doors?.first?.objectValue?["status"]?.stringValue, "LOCKED")
    }
}
