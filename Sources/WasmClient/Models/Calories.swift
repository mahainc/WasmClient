import Foundation

// MARK: - Calories Namespace

extension WasmClient {
    public enum Calories {}
}

// MARK: - ServiceMethod

extension WasmClient.Calories {
    // FlowKit service RPC method name (mirrors calories.fk.pb.swift).
    public struct ServiceMethod: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }

        public static let analyze = ServiceMethod(rawValue: "asyncify.calories.CaloriesService/Analyze")
        public static let search = ServiceMethod(rawValue: "asyncify.calories.CaloriesService/Search")
        public static let healthScore = ServiceMethod(rawValue: "asyncify.calories.CaloriesService/HealthScore")
        public static let barcode = ServiceMethod(rawValue: "asyncify.calories.CaloriesService/Barcode")
        public static let suggestions = ServiceMethod(rawValue: "asyncify.calories.CaloriesService/Suggestions")
        public static let ingredient = ServiceMethod(rawValue: "asyncify.calories.CaloriesService/Ingredient")
    }
}

// MARK: - Ingredient

extension WasmClient.Calories {
    public struct Ingredient: Sendable, Equatable, Identifiable {
        public let id: String
        public let name: String
        public let calories: Double
        public let protein: Double
        public let carbs: Double
        public let fats: Double
        public let amount: Double
        public let unit: String
        public let confidence: Double

        public init(
            id: String = "",
            name: String = "",
            calories: Double = 0,
            protein: Double = 0,
            carbs: Double = 0,
            fats: Double = 0,
            amount: Double = 0,
            unit: String = "",
            confidence: Double = 0
        ) {
            self.id = id
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
}

// MARK: - FoodResult

extension WasmClient.Calories {
    public struct FoodResult: Sendable, Equatable {
        public let name: String
        public let calories: Double
        public let protein: Double
        public let carbs: Double
        public let fats: Double
        public let sugar: Double
        public let fiber: Double
        public let sodium: Double
        public let servings: Double
        public let healthScore: Int
        public let ingredients: [Ingredient]
        public let metadata: [String: String]

        public init(
            name: String = "",
            calories: Double = 0,
            protein: Double = 0,
            carbs: Double = 0,
            fats: Double = 0,
            sugar: Double = 0,
            fiber: Double = 0,
            sodium: Double = 0,
            servings: Double = 0,
            healthScore: Int = 0,
            ingredients: [Ingredient] = [],
            metadata: [String: String] = [:]
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
            self.metadata = metadata
        }
    }
}

// MARK: - HealthScore

extension WasmClient.Calories {
    public struct HealthScore: Sendable, Equatable {
        public let rating: Int
        public let balance: String
        public let fullness: String
        public let goalFit: String
        public let message: String
        public let tips: [String]

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

// MARK: - ServingType

extension WasmClient.Calories {
    public struct ServingType: Sendable, Equatable, Identifiable {
        public let id: String
        public let label: String
        public let amount: Double
        public let unit: String
        public let calories: Double
        public let protein: Double
        public let carbs: Double
        public let fats: Double

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
}

// MARK: - FoodItem

extension WasmClient.Calories {
    public struct FoodItem: Sendable, Equatable, Identifiable {
        public let id: String
        public let name: String
        public let calories: Double
        public let protein: Double
        public let carbs: Double
        public let fats: Double
        public let brand: String
        public let servingTypes: [ServingType]

        public init(
            id: String = "",
            name: String = "",
            calories: Double = 0,
            protein: Double = 0,
            carbs: Double = 0,
            fats: Double = 0,
            brand: String = "",
            servingTypes: [ServingType] = []
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
}

// MARK: - SearchResult

extension WasmClient.Calories {
    public struct SearchResult: Sendable, Equatable {
        public let items: [FoodItem]

        public init(items: [FoodItem] = []) {
            self.items = items
        }
    }
}
