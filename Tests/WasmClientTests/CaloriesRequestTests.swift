import XCTest

@testable import WasmClient

final class CaloriesRequestTests: XCTestCase {

    // MARK: - Wire constants

    func testServiceMethodRawValues() {
        XCTAssertEqual(
            WasmClient.Calories.ServiceMethod.analyze.rawValue,
            "asyncify.calories.CaloriesService/Analyze"
        )
        XCTAssertEqual(
            WasmClient.Calories.ServiceMethod.search.rawValue,
            "asyncify.calories.CaloriesService/Search"
        )
        XCTAssertEqual(
            WasmClient.Calories.ServiceMethod.healthScore.rawValue,
            "asyncify.calories.CaloriesService/HealthScore"
        )
        XCTAssertEqual(
            WasmClient.Calories.ServiceMethod.barcode.rawValue,
            "asyncify.calories.CaloriesService/Barcode"
        )
        XCTAssertEqual(
            WasmClient.Calories.ServiceMethod.suggestions.rawValue,
            "asyncify.calories.CaloriesService/Suggestions"
        )
        XCTAssertEqual(
            WasmClient.Calories.ServiceMethod.ingredient.rawValue,
            "asyncify.calories.CaloriesService/Ingredient"
        )
    }

    // MARK: - Model defaults

    func testFoodResultDefaults() {
        let result = WasmClient.Calories.FoodResult()
        XCTAssertEqual(result.name, "")
        XCTAssertEqual(result.calories, 0)
        XCTAssertTrue(result.ingredients.isEmpty)
        XCTAssertTrue(result.metadata.isEmpty)
    }

    func testSearchResultDefaults() {
        XCTAssertTrue(WasmClient.Calories.SearchResult().items.isEmpty)
    }

    // MARK: - Mocks

    func testNoopReturnsEmpty() async throws {
        let analyze = try await WasmClient.noop.caloriesAnalyze(nil, "x", nil)
        XCTAssertEqual(analyze, WasmClient.Calories.FoodResult())
        let search = try await WasmClient.noop.caloriesSearch(nil, "x")
        XCTAssertEqual(search, WasmClient.Calories.SearchResult())
        let score = try await WasmClient.noop.caloriesHealthScore(nil, "x", nil, nil, nil, nil)
        XCTAssertEqual(score, WasmClient.Calories.HealthScore())
    }

    func testHappyReturnsPopulated() async throws {
        let analyze = try await WasmClient.happy.caloriesAnalyze(nil, "salad", nil)
        XCTAssertEqual(analyze.name, "Grilled Chicken Salad")
        XCTAssertEqual(analyze.ingredients.count, 1)

        let search = try await WasmClient.happy.caloriesSearch(nil, "banana")
        XCTAssertEqual(search.items.first?.name, "Banana")

        let score = try await WasmClient.happy.caloriesHealthScore(nil, "salad", 420, 38, 12, 24)
        XCTAssertEqual(score.rating, 7)
        XCTAssertEqual(score.tips, ["Add more vegetables"])
    }
}
