import XCTest

@testable import WasmClient

final class TCGHoldingsRequestTests: XCTestCase {

    // MARK: - Wire constants

    func testServiceMethodRawValues() {
        XCTAssertEqual(
            WasmClient.TCG.ServiceMethod.holdingDetail.rawValue,
            "asyncify.tcg.TcgService/HoldingDetail"
        )
        XCTAssertEqual(
            WasmClient.TCG.ServiceMethod.updateHolding.rawValue,
            "asyncify.tcg.TcgService/UpdateHolding"
        )
        XCTAssertEqual(
            WasmClient.TCG.ServiceMethod.removeHolding.rawValue,
            "asyncify.tcg.TcgService/RemoveHolding"
        )
    }

    // MARK: - Model defaults

    func testDefaults() {
        XCTAssertEqual(WasmClient.TCG.HoldingDetail().item, WasmClient.TCG.CollectionItem())
        XCTAssertFalse(WasmClient.TCG.UpdateHoldingResult().ok)
        XCTAssertEqual(WasmClient.TCG.UpdateHoldingResult().item, WasmClient.TCG.CollectionItem())
        XCTAssertFalse(WasmClient.TCG.RemoveHoldingResult().ok)
    }

    // MARK: - Mocks

    func testNoopReturnsEmpty() async throws {
        let detail = try await WasmClient.noop.tcgHoldingDetail("")
        XCTAssertEqual(detail, WasmClient.TCG.HoldingDetail())
        let updated = try await WasmClient.noop.tcgUpdateHolding("", nil, nil, nil, nil)
        XCTAssertEqual(updated, WasmClient.TCG.UpdateHoldingResult())
        let removed = try await WasmClient.noop.tcgRemoveHolding("", "", WasmClient.TCG.Variant(), 0)
        XCTAssertEqual(removed, WasmClient.TCG.RemoveHoldingResult())
    }

    func testHappyReturnsPopulated() async throws {
        let detail = try await WasmClient.happy.tcgHoldingDetail("h1")
        XCTAssertEqual(detail.item.id, "h1")
        XCTAssertEqual(detail.item.card.name, "Charizard")
        XCTAssertEqual(detail.item.quantity, 2)

        let updated = try await WasmClient.happy.tcgUpdateHolding("h1", "50.00", "2026-01-01", "note", 3)
        XCTAssertTrue(updated.ok)
        XCTAssertEqual(updated.item.id, "h1")
        XCTAssertEqual(updated.item.quantity, 3)

        let removed = try await WasmClient.happy.tcgRemoveHolding("h1", "c1", WasmClient.TCG.Variant(), 1)
        XCTAssertTrue(removed.ok)
    }
}
