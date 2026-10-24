import CoreGraphics
import Foundation
import ImageIO
import PTZCore

/// Plays one camera's live video.
///
/// It tries the Motion JPEG stream first. If that gives no pictures, it falls
/// back to fetching single snapshots. If the video drops, it reconnects.
@MainActor
final class LiveVideoModel: ObservableObject {
    enum Status: Equatable {
        case connecting
        case live(source: String)
        case failed(String)
    }

    /// How the picture is fetched from the camera.
    enum Mode: String, CaseIterable, Identifiable {
        /// A continuous Motion JPEG stream: smoothest, but keeps a connection open.
        case stream
        /// Single pictures fetched about twice a second: lighter on the camera.
        case snapshots
        /// No video, so the camera only handles control commands.
        case off

        var id: String { rawValue }
        var label: String {
            switch self {
            case .stream: return "Stream"
            case .snapshots: return "Snapshots"
            case .off: return "Off"
            }
        }
    }

    @Published private(set) var frame: CGImage?
    @Published private(set) var status: Status = .connecting

    private let camera: Camera
    private let password: String
    private var task: Task<Void, Never>?

    init(camera: Camera, password: String?) {
        self.camera = camera
        self.password = password ?? ""
    }

    func start(mode: Mode) {
        stop()
        guard mode != .off else {
            frame = nil
            return
        }
        status = .connecting
        task = Task { [weak self] in
            await self?.run(mode: mode)
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func run(mode: Mode) async {
        guard let base = camera.baseURL,
              let mjpegURL = PanasonicVideo.mjpegURL(baseURL: base),
              let snapshotURL = PanasonicVideo.snapshotURL(baseURL: base)
        else {
            status = .failed(PTZError.noAddress.description)
            return
        }

        while !Task.isCancelled {
            var stream: (frames: Int, error: Error?) = (0, nil)
            if mode == .stream {
                stream = await play(
                    PanasonicVideo.mjpegFrames(url: mjpegURL, username: camera.username, password: password),
                    source: "JPEG stream"
                )
                if Task.isCancelled { return }
            }

            if stream.frames == 0 {
                let snapshots = await play(
                    PanasonicVideo.snapshotFrames(url: snapshotURL, username: camera.username, password: password),
                    source: "Snapshots"
                )
                if Task.isCancelled { return }
                if snapshots.frames == 0 {
                    status = .failed(Self.message(for: snapshots.error ?? stream.error))
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    continue
                }
            }
            // The video dropped after working. Reconnect shortly.
            status = .connecting
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    /// Shows frames until the stream ends. Returns how many were shown.
    private func play(_ frames: AsyncThrowingStream<Data, Error>, source: String) async -> (frames: Int, error: Error?) {
        var count = 0
        do {
            for try await data in frames {
                if Task.isCancelled { break }
                guard let image = await Self.decode(data) else { continue }
                frame = image
                count += 1
                if count == 1 { status = .live(source: source) }
            }
            return (count, nil)
        } catch {
            return (count, error)
        }
    }

    /// Decodes a JPEG away from the main thread.
    private nonisolated static func decode(_ data: Data) async -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func message(for error: Error?) -> String {
        if let error = error as? PTZError { return error.description }
        if let error { return error.localizedDescription }
        return "No video from the camera. Check that JPEG streaming is turned on in its web settings."
    }
}
