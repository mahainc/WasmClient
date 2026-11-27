@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Plant

extension WasmActor {
    func plantList(
        query: String?,
        listType: WasmClient.Plant.ListType?,
        latitude: Double?,
        longitude: Double?,
        season: WasmClient.Plant.Season?,
        month: Int?,
        limit: Int?,
        offset: Int?
    ) async throws -> WasmClient.Plant.ListResult {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if let query, !query.isEmpty { args["query"] = Google_Protobuf_Value(stringValue: query) }
        if let listType, !listType.rawValue.isEmpty {
            args["list_type"] = Google_Protobuf_Value(stringValue: listType.rawValue)
        }
        if let latitude { args["latitude"] = Google_Protobuf_Value(numberValue: latitude) }
        if let longitude { args["longitude"] = Google_Protobuf_Value(numberValue: longitude) }
        if let season, !season.rawValue.isEmpty {
            args["season"] = Google_Protobuf_Value(stringValue: season.rawValue)
        }
        if let month { args["month"] = Google_Protobuf_Value(numberValue: Double(month)) }
        if let limit { args["limit"] = Google_Protobuf_Value(numberValue: Double(limit)) }
        if let offset { args["offset"] = Google_Protobuf_Value(numberValue: Double(offset)) }

        let resp: PlantListResult = try await instance.run(
            method: WasmClient.Plant.ServiceMethod.list.rawValue,
            args: args
        )
        return WasmClient.Plant.ListResult(
            plants: resp.plants.map(Self.mapSpecies),
            total: Int(resp.total)
        )
    }

    func plantSearch(
        searchText: String,
        languageCode: String?,
        countryCode: String?
    ) async throws -> [WasmClient.Plant.Species] {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !searchText.isEmpty { args["search_text"] = Google_Protobuf_Value(stringValue: searchText) }
        Self.setLocale(languageCode: languageCode, countryCode: countryCode, into: &args)

        let resp: PlantSearchResult = try await instance.run(
            method: WasmClient.Plant.ServiceMethod.search.rawValue,
            args: args
        )
        return resp.species.map(Self.mapSpecies)
    }

    func plantComplete(
        searchText: String,
        languageCode: String?,
        countryCode: String?
    ) async throws -> [WasmClient.Plant.Species] {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !searchText.isEmpty { args["search_text"] = Google_Protobuf_Value(stringValue: searchText) }
        Self.setLocale(languageCode: languageCode, countryCode: countryCode, into: &args)

        let resp: PlantCompleteResult = try await instance.run(
            method: WasmClient.Plant.ServiceMethod.complete.rawValue,
            args: args
        )
        return resp.suggestions.map(Self.mapSpecies)
    }

    func plantDetail(
        uid: String,
        languageCode: String?,
        countryCode: String?
    ) async throws -> WasmClient.Plant.Detail {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !uid.isEmpty { args["uid"] = Google_Protobuf_Value(stringValue: uid) }
        Self.setLocale(languageCode: languageCode, countryCode: countryCode, into: &args)

        let resp: PlantPlantDetailResult = try await instance.run(
            method: WasmClient.Plant.ServiceMethod.plantDetail.rawValue,
            args: args
        )
        return Self.mapDetail(resp)
    }

    func plantWaterCalc(
        file: String?,
        plantID: String?,
        settings: String?,
        countryCode: String?,
        latitude: Double?,
        longitude: Double?
    ) async throws -> WasmClient.Plant.WaterCalc {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if let file, !file.isEmpty { args["file"] = Google_Protobuf_Value(stringValue: file) }
        if let plantID, !plantID.isEmpty { args["plant_id"] = Google_Protobuf_Value(stringValue: plantID) }
        if let settings, !settings.isEmpty { args["settings"] = Google_Protobuf_Value(stringValue: settings) }
        if let countryCode, !countryCode.isEmpty {
            args["country_code"] = Google_Protobuf_Value(stringValue: countryCode)
        }
        if let latitude { args["latitude"] = Google_Protobuf_Value(numberValue: latitude) }
        if let longitude { args["longitude"] = Google_Protobuf_Value(numberValue: longitude) }

        let resp: PlantWaterCalcResult = try await instance.run(
            method: WasmClient.Plant.ServiceMethod.waterCalc.rawValue,
            args: args
        )
        return Self.mapWaterCalc(resp)
    }

    func plantRepottingChecker(
        file: String,
        plantID: String?,
        plantName: String?
    ) async throws -> WasmClient.Plant.RepottingResult {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !file.isEmpty { args["file"] = Google_Protobuf_Value(stringValue: file) }
        if let plantID, !plantID.isEmpty { args["plant_id"] = Google_Protobuf_Value(stringValue: plantID) }
        if let plantName, !plantName.isEmpty {
            args["plant_name"] = Google_Protobuf_Value(stringValue: plantName)
        }

        let resp: PlantRepottingCheckerResult = try await instance.run(
            method: WasmClient.Plant.ServiceMethod.repottingChecker.rawValue,
            args: args
        )
        return Self.mapRepotting(resp)
    }

    func plantLightMeter(
        brightness: Double?,
        file: String?
    ) async throws -> WasmClient.Plant.LightMeter {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if let brightness { args["brightness"] = Google_Protobuf_Value(numberValue: brightness) }
        if let file, !file.isEmpty { args["file"] = Google_Protobuf_Value(stringValue: file) }

        let resp: PlantLightMeterResult = try await instance.run(
            method: WasmClient.Plant.ServiceMethod.lightMeter.rawValue,
            args: args
        )
        return WasmClient.Plant.LightMeter(level: resp.level, lux: resp.lux)
    }

    func plantDiagnose(
        file: String,
        plantID: String?,
        countryCode: String?,
        latitude: Double?,
        longitude: Double?,
        additionalFiles: [String]
    ) async throws -> WasmClient.Plant.DiagnoseResult {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [:]
        if !file.isEmpty { args["file"] = Google_Protobuf_Value(stringValue: file) }
        if let plantID, !plantID.isEmpty { args["plant_id"] = Google_Protobuf_Value(stringValue: plantID) }
        if let countryCode, !countryCode.isEmpty {
            args["country_code"] = Google_Protobuf_Value(stringValue: countryCode)
        }
        if let latitude { args["latitude"] = Google_Protobuf_Value(numberValue: latitude) }
        if let longitude { args["longitude"] = Google_Protobuf_Value(numberValue: longitude) }
        if !additionalFiles.isEmpty {
            args["additional_files"] = Google_Protobuf_Value(stringValue: additionalFiles.joined(separator: ","))
        }

        let resp: PlantDiagnoseResult = try await instance.run(
            method: WasmClient.Plant.ServiceMethod.diagnose.rawValue,
            args: args
        )
        return Self.mapDiagnose(resp)
    }

    func plantWeather(
        latitude: Double,
        longitude: Double,
        countryCode: String?,
        day: String?
    ) async throws -> WasmClient.Plant.WeatherResult {
        let instance = try await readyEngine()
        var args: [String: Google_Protobuf_Value] = [
            "latitude": Google_Protobuf_Value(numberValue: latitude),
            "longitude": Google_Protobuf_Value(numberValue: longitude),
        ]
        if let countryCode, !countryCode.isEmpty {
            args["country_code"] = Google_Protobuf_Value(stringValue: countryCode)
        }
        if let day, !day.isEmpty { args["day"] = Google_Protobuf_Value(stringValue: day) }

        let resp: PlantWeatherResult = try await instance.run(
            method: WasmClient.Plant.ServiceMethod.weather.rawValue,
            args: args
        )
        return Self.mapWeather(resp)
    }

    // MARK: - Arg helpers

    static func setLocale(
        languageCode: String?,
        countryCode: String?,
        into args: inout [String: Google_Protobuf_Value]
    ) {
        if let languageCode, !languageCode.isEmpty {
            args["language_code"] = Google_Protobuf_Value(stringValue: languageCode)
        }
        if let countryCode, !countryCode.isEmpty {
            args["country_code"] = Google_Protobuf_Value(stringValue: countryCode)
        }
    }

    // MARK: - Mapping

    static func mapSpecies(_ proto: PlantPlantSpecies) -> WasmClient.Plant.Species {
        WasmClient.Plant.Species(
            id: proto.uid,
            latinName: proto.latinName,
            commonNames: proto.commonNames,
            synonyms: proto.synonyms,
            mainImageURL: proto.mainImageURL,
            rank: Int(proto.rank),
            weight: proto.weight,
            countryCodes: proto.countryCodes,
            seasonTags: proto.seasonTags
        )
    }

    static func mapWaterCalc(_ proto: PlantWaterCalcResult) -> WasmClient.Plant.WaterCalc {
        WasmClient.Plant.WaterCalc(
            waterAmountMl: proto.waterAmountMl,
            frequencyDays: Int(proto.frequencyDays),
            careType: proto.careType,
            plantName: proto.plantName,
            latinName: proto.latinName,
            plantID: proto.plantID,
            raw: proto.raw
        )
    }

    static func mapRepotting(_ proto: PlantRepottingCheckerResult) -> WasmClient.Plant.RepottingResult {
        WasmClient.Plant.RepottingResult(
            isPlant: proto.isPlant,
            isRepottable: proto.isRepottable,
            status: proto.status,
            topics: proto.topics.map { topic in
                WasmClient.Plant.RepotTopic(
                    name: topic.name,
                    sections: topic.sections.map {
                        WasmClient.Plant.RepotSection(title: $0.title, content: $0.content)
                    }
                )
            },
            raw: proto.raw
        )
    }

    static func mapDiagnose(_ proto: PlantDiagnoseResult) -> WasmClient.Plant.DiagnoseResult {
        WasmClient.Plant.DiagnoseResult(
            plantName: proto.plantName,
            latinName: proto.latinName,
            diseases: proto.diseases.map { disease in
                WasmClient.Plant.DiseaseInfo(
                    name: disease.name,
                    causes: disease.causes,
                    summary: disease.summary,
                    treatments: disease.treatments,
                    confidence: disease.confidence,
                    bbox: disease.bbox
                )
            },
            scene: proto.scene,
            raw: proto.raw,
            careSchedule: proto.careSchedule.map { schedule in
                WasmClient.Plant.CareSchedule(
                    month: Int(schedule.month),
                    careList: schedule.careList.mapValues(Int.init)
                )
            },
            tips: proto.tips.map { tip in
                WasmClient.Plant.Tip(
                    id: tip.id, title: tip.title, content: tip.content, priority: Int(tip.priority)
                )
            },
            plantID: proto.plantID,
            healthImageURL: proto.healthImageURL,
            diagnosisImageIndex: Int(proto.diagnosisImageIndex),
            diseasedImageIndexes: proto.diseasedImageIndexes.map(Int.init)
        )
    }

    static func mapWeather(_ proto: PlantWeatherResult) -> WasmClient.Plant.WeatherResult {
        WasmClient.Plant.WeatherResult(
            forecast: proto.forecast.map { day in
                WasmClient.Plant.WeatherDay(
                    day: day.day,
                    conditions: day.conditions,
                    temperatureMax: day.temperatureMax,
                    temperatureMin: day.temperatureMin,
                    temperature: day.temperature,
                    conditionCode: Int(day.conditionCode),
                    iconURL: day.iconURL
                )
            },
            temperatureYear: proto.temperatureYear.map { month in
                WasmClient.Plant.ClimateMonth(
                    month: Int(month.month),
                    temperatureMax: month.temperatureMax,
                    temperatureMin: month.temperatureMin,
                    temperatureAvg: month.temperatureAvg
                )
            },
            hardinessZone: proto.hardinessZone,
            climateClassification: proto.climateClassification,
            climateConfidence: Int(proto.climateConfidence),
            seasonType: Int(proto.seasonType),
            raw: proto.raw
        )
    }

    static func mapDetail(_ proto: PlantPlantDetailResult) -> WasmClient.Plant.Detail {
        WasmClient.Plant.Detail(
            uid: proto.uid,
            preferredName: proto.preferredName,
            latinName: proto.latinName,
            commonNames: proto.commonNames,
            synonyms: proto.synonyms,
            mainImageURL: proto.mainImageURL,
            taxonomy: proto.taxonomy,
            facts: proto.facts,
            gallery: proto.gallery,
            raw: proto.raw
        )
    }
}
