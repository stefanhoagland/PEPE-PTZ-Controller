import XCTest
@testable import PTZCore

final class PanasonicCommandTests: XCTestCase {
    private let base = URL(string: "http://192.168.0.10")!

    private func url(_ command: PanasonicCommand) -> String? {
        command.url(baseURL: base)?.absoluteString
    }

    func testPanTiltURLs() {
        XCTAssertEqual(url(.stopPanTilt), "http://192.168.0.10/cgi-bin/aw_ptz?cmd=%23PTS5050&res=1")
        XCTAssertEqual(PanasonicCommand.panTilt(pan: 49, tilt: -49).commandText, "#PTS9901")
        XCTAssertEqual(PanasonicCommand.panTilt(pan: -10, tilt: 25).commandText, "#PTS4075")
    }

    func testSpeedsAreClamped() {
        XCTAssertEqual(PanasonicCommand.panTilt(pan: 200, tilt: -200).commandText, "#PTS9901")
        XCTAssertEqual(PanasonicCommand.zoom(-99).commandText, "#Z01")
    }

    func testZoomAndFocus() {
        XCTAssertEqual(PanasonicCommand.zoom(10).commandText, "#Z60")
        XCTAssertEqual(PanasonicCommand.stopZoom.commandText, "#Z50")
        XCTAssertEqual(PanasonicCommand.focus(-5).commandText, "#F45")
        XCTAssertEqual(PanasonicCommand.autoFocus(true).commandText, "#D11")
        XCTAssertEqual(PanasonicCommand.autoFocus(false).commandText, "#D10")
    }

    func testPresetsAreZeroBasedOnTheWire() {
        XCTAssertEqual(PanasonicCommand.recallPreset(1).commandText, "#R00")
        XCTAssertEqual(PanasonicCommand.recallPreset(100).commandText, "#R99")
        XCTAssertEqual(PanasonicCommand.savePreset(12).commandText, "#M11")
        XCTAssertEqual(PanasonicCommand.recallPreset(0).commandText, "#R00", "clamped to preset 1")
    }

    func testCameraCommandsUseAwCam() {
        XCTAssertEqual(url(.queryModel), "http://192.168.0.10/cgi-bin/aw_cam?cmd=QID&res=1")
        XCTAssertEqual(url(.power(true)), "http://192.168.0.10/cgi-bin/aw_ptz?cmd=%23O1&res=1")
    }

    func testCustomPort() {
        let camera = Camera(name: "A", host: "10.0.0.5", port: 8080)
        XCTAssertEqual(
            PanasonicCommand.stopZoom.url(baseURL: camera.baseURL!)?.absoluteString,
            "http://10.0.0.5:8080/cgi-bin/aw_ptz?cmd=%23Z50&res=1"
        )
    }

    func testIsStop() {
        XCTAssertTrue(PanasonicCommand.stopPanTilt.isStop)
        XCTAssertTrue(PanasonicCommand.zoom(0).isStop)
        XCTAssertFalse(PanasonicCommand.zoom(5).isStop)
    }

    func testErrorReplies() {
        XCTAssertEqual(try PTZError.check(response: "pTS5050\r\n"), "pTS5050")
        XCTAssertThrowsError(try PTZError.check(response: "ER1:OSA")) { XCTAssertEqual($0 as? PTZError, .unsupportedCommand("ER1:OSA")) }
        XCTAssertThrowsError(try PTZError.check(response: "ER2:PTS")) { XCTAssertEqual($0 as? PTZError, .busy("ER2:PTS")) }
        XCTAssertThrowsError(try PTZError.check(response: "ER3:R")) { XCTAssertEqual($0 as? PTZError, .outOfRange("ER3:R")) }
    }
}

final class SimulatedCameraTests: XCTestCase {
    func testTracksMovementAndPresets() async throws {
        let camera = SimulatedCamera()
        let reply = try await camera.send(.panTilt(pan: 10, tilt: -3))
        XCTAssertEqual(reply, "pTS6047")
        _ = try await camera.send(.savePreset(3))
        _ = try await camera.send(.recallPreset(3))
        let state = await camera.state
        XCTAssertEqual(state.panSpeed, 10)
        XCTAssertEqual(state.tiltSpeed, -3)
        XCTAssertEqual(state.savedPresets, [3])
        XCTAssertEqual(state.lastRecalledPreset, 3)
    }

    func testStandbyRejectsMovement() async throws {
        let camera = SimulatedCamera()
        _ = try await camera.send(.power(false))
        do {
            _ = try await camera.send(.zoom(10))
            XCTFail("expected busy error")
        } catch {
            XCTAssertEqual(error as? PTZError, .busy("ER2:Z60"))
        }
        let model = try await camera.send(.queryModel)
        XCTAssertEqual(model, "OID:AW-UE160")
    }
}
