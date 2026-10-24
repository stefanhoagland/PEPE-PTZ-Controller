import XCTest
@testable import PTZCore

final class CameraTests: XCTestCase {
    func testValidCameraHasNoErrors() {
        let camera = Camera(name: "Stage Left", host: "192.168.0.10")
        XCTAssertEqual(camera.validate(), [])
    }

    func testMissingFieldsAreReported() {
        let camera = Camera(name: "  ", host: "", port: 0)
        XCTAssertEqual(camera.validate(), [.missingName, .missingHost, .invalidPort])
    }

    func testHostWithSlashIsInvalid() {
        let camera = Camera(name: "Cam", host: "http://192.168.0.10")
        XCTAssertEqual(camera.validate(), [.invalidHost])
    }

    func testBaseURLOmitsDefaultPort() {
        XCTAssertEqual(Camera(name: "A", host: "10.0.0.5").baseURL?.absoluteString, "http://10.0.0.5")
        XCTAssertEqual(Camera(name: "A", host: "10.0.0.5", port: 8080).baseURL?.absoluteString, "http://10.0.0.5:8080")
    }
}

final class CameraLibraryTests: XCTestCase {
    func testAddUpdateRemove() {
        var library = CameraLibrary()
        var camera = Camera(name: "One", host: "10.0.0.1")
        library.add(camera)
        camera.name = "Renamed"
        library.update(camera)
        XCTAssertEqual(library.camera(id: camera.id)?.name, "Renamed")
        library.remove(id: camera.id)
        XCTAssertTrue(library.cameras.isEmpty)
    }

    func testMove() {
        let a = Camera(name: "A", host: "1"), b = Camera(name: "B", host: "2"), c = Camera(name: "C", host: "3")
        var library = CameraLibrary(cameras: [a, b, c])
        library.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        XCTAssertEqual(library.cameras.map(\.name), ["B", "C", "A"])
        library.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        XCTAssertEqual(library.cameras.map(\.name), ["A", "B", "C"])
    }

    func testSaveAndLoadRoundTrip() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = CameraLibraryFile(url: folder.appendingPathComponent("cameras.json"))

        XCTAssertEqual(try file.load(), CameraLibrary(), "missing file loads as empty")

        let library = CameraLibrary(cameras: [Camera(name: "Cam", host: "192.168.1.20", port: 8080, username: "op")])
        try file.save(library)
        XCTAssertEqual(try file.load(), library)
    }
}
