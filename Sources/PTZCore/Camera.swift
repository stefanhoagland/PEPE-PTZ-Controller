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
    /// A built-in fake camera for trying the app without hardware.
    public var isSimulated: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 80,
        username: String = "admin",
        isSimulated: Bool = false
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.isSimulated = isSimulated
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, host, port, username, isSimulated
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        host = try container.decode(String.self, forKey: .host)
        port = try container.decode(Int.self, forKey: .port)
        username = try container.decode(String.self, forKey: .username)
        // Older saved lists don't have this field.
        isSimulated = try container.decodeIfPresent(Bool.self, forKey: .isSimulated) ?? false
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
        if isSimulated {
            // A simulated camera doesn't need an address.
        } else if trimmedHost.isEmpty {
            errors.append(.missingHost)
        } else if trimmedHost.contains(where: { $0 == " " || $0 == "/" }) {
            errors.append(.invalidHost)
        }
        if !(1...65535).contains(port) { errors.append(.invalidPort) }
        return errors
    }
}
