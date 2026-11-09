import XCTest

@testable import WasmClient

final class UserDeleteTests: XCTestCase {

    func testDeleteUserServiceMethodRawValue() {
        XCTAssertEqual(
            WasmClient.Notification.ServiceMethod.deleteUser.rawValue,
            "asyncify.user.UserService/DeleteUser"
        )
    }

    func testNoopDeleteUserDoesNotThrow() async throws {
        try await WasmClient.noop.deleteUser("firebase-uid")
    }

    func testHappyDeleteUserDoesNotThrow() async throws {
        try await WasmClient.happy.deleteUser("firebase-uid")
    }
}
