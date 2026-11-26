import Foundation

// MARK: - Plant Namespace

extension WasmClient {
    public enum Plant {}
}

// MARK: - ServiceMethod

extension WasmClient.Plant {
    // FlowKit service RPC method name (mirrors plant.fk.pb.swift).
    public struct ServiceMethod: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }

        public static let list = ServiceMethod(rawValue: "asyncify.plant.PlantService/List")
        public static let search = ServiceMethod(rawValue: "asyncify.plant.PlantService/Search")
        public static let plantDetail = ServiceMethod(rawValue: "asyncify.plant.PlantService/PlantDetail")
        public static let complete = ServiceMethod(rawValue: "asyncify.plant.PlantService/Complete")
        public static let waterCalc = ServiceMethod(rawValue: "asyncify.plant.PlantService/WaterCalc")
        public static let repottingChecker = ServiceMethod(rawValue: "asyncify.plant.PlantService/RepottingChecker")
        public static let lightMeter = ServiceMethod(rawValue: "asyncify.plant.PlantService/LightMeter")
        public static let diagnose = ServiceMethod(rawValue: "asyncify.plant.PlantService/Diagnose")
        public static let weather = ServiceMethod(rawValue: "asyncify.plant.PlantService/Weather")
    }
}

// MARK: - ListType / Season (wire = SCREAMING_SNAKE protoName; empty = unspecified)

extension WasmClient.Plant {
    public struct ListType: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }

        public static let popular = ListType(rawValue: "PLANT_LIST_TYPE_POPULAR")
        public static let nearby = ListType(rawValue: "PLANT_LIST_TYPE_NEARBY")
        public static let season = ListType(rawValue: "PLANT_LIST_TYPE_SEASON")
    }

    public struct Season: RawRepresentable, Sendable, Equatable, Hashable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }

        public static let spring = Season(rawValue: "PLANT_SEASON_SPRING")
        public static let summer = Season(rawValue: "PLANT_SEASON_SUMMER")
        public static let autumn = Season(rawValue: "PLANT_SEASON_AUTUMN")
        public static let winter = Season(rawValue: "PLANT_SEASON_WINTER")
    }
}

// MARK: - Species

extension WasmClient.Plant {
    public struct Species: Sendable, Equatable, Identifiable {
        public let id: String
        public let latinName: String
        public let commonNames: [String]
        public let synonyms: [String]
        public let mainImageURL: String
        public let rank: Int
        public let weight: Double
        public let countryCodes: [String]
        public let seasonTags: [String]

        public init(
            id: String = "",
            latinName: String = "",
            commonNames: [String] = [],
            synonyms: [String] = [],
            mainImageURL: String = "",
            rank: Int = 0,
            weight: Double = 0,
            countryCodes: [String] = [],
            seasonTags: [String] = []
        ) {
            self.id = id
            self.latinName = latinName
            self.commonNames = commonNames
            self.synonyms = synonyms
            self.mainImageURL = mainImageURL
            self.rank = rank
            self.weight = weight
            self.countryCodes = countryCodes
            self.seasonTags = seasonTags
        }
    }
}

// MARK: - List / Search / Complete results

extension WasmClient.Plant {
    public struct ListResult: Sendable, Equatable {
        public let plants: [Species]
        public let total: Int

        public init(plants: [Species] = [], total: Int = 0) {
            self.plants = plants
            self.total = total
        }
    }
}

// MARK: - WaterCalc

extension WasmClient.Plant {
    public struct WaterCalc: Sendable, Equatable {
        public let waterAmountMl: Double
        public let frequencyDays: Int
        public let careType: String
        public let plantName: String
        public let latinName: String
        public let plantID: String
        public let raw: String

        public init(
            waterAmountMl: Double = 0,
            frequencyDays: Int = 0,
            careType: String = "",
            plantName: String = "",
            latinName: String = "",
            plantID: String = "",
            raw: String = ""
        ) {
            self.waterAmountMl = waterAmountMl
            self.frequencyDays = frequencyDays
            self.careType = careType
            self.plantName = plantName
            self.latinName = latinName
            self.plantID = plantID
            self.raw = raw
        }
    }
}

// MARK: - Repotting

extension WasmClient.Plant {
    public struct RepotSection: Sendable, Equatable {
        public let title: String
        public let content: String

        public init(title: String = "", content: String = "") {
            self.title = title
            self.content = content
        }
    }

    public struct RepotTopic: Sendable, Equatable, Identifiable {
        public let id: String
        public let name: String
        public let sections: [RepotSection]

        public init(name: String = "", sections: [RepotSection] = []) {
            self.id = name
            self.name = name
            self.sections = sections
        }
    }

    public struct RepottingResult: Sendable, Equatable {
        public let isPlant: Bool
        public let isRepottable: Bool
        public let status: String
        public let topics: [RepotTopic]
        public let raw: String

        public init(
            isPlant: Bool = false,
            isRepottable: Bool = false,
            status: String = "",
            topics: [RepotTopic] = [],
            raw: String = ""
        ) {
            self.isPlant = isPlant
            self.isRepottable = isRepottable
            self.status = status
            self.topics = topics
            self.raw = raw
        }
    }
}

// MARK: - LightMeter

extension WasmClient.Plant {
    public struct LightMeter: Sendable, Equatable {
        public let level: String
        public let lux: Double

        public init(level: String = "", lux: Double = 0) {
            self.level = level
            self.lux = lux
        }
    }
}

// MARK: - Diagnose

extension WasmClient.Plant {
    public struct DiseaseInfo: Sendable, Equatable, Identifiable {
        public let id: String
        public let name: String
        public let causes: [String]
        public let summary: String
        public let treatments: [String]
        public let confidence: Double
        public let bbox: [Double]

        public init(
            name: String = "",
            causes: [String] = [],
            summary: String = "",
            treatments: [String] = [],
            confidence: Double = 0,
            bbox: [Double] = []
        ) {
            self.id = name
            self.name = name
            self.causes = causes
            self.summary = summary
            self.treatments = treatments
            self.confidence = confidence
            self.bbox = bbox
        }
    }

    public struct CareSchedule: Sendable, Equatable, Identifiable {
        public let id: Int
        public let month: Int
        public let careList: [String: Int]

        public init(month: Int = 0, careList: [String: Int] = [:]) {
            self.id = month
            self.month = month
            self.careList = careList
        }
    }

    public struct Tip: Sendable, Equatable, Identifiable {
        public let id: String
        public let title: String
        public let content: String
        public let priority: Int

        public init(id: String = "", title: String = "", content: String = "", priority: Int = 0) {
            self.id = id
            self.title = title
            self.content = content
            self.priority = priority
        }
    }

    public struct DiagnoseResult: Sendable, Equatable {
        public let plantName: String
        public let latinName: String
        public let diseases: [DiseaseInfo]
        public let scene: [String: String]
        public let raw: String
        public let careSchedule: [CareSchedule]
        public let tips: [Tip]
        public let plantID: String
        public let healthImageURL: String
        public let diagnosisImageIndex: Int
        public let diseasedImageIndexes: [Int]

        public init(
            plantName: String = "",
            latinName: String = "",
            diseases: [DiseaseInfo] = [],
            scene: [String: String] = [:],
            raw: String = "",
            careSchedule: [CareSchedule] = [],
            tips: [Tip] = [],
            plantID: String = "",
            healthImageURL: String = "",
            diagnosisImageIndex: Int = 0,
            diseasedImageIndexes: [Int] = []
        ) {
            self.plantName = plantName
            self.latinName = latinName
            self.diseases = diseases
            self.scene = scene
            self.raw = raw
            self.careSchedule = careSchedule
            self.tips = tips
            self.plantID = plantID
            self.healthImageURL = healthImageURL
            self.diagnosisImageIndex = diagnosisImageIndex
            self.diseasedImageIndexes = diseasedImageIndexes
        }
    }
}

// MARK: - Weather

extension WasmClient.Plant {
    public struct WeatherDay: Sendable, Equatable, Identifiable {
        public let id: String
        public let day: String
        public let conditions: String
        public let temperatureMax: Double
        public let temperatureMin: Double
        public let temperature: Double
        public let conditionCode: Int
        public let iconURL: String

        public init(
            day: String = "",
            conditions: String = "",
            temperatureMax: Double = 0,
            temperatureMin: Double = 0,
            temperature: Double = 0,
            conditionCode: Int = 0,
            iconURL: String = ""
        ) {
            self.id = day
            self.day = day
            self.conditions = conditions
            self.temperatureMax = temperatureMax
            self.temperatureMin = temperatureMin
            self.temperature = temperature
            self.conditionCode = conditionCode
            self.iconURL = iconURL
        }
    }

    public struct ClimateMonth: Sendable, Equatable, Identifiable {
        public let id: Int
        public let month: Int
        public let temperatureMax: Double
        public let temperatureMin: Double
        public let temperatureAvg: Double

        public init(
            month: Int = 0,
            temperatureMax: Double = 0,
            temperatureMin: Double = 0,
            temperatureAvg: Double = 0
        ) {
            self.id = month
            self.month = month
            self.temperatureMax = temperatureMax
            self.temperatureMin = temperatureMin
            self.temperatureAvg = temperatureAvg
        }
    }

    public struct WeatherResult: Sendable, Equatable {
        public let forecast: [WeatherDay]
        public let temperatureYear: [ClimateMonth]
        public let hardinessZone: String
        public let climateClassification: String
        public let climateConfidence: Int
        public let seasonType: Int
        public let raw: String

        public init(
            forecast: [WeatherDay] = [],
            temperatureYear: [ClimateMonth] = [],
            hardinessZone: String = "",
            climateClassification: String = "",
            climateConfidence: Int = 0,
            seasonType: Int = 0,
            raw: String = ""
        ) {
            self.forecast = forecast
            self.temperatureYear = temperatureYear
            self.hardinessZone = hardinessZone
            self.climateClassification = climateClassification
            self.climateConfidence = climateConfidence
            self.seasonType = seasonType
            self.raw = raw
        }
    }
}

// MARK: - PlantDetail

extension WasmClient.Plant {
    public struct Detail: Sendable, Equatable, Identifiable {
        public let id: String
        public let preferredName: String
        public let latinName: String
        public let commonNames: [String]
        public let synonyms: [String]
        public let mainImageURL: String
        public let taxonomy: [String: String]
        public let facts: [String: String]
        public let gallery: [String]
        public let raw: String

        public init(
            uid: String = "",
            preferredName: String = "",
            latinName: String = "",
            commonNames: [String] = [],
            synonyms: [String] = [],
            mainImageURL: String = "",
            taxonomy: [String: String] = [:],
            facts: [String: String] = [:],
            gallery: [String] = [],
            raw: String = ""
        ) {
            self.id = uid
            self.preferredName = preferredName
            self.latinName = latinName
            self.commonNames = commonNames
            self.synonyms = synonyms
            self.mainImageURL = mainImageURL
            self.taxonomy = taxonomy
            self.facts = facts
            self.gallery = gallery
            self.raw = raw
        }
    }
}
