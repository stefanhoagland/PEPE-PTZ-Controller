import Foundation

/// A fake camera that answers like an AW-UE160. Used for trying the app
/// without hardware and in tests.
public actor SimulatedCamera: PTZClient {
    public struct State: Equatable, Sendable {
        public var panSpeed = 0
        public var tiltSpeed = 0
        public var zoomSpeed = 0
        public var focusSpeed = 0
        public var autoFocus = true
        public var poweredOn = true
        public var savedPresets: Set<Int> = []
        public var lastRecalledPreset: Int?
    }

    public private(set) var state = State()
    public private(set) var sentCommands: [PanasonicCommand] = []

    public init() {}

    public func send(_ command: PanasonicCommand) async throws -> String {
        sentCommands.append(command)
        if !state.poweredOn, command != .power(true), command != .queryModel {
            return try PTZError.check(response: "ER2:" + command.commandText.dropFirst())
        }
        switch command {
        case let .panTilt(pan, tilt):
            state.panSpeed = pan
            state.tiltSpeed = tilt
            return "pTS" + PanasonicCommand.speedCode(pan) + PanasonicCommand.speedCode(tilt)
        case let .zoom(speed):
            state.zoomSpeed = speed
            return "zS" + PanasonicCommand.speedCode(speed)
        case let .focus(speed):
            state.focusSpeed = speed
            return "fS" + PanasonicCommand.speedCode(speed)
        case let .autoFocus(on):
            state.autoFocus = on
            return on ? "d11" : "d10"
        case let .recallPreset(number):
            state.lastRecalledPreset = number
            return "s" + PanasonicCommand.presetCode(number)
        case let .savePreset(number):
            state.savedPresets.insert(number)
            return "s" + PanasonicCommand.presetCode(number)
        case let .power(on):
            state.poweredOn = on
            return on ? "p1" : "p0"
        case .queryModel:
            return "OID:AW-UE160"
        }
    }
}
