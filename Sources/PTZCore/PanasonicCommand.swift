import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A command in Panasonic's PTZ network protocol, used by the AW-UE160 and
/// other Panasonic integrated cameras.
///
/// Commands are sent as HTTP GET requests, for example
/// `http://192.168.0.10/cgi-bin/aw_ptz?cmd=%23PTS5050&res=1`.
///
/// Speeds use a signed scale from -49 to 49, where 0 is stop.
/// The protocol itself uses 01 to 99 with 50 as stop.
public enum PanasonicCommand: Equatable, Hashable, Sendable {
    /// Move pan and tilt together. Positive pan is right, positive tilt is up.
    case panTilt(pan: Int, tilt: Int)
    /// Positive zooms in (tele), negative zooms out (wide).
    case zoom(Int)
    /// Positive focuses far, negative focuses near.
    case focus(Int)
    case autoFocus(Bool)
    /// Presets are numbered 1 to 100, as shown on the camera's web page.
    case recallPreset(Int)
    case savePreset(Int)
    /// `true` turns the camera on, `false` puts it in standby.
    case power(Bool)
    /// Asks for the model name, for example `OID:AW-UE160`.
    case queryModel

    public static let stopPanTilt = PanasonicCommand.panTilt(pan: 0, tilt: 0)
    public static let stopZoom = PanasonicCommand.zoom(0)
    public static let stopFocus = PanasonicCommand.focus(0)

    public static let speedRange = -49...49
    public static let presetRange = 1...100

    /// `aw_ptz` for movement commands, `aw_cam` for camera settings.
    public var cgiName: String {
        switch self {
        case .queryModel: return "aw_cam"
        default: return "aw_ptz"
        }
    }

    /// The command text, for example `#PTS5050`.
    public var commandText: String {
        switch self {
        case let .panTilt(pan, tilt):
            return "#PTS" + Self.speedCode(pan) + Self.speedCode(tilt)
        case let .zoom(speed):
            return "#Z" + Self.speedCode(speed)
        case let .focus(speed):
            return "#F" + Self.speedCode(speed)
        case let .autoFocus(on):
            return on ? "#D11" : "#D10"
        case let .recallPreset(number):
            return "#R" + Self.presetCode(number)
        case let .savePreset(number):
            return "#M" + Self.presetCode(number)
        case let .power(on):
            return on ? "#O1" : "#O0"
        case .queryModel:
            return "QID"
        }
    }

    /// The full request URL for a camera at `baseURL` (for example `http://192.168.0.10`).
    public func url(baseURL: URL) -> URL? {
        let endpoint = baseURL
            .appendingPathComponent("cgi-bin")
            .appendingPathComponent(cgiName)
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            return nil
        }
        let encoded = commandText.replacingOccurrences(of: "#", with: "%23")
        components.percentEncodedQuery = "cmd=\(encoded)&res=1"
        return components.url
    }

    /// Whether this command stops a movement. Stops matter most, so callers
    /// may want to retry them.
    public var isStop: Bool {
        self == .stopPanTilt || self == .stopZoom || self == .stopFocus
    }

    static func speedCode(_ speed: Int) -> String {
        let clamped = min(max(speed, speedRange.lowerBound), speedRange.upperBound)
        return twoDigits(50 + clamped)
    }

    static func presetCode(_ number: Int) -> String {
        let clamped = min(max(number, presetRange.lowerBound), presetRange.upperBound)
        return twoDigits(clamped - 1)
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}

/// Errors from a Panasonic camera or the network.
public enum PTZError: Error, Equatable, CustomStringConvertible {
    case noAddress
    case unauthorized
    case httpStatus(Int)
    /// `ER1`: the camera doesn't support this command.
    case unsupportedCommand(String)
    /// `ER2`: the camera is busy, for example still powering on.
    case busy(String)
    /// `ER3`: a value was out of range.
    case outOfRange(String)
    case cameraError(String)
    /// The video connection closed.
    case streamEnded

    public var description: String {
        switch self {
        case .noAddress: return "The camera's address isn't valid."
        case .unauthorized: return "The camera rejected the username or password."
        case let .httpStatus(code): return "The camera answered with HTTP error \(code)."
        case let .unsupportedCommand(text): return "The camera doesn't support this command (\(text))."
        case let .busy(text): return "The camera is busy (\(text)). It may still be starting up or in standby."
        case let .outOfRange(text): return "The camera rejected a value as out of range (\(text))."
        case let .cameraError(text): return "The camera reported an error: \(text)"
        case .streamEnded: return "The camera closed the video connection."
        }
    }

    /// Throws for a login failure or any other non-success HTTP status.
    public static func check(httpResponse response: URLResponse?) throws {
        guard let http = response as? HTTPURLResponse else { return }
        if http.statusCode == 401 { throw PTZError.unauthorized }
        if !(200..<300).contains(http.statusCode) { throw PTZError.httpStatus(http.statusCode) }
    }

    /// Checks a camera reply and throws if it is an error such as `ER2:PTS`.
    public static func check(response: String) throws -> String {
        let text = response.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("ER1") { throw PTZError.unsupportedCommand(text) }
        if text.hasPrefix("ER2") { throw PTZError.busy(text) }
        if text.hasPrefix("ER3") { throw PTZError.outOfRange(text) }
        if text.hasPrefix("ER") { throw PTZError.cameraError(text) }
        return text
    }
}
