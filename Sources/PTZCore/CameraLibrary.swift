import Foundation

/// The user's list of cameras, in display order.
public struct CameraLibrary: Codable, Equatable, Sendable {
    public private(set) var cameras: [Camera]

    public init(cameras: [Camera] = []) {
        self.cameras = cameras
    }

    public func camera(id: Camera.ID) -> Camera? {
        cameras.first { $0.id == id }
    }

    public mutating func add(_ camera: Camera) {
        cameras.append(camera)
    }

    /// Replaces the camera with the same id. Does nothing if it isn't in the list.
    public mutating func update(_ camera: Camera) {
        guard let index = cameras.firstIndex(where: { $0.id == camera.id }) else { return }
        cameras[index] = camera
    }

    public mutating func remove(id: Camera.ID) {
        cameras.removeAll { $0.id == id }
    }

    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        // Same behavior as SwiftUI's Array.move(fromOffsets:toOffset:), without importing SwiftUI.
        let moving = source.map { cameras[$0] }
        let insertAt = destination - source.filter { $0 < destination }.count
        for index in source.sorted(by: >) { cameras.remove(at: index) }
        cameras.insert(contentsOf: moving, at: insertAt)
    }
}

/// Saves and loads a `CameraLibrary` as a JSON file.
public struct CameraLibraryFile: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// The default location: `~/Library/Application Support/PEPE PTZ Controller/cameras.json`.
    public static func defaultLocation() throws -> CameraLibraryFile {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        let folder = support.appendingPathComponent("PEPE PTZ Controller", isDirectory: true)
        return CameraLibraryFile(url: folder.appendingPathComponent("cameras.json"))
    }

    /// Returns an empty library if the file doesn't exist yet.
    public func load() throws -> CameraLibrary {
        guard FileManager.default.fileExists(atPath: url.path) else { return CameraLibrary() }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(CameraLibrary.self, from: data)
    }

    public func save(_ library: CameraLibrary) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(library).write(to: url, options: .atomic)
    }
}
