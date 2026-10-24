import XCTest
@testable import PTZCore

final class MJPEGParserTests: XCTestCase {
    private let frameA = Data([0xFF, 0xD8, 0x01, 0x02, 0xFF, 0xD9])
    private let frameB = Data([0xFF, 0xD8, 0x03, 0xFF, 0x00, 0x04, 0xFF, 0xD9])

    private func part(_ frame: Data) -> Data {
        Data("--myboundary\r\nContent-Type: image/jpeg\r\nContent-Length: \(frame.count)\r\n\r\n".utf8) + frame + Data("\r\n".utf8)
    }

    func testFindsFramesBetweenMultipartHeaders() {
        var parser = MJPEGParser()
        XCTAssertEqual(parser.append(part(frameA) + part(frameB)), [frameA, frameB])
    }

    func testFramesSplitAcrossChunks() {
        var parser = MJPEGParser()
        let bytes = part(frameA) + part(frameB)
        var frames: [Data] = []
        for byte in bytes {
            frames += parser.append(Data([byte]))
        }
        XCTAssertEqual(frames, [frameA, frameB])
    }

    func testOversizedFrameIsDropped() {
        var parser = MJPEGParser(maxBufferSize: 16)
        XCTAssertEqual(parser.append(Data([0xFF, 0xD8]) + Data(repeating: 0x11, count: 32)), [])
        XCTAssertEqual(parser.append(part(frameA)), [frameA], "recovers on the next frame")
    }
}

final class PanasonicVideoTests: XCTestCase {
    func testURLs() {
        let base = URL(string: "http://192.168.0.10")!
        XCTAssertEqual(PanasonicVideo.mjpegURL(baseURL: base)?.absoluteString, "http://192.168.0.10/cgi-bin/mjpeg?stream=1")
        XCTAssertEqual(PanasonicVideo.snapshotURL(baseURL: base)?.absoluteString, "http://192.168.0.10/cgi-bin/camera?resolution=640")
    }
}
