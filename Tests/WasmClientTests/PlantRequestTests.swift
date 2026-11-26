import XCTest

@testable import WasmClient

final class PlantRequestTests: XCTestCase {

    // MARK: - Wire constants

    func testServiceMethodRawValues() {
        XCTAssertEqual(WasmClient.Plant.ServiceMethod.list.rawValue, "asyncify.plant.PlantService/List")
        XCTAssertEqual(WasmClient.Plant.ServiceMethod.search.rawValue, "asyncify.plant.PlantService/Search")
        XCTAssertEqual(
            WasmClient.Plant.ServiceMethod.plantDetail.rawValue, "asyncify.plant.PlantService/PlantDetail"
        )
        XCTAssertEqual(WasmClient.Plant.ServiceMethod.complete.rawValue, "asyncify.plant.PlantService/Complete")
        XCTAssertEqual(
            WasmClient.Plant.ServiceMethod.waterCalc.rawValue, "asyncify.plant.PlantService/WaterCalc"
        )
        XCTAssertEqual(
            WasmClient.Plant.ServiceMethod.repottingChecker.rawValue,
            "asyncify.plant.PlantService/RepottingChecker"
        )
        XCTAssertEqual(
            WasmClient.Plant.ServiceMethod.lightMeter.rawValue, "asyncify.plant.PlantService/LightMeter"
        )
        XCTAssertEqual(WasmClient.Plant.ServiceMethod.diagnose.rawValue, "asyncify.plant.PlantService/Diagnose")
        XCTAssertEqual(WasmClient.Plant.ServiceMethod.weather.rawValue, "asyncify.plant.PlantService/Weather")
    }

    func testListTypeAndSeasonRawValues() {
        XCTAssertEqual(WasmClient.Plant.ListType.popular.rawValue, "PLANT_LIST_TYPE_POPULAR")
        XCTAssertEqual(WasmClient.Plant.ListType.nearby.rawValue, "PLANT_LIST_TYPE_NEARBY")
        XCTAssertEqual(WasmClient.Plant.ListType.season.rawValue, "PLANT_LIST_TYPE_SEASON")
        XCTAssertEqual(WasmClient.Plant.Season.spring.rawValue, "PLANT_SEASON_SPRING")
        XCTAssertEqual(WasmClient.Plant.Season.winter.rawValue, "PLANT_SEASON_WINTER")
    }

    // MARK: - Model defaults

    func testDefaults() {
        XCTAssertTrue(WasmClient.Plant.ListResult().plants.isEmpty)
        XCTAssertEqual(WasmClient.Plant.WaterCalc().frequencyDays, 0)
        XCTAssertTrue(WasmClient.Plant.DiagnoseResult().diseases.isEmpty)
        XCTAssertTrue(WasmClient.Plant.WeatherResult().forecast.isEmpty)
    }

    // MARK: - Mocks

    func testNoopReturnsEmpty() async throws {
        let list = try await WasmClient.noop.plantList(nil, nil, nil, nil, nil, nil, nil, nil)
        XCTAssertEqual(list, WasmClient.Plant.ListResult())
        let weather = try await WasmClient.noop.plantWeather(0, 0, nil, nil)
        XCTAssertEqual(weather, WasmClient.Plant.WeatherResult())
    }

    func testHappyReturnsPopulated() async throws {
        let list = try await WasmClient.happy.plantList(
            nil, .popular, nil, nil, nil, nil, nil, nil
        )
        XCTAssertEqual(list.plants.first?.commonNames, ["Carnation"])

        let diagnose = try await WasmClient.happy.plantDiagnose("img", nil, nil, nil, nil, [])
        XCTAssertEqual(diagnose.diseases.first?.name, "Brown Spot")

        let repot = try await WasmClient.happy.plantRepottingChecker("img", nil, nil)
        XCTAssertTrue(repot.isRepottable)
        XCTAssertEqual(repot.topics.first?.name, "Preparation")
    }
}
