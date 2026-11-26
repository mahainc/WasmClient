import XCTest

@testable import WasmClient

final class AIArtRequestTests: XCTestCase {

    func testStyleUnspecifiedUsesEmptyRawValue() {
        XCTAssertEqual(WasmClient.AIArt.Style.unspecified.rawValue, "")
    }

    func testImageRequestKindRawValues() {
        XCTAssertEqual(WasmClient.AIArt.ImageRequest.Kind.normal.rawValue, "NORMAL")
        XCTAssertEqual(WasmClient.AIArt.ImageRequest.Kind.stamp.rawValue, "STAMPS")
        XCTAssertEqual(WasmClient.AIArt.ImageRequest.Kind.modCar.rawValue, "MOD_CAR")
    }

    func testServiceMethodListModelsRawValue() {
        XCTAssertEqual(
            WasmClient.AIArt.ServiceMethod.listModels.rawValue,
            "asyncify.aiart.AiartService/ListModels"
        )
    }

    func testImageRequestWireArgsDropsEmptyDefaults() {
        let request = WasmClient.AIArt.ImageRequest(prompt: "A sunset")

        XCTAssertEqual(request.toWireArgs(), ["prompt": "A sunset"])
    }

    func testImageRequestWireArgsMapsModelAndFields() {
        let model = WasmClient.AIArt.Model(
            id: "flux-pro",
            name: "Flux Pro",
            providerID: "provider-1",
            aspectRatios: ["1:1", "16:9"]
        )
        let request = WasmClient.AIArt.ImageRequest(
            kind: .normal,
            prompt: "A mountain",
            style: .watercolor,
            image: .url("https://example.com/input.png"),
            model: model,
            aspectRatio: "16:9",
            numberOfImages: 2
        )

        XCTAssertEqual(
            request.toWireArgs(),
            [
                "prompt": "A mountain",
                "style": "WATERCOLOR",
                "image_url": "https://example.com/input.png",
                "model": "flux-pro",
                "aspect_ratio": "16:9",
                "num_images": "2",
            ]
        )
    }

    func testImageReferencePathMapsToImagePath() {
        let request = WasmClient.AIArt.ImageRequest(
            prompt: "Edit this",
            image: .path("file:///tmp/input.png")
        )

        XCTAssertEqual(request.toWireArgs()["image_path"], "file:///tmp/input.png")
        XCTAssertNil(request.toWireArgs()["image_url"])
    }

    func testImageRequestExtraArgsMergeLastAndOverrideGeneratedKeys() {
        let request = WasmClient.AIArt.ImageRequest(
            prompt: "original",
            style: .anime,
            extraArgs: [
                "prompt": "override",
                "style": "PHOTOREAL",
                "custom": "value",
                "empty": "",
            ]
        )

        XCTAssertEqual(
            request.toWireArgs(),
            [
                "prompt": "override",
                "style": "PHOTOREAL",
                "custom": "value",
            ]
        )
    }

    func testModCarUsesSameImageRequestShape() {
        let model = WasmClient.AIArt.Model(id: "car-model", name: "Car Model")
        let request = WasmClient.AIArt.ImageRequest(
            kind: .modCar,
            prompt: "red sports car",
            style: .photoreal,
            image: .path("file:///tmp/car.png"),
            model: model,
            aspectRatio: "1:1"
        )

        let args = request.toWireArgs()
        XCTAssertEqual(request.kind, .modCar)
        XCTAssertNil(args["kind"])
        XCTAssertNil(args["mode"])
        XCTAssertEqual(args["prompt"], "red sports car")
        XCTAssertEqual(args["style"], "PHOTOREAL")
        XCTAssertEqual(args["image_path"], "file:///tmp/car.png")
        XCTAssertEqual(args["model"], "car-model")
        XCTAssertEqual(args["aspect_ratio"], "1:1")
    }

    func testModelCatalogDefaultModel() {
        let first = WasmClient.AIArt.Model(id: "first", name: "First")
        let second = WasmClient.AIArt.Model(id: "second", name: "Second")
        let catalog = WasmClient.AIArt.ModelCatalog(
            models: [first, second],
            defaultModelID: "second"
        )

        XCTAssertEqual(catalog.defaultModel, second)
    }

    func testRequestsConformToWireRequest() {
        func assertWireRequest<T: WasmClient.AIArt.WireRequest>(_: T.Type) {}

        assertWireRequest(WasmClient.AIArt.ImageRequest.self)
        assertWireRequest(WasmClient.AIArt.VideoRequest.self)
    }

    func testVideoRequestWireArgs() {
        let request = WasmClient.AIArt.VideoRequest(
            imagePath: "file:///tmp/avatar.png",
            artStyle: "Ghibli",
            audioPath: "file:///tmp/audio.m4a",
            extraArgs: ["cache_dir": "/tmp/cache"]
        )

        XCTAssertEqual(
            request.toWireArgs(),
            [
                "image_path": "file:///tmp/avatar.png",
                "art_style": "Ghibli",
                "audio_path": "file:///tmp/audio.m4a",
                "cache_dir": "/tmp/cache",
            ]
        )
    }

    func testHappyMockUsesNewAIArtTypes() async throws {
        let client = WasmClient.happy

        let image = try await client.generateAIArt(.init(prompt: "A forest", style: .fantasy))
        XCTAssertEqual(image.prompt, "A forest")
        XCTAssertEqual(image.style, .fantasy)

        let catalog = try await client.loadAIArtModelCatalog(.modCar)
        XCTAssertEqual(catalog.defaultModel?.id, "mock-model-flux")

        let video = try await client.submitAIArtVideo(
            .init(imagePath: "file:///tmp/avatar.png", artStyle: "Ghibli")
        )
        XCTAssertEqual(video.status, .processing)
    }
}
