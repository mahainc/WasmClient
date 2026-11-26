@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Calories

extension WasmActor {
    func caloriesAnalyze(
        providerID: String?,
        text: String?,
        image: String?
    ) async throws -> WasmClient.Calories.FoodResult {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        Self.setProvider(providerID, into: &args)
        if let text, !text.isEmpty { args["text"] = Google_Protobuf_Value(stringValue: text) }
        if let image, !image.isEmpty { args["image"] = Google_Protobuf_Value(stringValue: image) }

        let resp: CaloriesFoodResult = try await instance.run(
            method: WasmClient.Calories.ServiceMethod.analyze.rawValue,
            providerId: providerID ?? "",
            args: args
        )
        return Self.mapFoodResult(resp)
    }

    func caloriesSearch(
        providerID: String?,
        query: String
    ) async throws -> WasmClient.Calories.SearchResult {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        Self.setProvider(providerID, into: &args)
        if !query.isEmpty { args["query"] = Google_Protobuf_Value(stringValue: query) }

        let resp: CaloriesSearchResult = try await instance.run(
            method: WasmClient.Calories.ServiceMethod.search.rawValue,
            providerId: providerID ?? "",
            args: args
        )
        return Self.mapSearchResult(resp)
    }

    func caloriesHealthScore(
        providerID: String?,
        name: String,
        calories: Double?,
        protein: Double?,
        carbs: Double?,
        fats: Double?
    ) async throws -> WasmClient.Calories.HealthScore {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        Self.setProvider(providerID, into: &args)
        if !name.isEmpty { args["name"] = Google_Protobuf_Value(stringValue: name) }
        if let calories { args["calories"] = Google_Protobuf_Value(numberValue: calories) }
        if let protein { args["protein"] = Google_Protobuf_Value(numberValue: protein) }
        if let carbs { args["carbs"] = Google_Protobuf_Value(numberValue: carbs) }
        if let fats { args["fats"] = Google_Protobuf_Value(numberValue: fats) }

        let resp: CaloriesHealthScoreResult = try await instance.run(
            method: WasmClient.Calories.ServiceMethod.healthScore.rawValue,
            providerId: providerID ?? "",
            args: args
        )
        return Self.mapHealthScore(resp)
    }

    func caloriesBarcode(
        providerID: String?,
        barcode: String
    ) async throws -> WasmClient.Calories.FoodResult {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        Self.setProvider(providerID, into: &args)
        if !barcode.isEmpty { args["barcode"] = Google_Protobuf_Value(stringValue: barcode) }

        let resp: CaloriesFoodResult = try await instance.run(
            method: WasmClient.Calories.ServiceMethod.barcode.rawValue,
            providerId: providerID ?? "",
            args: args
        )
        return Self.mapFoodResult(resp)
    }

    func caloriesSuggestions(
        providerID: String?
    ) async throws -> WasmClient.Calories.SearchResult {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        Self.setProvider(providerID, into: &args)

        let resp: CaloriesSearchResult = try await instance.run(
            method: WasmClient.Calories.ServiceMethod.suggestions.rawValue,
            providerId: providerID ?? "",
            args: args
        )
        return Self.mapSearchResult(resp)
    }

    func caloriesIngredient(
        providerID: String?,
        name: String
    ) async throws -> WasmClient.Calories.FoodResult {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        Self.setProvider(providerID, into: &args)
        if !name.isEmpty { args["name"] = Google_Protobuf_Value(stringValue: name) }

        let resp: CaloriesFoodResult = try await instance.run(
            method: WasmClient.Calories.ServiceMethod.ingredient.rawValue,
            providerId: providerID ?? "",
            args: args
        )
        return Self.mapFoodResult(resp)
    }

    // MARK: - Arg helpers

    static func setProvider(_ providerID: String?, into args: inout [String: Google_Protobuf_Value]) {
        guard let providerID, !providerID.isEmpty else { return }
        args["provider_id"] = Google_Protobuf_Value(stringValue: providerID)
    }

    // MARK: - Mapping

    static func mapFoodResult(_ proto: CaloriesFoodResult) -> WasmClient.Calories.FoodResult {
        WasmClient.Calories.FoodResult(
            name: proto.name,
            calories: proto.calories,
            protein: proto.protein,
            carbs: proto.carbs,
            fats: proto.fats,
            sugar: proto.sugar,
            fiber: proto.fiber,
            sodium: proto.sodium,
            servings: proto.servings,
            healthScore: Int(proto.healthScore),
            ingredients: proto.ingredients.map(mapIngredient),
            metadata: mapCaloriesMetadata(proto.hasMetadata ? proto.metadata : nil)
        )
    }

    static func mapIngredient(_ proto: CaloriesIngredient) -> WasmClient.Calories.Ingredient {
        WasmClient.Calories.Ingredient(
            id: proto.name,
            name: proto.name,
            calories: proto.calories,
            protein: proto.protein,
            carbs: proto.carbs,
            fats: proto.fats,
            amount: proto.amount,
            unit: proto.unit,
            confidence: proto.confidence
        )
    }

    static func mapHealthScore(_ proto: CaloriesHealthScoreResult) -> WasmClient.Calories.HealthScore {
        WasmClient.Calories.HealthScore(
            rating: Int(proto.rating),
            balance: proto.balance,
            fullness: proto.fullness,
            goalFit: proto.goalFit,
            message: proto.message,
            tips: proto.tips
        )
    }

    static func mapSearchResult(_ proto: CaloriesSearchResult) -> WasmClient.Calories.SearchResult {
        WasmClient.Calories.SearchResult(items: proto.items.map(mapFoodItem))
    }

    static func mapFoodItem(_ proto: CaloriesFoodItem) -> WasmClient.Calories.FoodItem {
        WasmClient.Calories.FoodItem(
            id: proto.id,
            name: proto.name,
            calories: proto.calories,
            protein: proto.protein,
            carbs: proto.carbs,
            fats: proto.fats,
            brand: proto.brand,
            servingTypes: proto.servingTypes.map(mapServingType)
        )
    }

    static func mapServingType(_ proto: CaloriesServingType) -> WasmClient.Calories.ServingType {
        WasmClient.Calories.ServingType(
            id: proto.id,
            label: proto.label,
            amount: proto.amount,
            unit: proto.unit,
            calories: proto.calories,
            protein: proto.protein,
            carbs: proto.carbs,
            fats: proto.fats
        )
    }

    static func mapCaloriesMetadata(_ metadata: Google_Protobuf_Struct?) -> [String: String] {
        guard let metadata else { return [:] }
        var result: [String: String] = [:]
        for (key, value) in metadata.fields {
            result[key] = value.stringValue
        }
        return result
    }
}
