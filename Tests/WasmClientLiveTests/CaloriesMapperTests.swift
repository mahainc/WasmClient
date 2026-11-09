import SwiftProtobuf
import XCTest

@testable import WasmClient
@testable import WasmClientLive

final class CaloriesMapperTests: XCTestCase {

    // MARK: - Provider arg

    func testSetProviderOmitsEmpty() {
        var args: [String: Google_Protobuf_Value] = [:]
        WasmActor.setProvider(nil, into: &args)
        WasmActor.setProvider("", into: &args)
        XCTAssertNil(args["provider_id"])

        WasmActor.setProvider("openai", into: &args)
        XCTAssertEqual(args["provider_id"]?.stringValue, "openai")
    }

    // MARK: - FoodResult mapping

    func testMapFoodResultMapsMacrosIngredientsAndMetadata() {
        var ingredient = CaloriesIngredient()
        ingredient.name = "grilled chicken"
        ingredient.calories = 230
        ingredient.amount = 150
        ingredient.unit = "g"

        var metadata = Google_Protobuf_Struct()
        metadata.fields["source"] = Google_Protobuf_Value(stringValue: "vision")

        var proto = CaloriesFoodResult()
        proto.name = "Chicken Caesar Salad"
        proto.calories = 420
        proto.protein = 38
        proto.carbs = 12
        proto.fats = 24
        proto.healthScore = 8
        proto.ingredients = [ingredient]
        proto.metadata = metadata

        let result = WasmActor.mapFoodResult(proto)
        XCTAssertEqual(result.name, "Chicken Caesar Salad")
        XCTAssertEqual(result.calories, 420)
        XCTAssertEqual(result.healthScore, 8)
        XCTAssertEqual(result.ingredients.count, 1)
        XCTAssertEqual(result.ingredients.first?.name, "grilled chicken")
        XCTAssertEqual(result.ingredients.first?.id, "grilled chicken")
        XCTAssertEqual(result.metadata, ["source": "vision"])
    }

    func testMapFoodResultEmptyMetadataWhenUnset() {
        let result = WasmActor.mapFoodResult(CaloriesFoodResult())
        XCTAssertEqual(result.metadata, [:])
        XCTAssertTrue(result.ingredients.isEmpty)
    }

    // MARK: - HealthScore mapping

    func testMapHealthScore() {
        var proto = CaloriesHealthScoreResult()
        proto.rating = 7
        proto.balance = "Well-balanced"
        proto.fullness = "Very filling"
        proto.goalFit = "Good for weight loss"
        proto.message = "Nice choice"
        proto.tips = ["Add greens", "Less sodium"]

        let score = WasmActor.mapHealthScore(proto)
        XCTAssertEqual(score.rating, 7)
        XCTAssertEqual(score.balance, "Well-balanced")
        XCTAssertEqual(score.tips, ["Add greens", "Less sodium"])
    }

    // MARK: - SearchResult mapping

    func testMapSearchResultMapsItemsAndServingTypes() {
        var serving = CaloriesServingType()
        serving.id = "s1"
        serving.label = "1 cup"
        serving.amount = 240
        serving.unit = "ml"
        serving.calories = 120

        var item = CaloriesFoodItem()
        item.id = "f1"
        item.name = "Banana"
        item.calories = 105
        item.brand = "Dole"
        item.servingTypes = [serving]

        var proto = CaloriesSearchResult()
        proto.items = [item]

        let result = WasmActor.mapSearchResult(proto)
        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items.first?.name, "Banana")
        XCTAssertEqual(result.items.first?.brand, "Dole")
        XCTAssertEqual(result.items.first?.servingTypes.first?.label, "1 cup")
        XCTAssertEqual(result.items.first?.servingTypes.first?.amount, 240)
    }

    func testMapEmptySearchResult() {
        XCTAssertTrue(WasmActor.mapSearchResult(CaloriesSearchResult()).items.isEmpty)
    }
}
