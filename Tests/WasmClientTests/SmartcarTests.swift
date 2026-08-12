import XCTest

@testable import WasmClient

final class SmartcarTests: XCTestCase {

    // MARK: - Wire method names

    func testServiceMethodWireStrings() {
        XCTAssertEqual(
            WasmClient.SmartcarMethod.connectConfig.rawValue,
            "asyncify.smartcar.SmartcarService/ConnectConfig"
        )
        XCTAssertEqual(
            WasmClient.SmartcarMethod.getPermissions.rawValue,
            "asyncify.smartcar.SmartcarService/GetPermissions"
        )
        XCTAssertEqual(
            WasmClient.SmartcarMethod.allVehicles.rawValue,
            "asyncify.smartcar.SmartcarService/AllVehicles"
        )
        XCTAssertEqual(
            WasmClient.SmartcarMethod.setSecurity.rawValue,
            "asyncify.smartcar.SmartcarService/SetSecurity"
        )
        XCTAssertEqual(
            WasmClient.SmartcarMethod.teslaBatteryStatus.rawValue,
            "asyncify.smartcar.SmartcarService/TeslaBatteryStatus"
        )
    }

    // MARK: - Wire-mapped action / mode raw values

    func testConnectModeRawValues() {
        XCTAssertEqual(WasmClient.Smartcar.ConnectMode.unspecified.rawValue, "")
        XCTAssertEqual(WasmClient.Smartcar.ConnectMode.live.rawValue, "live")
        XCTAssertEqual(WasmClient.Smartcar.ConnectMode.test.rawValue, "test")
        XCTAssertEqual(WasmClient.Smartcar.ConnectMode.simulated.rawValue, "simulated")
    }

    func testControlActionRawValues() {
        XCTAssertEqual(WasmClient.Smartcar.ChargeAction.start.rawValue, "START")
        XCTAssertEqual(WasmClient.Smartcar.ClimateAction.set.rawValue, "SET")
        XCTAssertEqual(WasmClient.Smartcar.DefrosterAction.open.rawValue, "OPEN")
        XCTAssertEqual(WasmClient.Smartcar.HeaterAction.stop.rawValue, "STOP")
        XCTAssertEqual(WasmClient.Smartcar.SecurityAction.unlock.rawValue, "UNLOCK")
    }

    func testHostedConnectActionRawValues() {
        XCTAssertEqual(WasmClient.Smartcar.HostedConnectAction.complete.rawValue, "complete")
        XCTAssertEqual(WasmClient.Smartcar.HostedConnectAction.error.rawValue, "error")
    }

    // MARK: - Permissions capability

    func testPermissionsContainsKnownScope() {
        let permissions = WasmClient.Smartcar.Permissions(
            permissions: ["read_odometer", "read_battery"]
        )

        XCTAssertTrue(permissions.contains(.readOdometer))
        XCTAssertTrue(permissions.contains(.readBattery))
        XCTAssertFalse(permissions.contains(.readTires))
        XCTAssertFalse(permissions.contains(.controlSecurity))
    }

    func testScopeRawValues() {
        XCTAssertEqual(WasmClient.Smartcar.Scope.readOdometer.rawValue, "read_odometer")
        XCTAssertEqual(WasmClient.Smartcar.Scope.controlClimate.rawValue, "control_climate")
    }

    // MARK: - Optional read semantics

    func testReadsDefaultToNilNotZero() {
        XCTAssertNil(WasmClient.Smartcar.Odometer().distanceKm)
        XCTAssertNil(WasmClient.Smartcar.BatteryLevel().percentRemaining)
        XCTAssertNil(WasmClient.Smartcar.LockStatus().isLocked)
        XCTAssertTrue(WasmClient.Smartcar.LockStatus().doors.isEmpty)
    }

    // MARK: - Mocks

    func testNoopReturnsEmptyValues() async throws {
        let client = WasmClient.noop

        let vehicles = try await client.smartcarAllVehicles("", "")
        XCTAssertTrue(vehicles.isEmpty)

        let permissions = try await client.smartcarGetPermissions("", "")
        XCTAssertTrue(permissions.permissions.isEmpty)
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

        let battery = try await client.smartcarGetBatteryLevel("veh-1", "TESLA")
        XCTAssertEqual(battery.percentRemaining, 0.72)
    }

    func testHappyMockControlEchoesAction() async throws {
        let client = WasmClient.happy

        let response = try await client.smartcarSetSecurity("veh-1", .lock)
        XCTAssertEqual(response.action, "LOCK")
    }
}
