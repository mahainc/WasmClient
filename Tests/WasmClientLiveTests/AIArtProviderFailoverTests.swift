import XCTest

@testable import WasmClientLive

/// Unit tests for the pure provider-failover ranking used by `generateAIArt`.
/// The engine registers providers that advertise no model for a mode (e.g. a
/// runware entry with no ListModels row); ranking pushes those last so a blind
/// pick never throws "missing runware data entry".
final class AIArtProviderFailoverTests: XCTestCase {

    func testCatalogueProvidersRankBeforeUnbackedOnes() {
        // `runware` first in registration order but absent from the catalogue.
        let order = WasmActor.providerFailoverOrder(
            providers: ["runware", "banana_a", "banana_b"],
            catalogueProviderIDs: ["banana_a", "banana_b"],
            preferredProviderID: nil
        )

        // banana providers (indices 1, 2) come before the unbacked runware (0).
        XCTAssertEqual(order, [1, 2, 0])
    }

    func testPreferredProviderRanksFirst() {
        let order = WasmActor.providerFailoverOrder(
            providers: ["banana_a", "banana_b", "runware"],
            catalogueProviderIDs: ["banana_a", "banana_b"],
            preferredProviderID: "banana_b"
        )

        // Preferred provider (index 1) leads; the rest keep catalogue-first order.
        XCTAssertEqual(order, [1, 0, 2])
    }

    func testStableWithinSameRank() {
        // Empty catalogue → every provider shares rank 2; original order holds.
        let order = WasmActor.providerFailoverOrder(
            providers: ["p0", "p1", "p2"],
            catalogueProviderIDs: [],
            preferredProviderID: nil
        )

        XCTAssertEqual(order, [0, 1, 2])
    }

    func testEmptyPreferredIsIgnored() {
        let order = WasmActor.providerFailoverOrder(
            providers: ["runware", "banana_a"],
            catalogueProviderIDs: ["banana_a"],
            preferredProviderID: ""
        )

        XCTAssertEqual(order, [1, 0])
    }
}
