import XCTest

@testable import WasmClient

final class AuditCleanupTests: XCTestCase {

    func testBundledFlowKitVersionMatchesPackagePin() {
        XCTAssertEqual(WasmClient.bundledFlowKitVersion, "1.2.65-26.1.1-ffi")
    }

    func testOpenActionIDRoundTripsKnownAndUnknownValues() {
        XCTAssertEqual(
            WasmClient.ActionID.chat.rawValue,
            "5e1ab91a-ac32-4269-9e20-4d864df4112d"
        )

        let custom = WasmClient.ActionID(rawValue: "custom-action")
        XCTAssertEqual(custom.rawValue, "custom-action")
        XCTAssertEqual(Set([custom, .chat]).count, 2)
    }

    func testOpenMethodIdentifiersRoundTripUnknownValues() {
        XCTAssertEqual(
            WasmClient.VisionMethod.visualSearch.rawValue,
            "asyncify.vision.VisionService/VisualSearch"
        )
        XCTAssertEqual(
            WasmClient.Chat.Method.listProviders.rawValue,
            "asyncify.openai.OpenAIService/ListProviders"
        )
        XCTAssertEqual(
            WasmClient.Inpaint.Method.erase.rawValue,
            "asyncify.inpaint.InpaintService/Erase"
        )

        XCTAssertEqual(WasmClient.VisionMethod(rawValue: "custom/vision").rawValue, "custom/vision")
        XCTAssertEqual(WasmClient.Chat.Method(rawValue: "custom/chat").rawValue, "custom/chat")
        XCTAssertEqual(WasmClient.Inpaint.Method(rawValue: "custom/inpaint").rawValue, "custom/inpaint")
    }

    func testEngineHandleRecoversWrappedValue() {
        final class Box {}
        let box = Box()
        let handle = WasmClient.EngineHandle(box)

        XCTAssertTrue(handle.value(as: Box.self) === box)
        XCTAssertNil(handle.value(as: String.self))
    }

    func testHomeDecorWireValuesRoundTripUnknownValues() {
        XCTAssertEqual(WasmClient.HomeDecor.ProcessType.interior.wireName, "interior")
        XCTAssertEqual(WasmClient.HomeDecor.ProcessType.interior.actionID, .interiorDesign)
        XCTAssertNil(WasmClient.HomeDecor.ProcessType(rawValue: "custom_process").actionID)

        XCTAssertEqual(WasmClient.HomeDecor.StyleSelection(wireName: "custom_style").wireName, "custom_style")
        XCTAssertEqual(WasmClient.HomeDecor.RoomType(wireName: "custom_room").wireName, "custom_room")
        XCTAssertEqual(WasmClient.HomeDecor.RoomStyle(wireName: "custom_room_style").wireName, "custom_room_style")
        XCTAssertEqual(WasmClient.HomeDecor.ColorPalette(wireName: "custom_palette").wireName, "custom_palette")
        XCTAssertEqual(WasmClient.HomeDecor.SurfaceType(wireName: "custom_surface").wireName, "custom_surface")
    }

    func testHomeDecorRequestKeepsUnknownWireValues() {
        let request = WasmClient.HomeDecor.Request(
            file: "room.jpg",
            processType: .init(rawValue: "custom_process"),
            roomStyle: .init(rawValue: "custom_style"),
            roomType: .init(rawValue: "custom_room"),
            styleSelection: .init(rawValue: "custom_selection"),
            colorPalette: .init(rawValue: "custom_palette"),
            surfaceType: .init(rawValue: "custom_surface"),
            extraArgs: ["room_style": "override_style"]
        )

        XCTAssertEqual(
            request.toWireArgs(),
            [
                "file": "room.jpg",
                "process_type": "custom_process",
                "room_style": "override_style",
                "room_type": "custom_room",
                "style_selection": "custom_selection",
                "color": "custom_palette",
                "surface_type": "custom_surface",
            ]
        )
    }

    func testSetNotificationAcceptsLiveActivityAttributesType() async throws {
        actor Capture {
            var values: [WasmClient.Notification.LiveActivityAttributesType?] = []

            func append(_ value: WasmClient.Notification.LiveActivityAttributesType?) {
                values.append(value)
            }

            func get() -> [WasmClient.Notification.LiveActivityAttributesType?] {
                values
            }
        }

        let capture = Capture()
        var client = WasmClient.noop
        client.setNotification = { _, _, _, _, type in
            await capture.append(type)
        }

        let type = WasmClient.Notification.LiveActivityAttributesType(rawValue: "MatchActivityAttributes")
        try await client.setNotification(true, "token", nil, "activity-token", type)
        try await client.setNotification(false, "", nil, "", nil)

        let values = await capture.get()
        XCTAssertEqual(values.count, 2)
        XCTAssertEqual(values[0]?.rawValue, "MatchActivityAttributes")
        XCTAssertNil(values[1])
    }

    func testDefaultStreamsDoNotFinishImmediately() async {
        let client = WasmClient()

        await assertDoesNotFinishImmediately(await client.observeTaskCreated())
        await assertDoesNotFinishImmediately(await client.liveMatchEvents())
    }

    private func assertDoesNotFinishImmediately<Element: Sendable>(
        _ stream: AsyncStream<Element>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                var iterator = stream.makeAsyncIterator()
                return await iterator.next() == nil
            }
            group.addTask {
                try? await Task.sleep(for: .milliseconds(50))
                return false
            }

            let finished = await group.next() ?? false
            group.cancelAll()
            XCTAssertFalse(finished, "stream finished immediately", file: file, line: line)
        }
    }
}
