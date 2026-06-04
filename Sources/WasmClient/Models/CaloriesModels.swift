import Foundation

extension WasmClient {
    /// Full nutrition analysis for a food/meal — returned by analyze (text/image),
    /// barcode lookup, and ingredient lookup. Normalized across providers.
    public struct FoodResult: Sendable, Equatable {
        /// Display name of the food (e.g. "Chicken Caesar Salad").
        public var name: String
        /// Total calories in kcal for the analyzed portion.
        public var calories: Double
        /// Total protein in grams.
        public var protein: Double
        /// Total carbohydrates in grams.
        public var carbs: Double
        /// Total fats in grams.
        public var fats: Double
        /// Total sugar in grams (not all providers return this).
        public var sugar: Double?
        /// Total dietary fiber in grams.
        public var fiber: Double?
        /// Total sodium in milligrams.
        public var sodium: Double?
        /// Number of servings the macros represent (e.g. 1.0 = single serving).
        public var servings: Double?
        /// Provider's healthiness rating on a 1-10 scale (higher = healthier).
        public var healthScore: Int?
        /// Breakdown of individual ingredients with per-ingredient macros.
        public var ingredients: [FoodIngredient]

        public init(
            name: String = "",
            calories: Double = 0,
            protein: Double = 0,
            carbs: Double = 0,
            fats: Double = 0,
            sugar: Double? = nil,
            fiber: Double? = nil,
            sodium: Double? = nil,
            servings: Double? = nil,
            healthScore: Int? = nil,
            ingredients: [FoodIngredient] = []
        ) {
            self.name = name
            self.calories = calories
            self.protein = protein
            self.carbs = carbs
            self.fats = fats
            self.sugar = sugar
            self.fiber = fiber
            self.sodium = sodium
            self.servings = servings
            self.healthScore = healthScore
            self.ingredients = ingredients
        }
    }

    /// A single ingredient within a FoodResult breakdown.
    public struct FoodIngredient: Sendable, Equatable {
        /// Ingredient name (e.g. "romaine lettuce", "grilled chicken").
        public var name: String
        /// Calories in kcal for this ingredient's portion.
        public var calories: Double
        /// Protein in grams.
        public var protein: Double
        /// Carbohydrates in grams.
        public var carbs: Double
        /// Fats in grams.
        public var fats: Double
        /// Quantity of this ingredient (e.g. 150.0 for 150g).
        public var amount: Double?
        /// Unit of the amount (e.g. "g", "ml", "oz", "cup").
        public var unit: String?
        /// Provider's confidence in this ingredient identification (0.0-1.0).
        public var confidence: Double?

        public init(
            name: String = "",
            calories: Double = 0,
            protein: Double = 0,
            carbs: Double = 0,
            fats: Double = 0,
            amount: Double? = nil,
            unit: String? = nil,
            confidence: Double? = nil
        ) {
            self.name = name
            self.calories = calories
            self.protein = protein
            self.carbs = carbs
            self.fats = fats
            self.amount = amount
            self.unit = unit
            self.confidence = confidence
        }
    }

    /// A food item from search/suggestions — lighter than FoodResult
    /// (summary macros, no ingredient breakdown).
    public struct FoodItem: Sendable, Equatable, Identifiable {
        /// Provider-specific unique identifier for this food item.
        public var id: String
        /// Display name (e.g. "Banana", "Coca-Cola Classic 330ml").
        public var name: String
        /// Calories in kcal per default serving.
        public var calories: Double
        /// Protein in grams per default serving.
        public var protein: Double
        /// Carbohydrates in grams per default serving.
        public var carbs: Double
        /// Fats in grams per default serving.
        public var fats: Double
        /// Brand name if this is a branded/packaged product.
        public var brand: String?
        /// Available serving sizes with pre-calculated macros for each.
        public var servingTypes: [FoodServingType]

        public init(
            id: String = "",
            name: String = "",
            calories: Double = 0,
            protein: Double = 0,
            carbs: Double = 0,
            fats: Double = 0,
            brand: String? = nil,
            servingTypes: [FoodServingType] = []
        ) {
            self.id = id
            self.name = name
            self.calories = calories
            self.protein = protein
            self.carbs = carbs
            self.fats = fats
            self.brand = brand
            self.servingTypes = servingTypes
        }
    }

    /// A specific serving size option for a food item, with pre-calculated macros.
    public struct FoodServingType: Sendable, Equatable, Identifiable {
        /// Provider-specific identifier for this serving type.
        public var id: String
        /// Human-readable label (e.g. "1 cup", "100g", "1 medium").
        public var label: String
        /// Numeric amount in the specified unit (e.g. 240.0 for 240ml).
        public var amount: Double
        /// Unit of measurement (e.g. "g", "ml", "piece").
        public var unit: String
        /// Calories in kcal for this serving size.
        public var calories: Double
        /// Protein in grams for this serving size.
        public var protein: Double
        /// Carbohydrates in grams for this serving size.
        public var carbs: Double
        /// Fats in grams for this serving size.
        public var fats: Double

        public init(
            id: String = "",
            label: String = "",
            amount: Double = 0,
            unit: String = "",
            calories: Double = 0,
            protein: Double = 0,
            carbs: Double = 0,
            fats: Double = 0
        ) {
            self.id = id
            self.label = label
            self.amount = amount
            self.unit = unit
            self.calories = calories
            self.protein = protein
            self.carbs = carbs
            self.fats = fats
        }
    }

    /// Health score / analytics result for a specific food item.
    public struct FoodHealthScore: Sendable, Equatable {
        /// Overall health rating on a 1-10 scale (higher = healthier).
        public var rating: Int
        /// Nutritional balance assessment (e.g. "Well-balanced", "High in carbs").
        public var balance: String
        /// Satiety/fullness assessment (e.g. "Very filling", "Light meal").
        public var fullness: String
        /// How well the food fits typical health goals (e.g. "Good for weight loss").
        public var goalFit: String
        /// Summary message from the provider's analysis.
        public var message: String
        /// Actionable improvement tips (e.g. "Add more vegetables", "Reduce sodium").
        public var tips: [String]

        public init(
            rating: Int = 0,
            balance: String = "",
            fullness: String = "",
            goalFit: String = "",
            message: String = "",
            tips: [String] = []
        ) {
            self.rating = rating
            self.balance = balance
            self.fullness = fullness
            self.goalFit = goalFit
            self.message = message
            self.tips = tips
        }
    }
}
