@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Calories / Nutrition

extension WasmActor {

    /// Analyze food from a text description.
    func analyzeFoodText(text: String) async throws -> WasmClient.FoodResult {
        let result = try await runFoodAnalysis(
            actionID: WasmClient.ActionID.caloriesAnalyze.rawValue,
            args: ["text": Google_Protobuf_Value(stringValue: text)]
        )
        return result
    }

    /// Analyze food from an image file URL (`file://` or `http(s)://`).
    ///
    /// Local `file://` URLs are not reachable by the analysis providers (they
    /// fetch the image server-side and 400 with "failed to read image"), so
    /// they are first uploaded to blobstore and analyzed via the hosted URL —
    /// the same upload-then-act pattern as the Scan flow.
    func analyzeFoodImage(imageURL: String) async throws -> WasmClient.FoodResult {
        var hostedURL = imageURL
        if imageURL.hasPrefix("file://") {
            guard let fileURL = URL(string: imageURL), let data = try? Data(contentsOf: fileURL) else {
                throw WasmClient.Error.uploadFailed("Cannot read local image at \(imageURL)")
            }
            hostedURL = try await uploadImage(imageData: data)
            logger("calories.analyze: uploaded local image (\(data.count) bytes) → \(hostedURL)")
        }
        return try await runFoodAnalysis(
            actionID: WasmClient.ActionID.caloriesAnalyze.rawValue,
            args: ["image": Google_Protobuf_Value(stringValue: hostedURL)]
        )
    }

    /// Lookup food by barcode.
    func scanFoodBarcode(barcode: String) async throws -> WasmClient.FoodResult {
        try await runFoodAnalysis(
            actionID: WasmClient.ActionID.caloriesBarcode.rawValue,
            args: ["barcode": Google_Protobuf_Value(stringValue: barcode)]
        )
    }

    /// Lookup a single raw ingredient by name.
    func ingredientLookup(name: String) async throws -> WasmClient.FoodResult {
        try await runFoodAnalysis(
            actionID: WasmClient.ActionID.caloriesIngredient.rawValue,
            args: ["name": Google_Protobuf_Value(stringValue: name)]
        )
    }

    /// Search for food items by name/query.
    func searchFood(query: String) async throws -> [WasmClient.FoodItem] {
        let items = try await runFoodSearch(
            actionID: WasmClient.ActionID.caloriesSearch.rawValue,
            args: ["query": Google_Protobuf_Value(stringValue: query)]
        )
        return items
    }

    /// Get food suggestions (popular/trending).
    func foodSuggestions() async throws -> [WasmClient.FoodItem] {
        try await runFoodSearch(
            actionID: WasmClient.ActionID.caloriesSuggestions.rawValue,
            args: [:]
        )
    }

    /// Get a health score / analytics for a food item.
    func foodHealthScore(
        name: String,
        calories: Double,
        protein: Double,
        carbs: Double,
        fats: Double
    ) async throws -> WasmClient.FoodHealthScore {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(
            actionID: WasmClient.ActionID.caloriesHealthScore.rawValue,
            logger: logger
        )
        var args: [String: Google_Protobuf_Value] = [
            "name": Google_Protobuf_Value(stringValue: name)
        ]
        if calories > 0 { args["calories"] = Google_Protobuf_Value(numberValue: calories) }
        if protein > 0 { args["protein"] = Google_Protobuf_Value(numberValue: protein) }
        if carbs > 0 { args["carbs"] = Google_Protobuf_Value(numberValue: carbs) }
        if fats > 0 { args["fats"] = Google_Protobuf_Value(numberValue: fats) }
        let task = try await instance.create(action: action, args: args)
        guard task.status == .completed, task.hasValue else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
        let proto = try CaloriesHealthScoreResult(unpackingAny: task.value)
        return Self.mapHealthScore(proto)
    }

    // MARK: - Shared runners

    private func runFoodAnalysis(
        actionID: String,
        args: [String: Google_Protobuf_Value]
    ) async throws -> WasmClient.FoodResult {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(actionID: actionID, logger: logger)
        logger(
            "calories.analyze: provider=\(action.provider) args=\(args.keys.sorted()) "
                + "image=\(Self.describeArg(args["image"])) text=\(Self.describeArg(args["text"]))"
        )
        let task = try await instance.create(action: action, args: args)
        guard task.status == .completed, task.hasValue else {
            // On failure the backend surfaces detail (e.g. HTTP 400 + message)
            // in the task metadata; log it and carry it in the thrown error.
            let detail = Self.failureDetail(task)
            logger("calories.analyze: FAILED status=\(task.status) detail=\(detail)")
            throw WasmClient.Error.taskFailed(status: detail)
        }
        let proto = try CaloriesFoodResult(unpackingAny: task.value)
        return Self.mapFoodResult(proto)
    }

    /// Pull whatever the backend reported on a failed task — the `error`
    /// metadata field (which carries the HTTP status / provider message) if
    /// present, otherwise the raw status. Mirrors HomedecorSession.
    private static func failureDetail(_ task: WaTTask) -> String {
        let fields = task.metadata.fields
        if let error = fields["error"]?.stringValue, !error.isEmpty {
            let code = fields["status"]?.stringValue ?? fields["statusCode"]?.stringValue
            return code.map { "\($0): \(error)" } ?? error
        }
        return "\(task.status)"
    }

    /// Short, log-safe description of an image/text arg (no base64 dumps).
    private static func describeArg(_ value: Google_Protobuf_Value?) -> String {
        guard let value, case .stringValue(let string) = value.kind else { return "nil" }
        if string.count > 80 { return "\(string.prefix(64))…(\(string.count) chars)" }
        return string
    }

    private func runFoodSearch(
        actionID: String,
        args: [String: Google_Protobuf_Value]
    ) async throws -> [WasmClient.FoodItem] {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(actionID: actionID, logger: logger)
        let task = try await instance.create(action: action, args: args)
        guard task.status == .completed, task.hasValue else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
        let proto = try CaloriesSearchResult(unpackingAny: task.value)
        return proto.items.map(Self.mapFoodItem)
    }

    // MARK: - Mapping (proto → pure model)

    private static func mapFoodResult(_ p: CaloriesFoodResult) -> WasmClient.FoodResult {
        WasmClient.FoodResult(
            name: p.name,
            calories: p.calories,
            protein: p.protein,
            carbs: p.carbs,
            fats: p.fats,
            sugar: p.hasSugar ? p.sugar : nil,
            fiber: p.hasFiber ? p.fiber : nil,
            sodium: p.hasSodium ? p.sodium : nil,
            servings: p.hasServings ? p.servings : nil,
            healthScore: p.hasHealthScore ? Int(p.healthScore) : nil,
            ingredients: p.ingredients.map(mapIngredient)
        )
    }

    private static func mapIngredient(_ i: CaloriesIngredient) -> WasmClient.FoodIngredient {
        WasmClient.FoodIngredient(
            name: i.name,
            calories: i.calories,
            protein: i.protein,
            carbs: i.carbs,
            fats: i.fats,
            amount: i.hasAmount ? i.amount : nil,
            unit: i.hasUnit ? i.unit : nil,
            confidence: i.hasConfidence ? i.confidence : nil
        )
    }

    private static func mapFoodItem(_ i: CaloriesFoodItem) -> WasmClient.FoodItem {
        WasmClient.FoodItem(
            id: i.id,
            name: i.name,
            calories: i.calories,
            protein: i.protein,
            carbs: i.carbs,
            fats: i.fats,
            brand: i.hasBrand ? i.brand : nil,
            servingTypes: i.servingTypes.map(mapServingType)
        )
    }

    private static func mapServingType(_ s: CaloriesServingType) -> WasmClient.FoodServingType {
        WasmClient.FoodServingType(
            id: s.id,
            label: s.label,
            amount: s.amount,
            unit: s.unit,
            calories: s.calories,
            protein: s.protein,
            carbs: s.carbs,
            fats: s.fats
        )
    }

    private static func mapHealthScore(_ h: CaloriesHealthScoreResult) -> WasmClient.FoodHealthScore {
        WasmClient.FoodHealthScore(
            rating: Int(h.rating),
            balance: h.balance,
            fullness: h.fullness,
            goalFit: h.goalFit,
            message: h.message,
            tips: h.tips
        )
    }
}
