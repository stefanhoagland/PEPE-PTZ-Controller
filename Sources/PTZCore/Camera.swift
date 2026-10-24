import Foundation

/// A PTZ camera on the local network.
///
/// The password is not stored here. The app keeps it in the macOS Keychain,
/// keyed by the camera's `id`.
public struct Camera: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var host: String
    public var port: Int
    public var username: String

    public init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 80,
        username: String = "admin"
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
    }

    /// The camera's HTTP address, for example `http://192.168.0.10`.
    public var baseURL: URL? {
        var parts = URLComponents()
        parts.scheme = "http"
        parts.host = host.trimmingCharacters(in: .whitespaces)
        if port != 80 { parts.port = port }
        return parts.url
    }

    public enum ValidationError: Error, Hashable, CustomStringConvertible {
        case missingName
        case missingHost
        case invalidHost
        case invalidPort

        public var description: String {
            switch self {
            case .missingName: return "Give the camera a name."
            case .missingHost: return "Enter the camera's IP address or hostname."
            case .invalidHost: return "The address can't contain spaces or slashes."
            case .invalidPort: return "The port must be between 1 and 65535."
            }
        }
    }

    /// Problems that stop this camera from being saved. Empty means it's valid.
    public func validate() -> [ValidationError] {
        var errors: [ValidationError] = []
        if name.trimmingCharacters(in: .whitespaces).isEmpty { errors.append(.missingName) }
        let trimmedHost = host.trimmingCharacters(in: .whitespaces)
        if trimmedHost.isEmpty {
            errors.append(.missingHost)
        } else if trimmedHost.contains(where: { $0 == " " || $0 == "/" }) {
            errors.append(.invalidHost)
        }
        if !(1...65535).contains(port) { errors.append(.invalidPort) }
        return errors
    }
}
