import SwiftProtobuf
import XCTest

@testable import WasmClient
@testable import WasmClientLive

final class PlantMapperTests: XCTestCase {

    // MARK: - Locale args

    func testSetLocaleOmitsEmpty() {
        var args: [String: Google_Protobuf_Value] = [:]
        WasmActor.setLocale(languageCode: nil, countryCode: "", into: &args)
        XCTAssertTrue(args.isEmpty)

        WasmActor.setLocale(languageCode: "en", countryCode: "US", into: &args)
        XCTAssertEqual(args["language_code"]?.stringValue, "en")
        XCTAssertEqual(args["country_code"]?.stringValue, "US")
    }

    // MARK: - Species

    func testMapSpecies() {
        var proto = PlantPlantSpecies()
        proto.uid = "u1"
        proto.latinName = "Rosa"
        proto.commonNames = ["Rose"]
        proto.rank = 3
        proto.seasonTags = ["spring"]

        let species = WasmActor.mapSpecies(proto)
        XCTAssertEqual(species.id, "u1")
        XCTAssertEqual(species.latinName, "Rosa")
        XCTAssertEqual(species.commonNames, ["Rose"])
        XCTAssertEqual(species.rank, 3)
        XCTAssertEqual(species.seasonTags, ["spring"])
    }

    // MARK: - WaterCalc

    func testMapWaterCalc() {
        var proto = PlantWaterCalcResult()
        proto.waterAmountMl = 250
        proto.frequencyDays = 7
        proto.careType = "moderate"
        proto.plantName = "Carnation"

        let result = WasmActor.mapWaterCalc(proto)
        XCTAssertEqual(result.waterAmountMl, 250)
        XCTAssertEqual(result.frequencyDays, 7)
        XCTAssertEqual(result.careType, "moderate")
    }

    // MARK: - Repotting (nested topics/sections)

    func testMapRepotting() {
        var section = PlantRepotTopicSection()
        section.title = "How to repot"
        section.content = "Loosen the roots"

        var topic = PlantRepotTopic()
        topic.name = "Preparation"
        topic.sections = [section]

        var proto = PlantRepottingCheckerResult()
        proto.isPlant = true
        proto.isRepottable = true
        proto.topics = [topic]

        let result = WasmActor.mapRepotting(proto)
        XCTAssertTrue(result.isRepottable)
        XCTAssertEqual(result.topics.first?.name, "Preparation")
        XCTAssertEqual(result.topics.first?.sections.first?.title, "How to repot")
    }

    // MARK: - Diagnose (diseases, careSchedule, tips)

    func testMapDiagnose() {
        var disease = PlantDiseaseInfo()
        disease.name = "Brown Spot"
        disease.causes = ["Poor ventilation"]
        disease.confidence = 0.8
        disease.bbox = [0.1, 0.2, 0.3, 0.4]

        var schedule = PlantCareSchedule()
        schedule.month = 6
        schedule.careList = ["watering": 3, "fertilize": -1]

        var tip = PlantTip()
        tip.id = "t1"
        tip.title = "Pruning time?"
        tip.priority = 2

        var proto = PlantDiagnoseResult()
        proto.plantName = "Carnation"
        proto.diseases = [disease]
        proto.scene = ["care_situation": "bad_care"]
        proto.careSchedule = [schedule]
        proto.tips = [tip]
        proto.diseasedImageIndexes = [0, 2]

        let result = WasmActor.mapDiagnose(proto)
        XCTAssertEqual(result.diseases.first?.name, "Brown Spot")
        XCTAssertEqual(result.diseases.first?.bbox, [0.1, 0.2, 0.3, 0.4])
        XCTAssertEqual(result.scene, ["care_situation": "bad_care"])
        XCTAssertEqual(result.careSchedule.first?.month, 6)
        XCTAssertEqual(result.careSchedule.first?.careList["watering"], 3)
        XCTAssertEqual(result.tips.first?.title, "Pruning time?")
        XCTAssertEqual(result.diseasedImageIndexes, [0, 2])
    }

    // MARK: - Weather

    func testMapWeather() {
        var day = PlantWeatherDay()
        day.day = "2026-06-25"
        day.conditions = "Partially cloudy"
        day.temperature = 24

        var month = PlantClimateMonth()
        month.month = 6
        month.temperatureAvg = 22

        var proto = PlantWeatherResult()
        proto.forecast = [day]
        proto.temperatureYear = [month]
        proto.hardinessZone = "7b"
        proto.climateClassification = "Aw"

        let result = WasmActor.mapWeather(proto)
        XCTAssertEqual(result.forecast.first?.day, "2026-06-25")
        XCTAssertEqual(result.forecast.first?.temperature, 24)
        XCTAssertEqual(result.temperatureYear.first?.temperatureAvg, 22)
        XCTAssertEqual(result.hardinessZone, "7b")
        XCTAssertEqual(result.climateClassification, "Aw")
    }

    // MARK: - Detail

    func testMapDetail() {
        var proto = PlantPlantDetailResult()
        proto.uid = "u1"
        proto.preferredName = "Carnation"
        proto.latinName = "Dianthus caryophyllus"
        proto.taxonomy = ["Genus": "Dianthus"]
        proto.facts = ["toxicity": "mild"]

        let detail = WasmActor.mapDetail(proto)
        XCTAssertEqual(detail.id, "u1")
        XCTAssertEqual(detail.preferredName, "Carnation")
        XCTAssertEqual(detail.taxonomy, ["Genus": "Dianthus"])
        XCTAssertEqual(detail.facts, ["toxicity": "mild"])
    }
}
