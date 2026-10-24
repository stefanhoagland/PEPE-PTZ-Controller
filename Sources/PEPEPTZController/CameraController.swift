import Foundation
import PTZCore

/// Drives one camera from the control panel.
///
/// Commands go through a single queue so they reach the camera in the order
/// they were pressed, with a short gap between them. Panasonic recommends at
/// least 130 ms between commands to the same camera.
@MainActor
final class CameraController: ObservableObject {
    enum Status: Equatable {
        case connecting
        case connected(model: String)
        case failed(String)
    }

    @Published private(set) var status: Status = .connecting
    @Published private(set) var lastError: String?
    @Published private(set) var autoFocus = true
    @Published private(set) var lastPreset: Int?
    /// Pan and tilt speed, 1 to 49.
    @Published var moveSpeed: Double = 20
    /// Zoom and focus speed, 1 to 49.
    @Published var zoomSpeed: Double = 25

    private let queue: AsyncStream<PanasonicCommand>.Continuation

    static let commandGap: UInt64 = 130_000_000

    init(camera: Camera, password: String?) {
        let client: PTZClient?
        if camera.isSimulated {
            client = SimulatedCamera()
        } else if let url = camera.baseURL {
            client = PanasonicHTTPClient(baseURL: url, username: camera.username, password: password ?? "")
        } else {
            client = nil
        }

        var continuation: AsyncStream<PanasonicCommand>.Continuation!
        let stream = AsyncStream<PanasonicCommand> { continuation = $0 }
        queue = continuation

        guard let client else {
            status = .failed(PTZError.noAddress.description)
            return
        }

        Task { [weak self] in
            for await command in stream {
                do {
                    let reply = try await client.send(command)
                    self?.handle(reply: reply, to: command)
                } catch {
                    self?.handle(error: error, for: command)
                    // A stop that didn't arrive could leave the camera moving, so try once more.
                    if command.isStop, (try? await client.send(command)) != nil {
                        self?.lastError = nil
                    }
                }
                try? await Task.sleep(nanoseconds: Self.commandGap)
            }
        }
        send(.queryModel)
    }

    deinit {
        // Ending the queue lets any commands already in it (such as stops) go out first.
        queue.finish()
    }

    // MARK: - Controls

    /// `pan` and `tilt` are directions: -1, 0 or 1.
    func startMoving(pan: Int, tilt: Int) {
        let speed = Int(moveSpeed.rounded())
        send(.panTilt(pan: pan * speed, tilt: tilt * speed))
    }

    func stopMoving() { send(.stopPanTilt) }

    /// `direction` is 1 for zoom in (tele) or -1 for zoom out (wide).
    func startZoom(_ direction: Int) { send(.zoom(direction * Int(zoomSpeed.rounded()))) }
    func stopZoom() { send(.stopZoom) }

    /// `direction` is 1 for far or -1 for near.
    func startFocus(_ direction: Int) { send(.focus(direction * Int(zoomSpeed.rounded()))) }
    func stopFocus() { send(.stopFocus) }

    func setAutoFocus(_ on: Bool) {
        autoFocus = on
        send(.autoFocus(on))
    }

    func recallPreset(_ number: Int) { send(.recallPreset(number)) }
    func savePreset(_ number: Int) { send(.savePreset(number)) }
    func setPower(_ on: Bool) { send(.power(on)) }
    func reconnect() {
        status = .connecting
        send(.queryModel)
    }

    /// Stops all movement, for example when leaving the camera's page.
    func stopEverything() {
        send(.stopPanTilt)
        send(.stopZoom)
        send(.stopFocus)
    }

    // MARK: - Private

    private func send(_ command: PanasonicCommand) {
        queue.yield(command)
    }

    private func handle(reply: String, to command: PanasonicCommand) {
        lastError = nil
        switch command {
        case .queryModel:
            let model = reply.hasPrefix("OID:") ? String(reply.dropFirst(4)) : reply
            status = .connected(model: model)
        case let .recallPreset(number):
            lastPreset = number
        default:
            if case .failed = status { status = .connecting; send(.queryModel) }
        }
    }

    private func handle(error: Error, for command: PanasonicCommand) {
        let message = (error as? PTZError)?.description ?? error.localizedDescription
        if command == .queryModel {
            status = .failed(message)
        } else {
            lastError = message
        }
    }
}
