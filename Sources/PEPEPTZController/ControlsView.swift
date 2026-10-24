import PTZCore
import SwiftUI

/// Pan, tilt, zoom, focus, presets and power for one camera.
struct ControlsView: View {
    @ObservedObject var controller: CameraController

    @State private var storeMode = false
    @State private var presetToStore: Int?

    private static let presetCount = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            statusLine

            GroupBox("Pan and tilt") {
                VStack(spacing: 10) {
                    directionPad
                    speedSlider("Speed", value: $controller.moveSpeed)
                }
                .padding(6)
            }

            GroupBox("Zoom and focus") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Zoom").frame(width: 44, alignment: .leading)
                        HoldButton(onPress: { controller.startZoom(-1) }, onRelease: { controller.stopZoom() }) {
                            Label("Wide", systemImage: "minus.magnifyingglass")
                        }
                        HoldButton(onPress: { controller.startZoom(1) }, onRelease: { controller.stopZoom() }) {
                            Label("Tele", systemImage: "plus.magnifyingglass")
                        }
                    }
                    HStack {
                        Text("Focus").frame(width: 44, alignment: .leading)
                        HoldButton(onPress: { controller.startFocus(-1) }, onRelease: { controller.stopFocus() }) {
                            Text("Near")
                        }
                        .disabled(controller.autoFocus)
                        HoldButton(onPress: { controller.startFocus(1) }, onRelease: { controller.stopFocus() }) {
                            Text("Far")
                        }
                        .disabled(controller.autoFocus)
                        Toggle("Auto", isOn: Binding(
                            get: { controller.autoFocus },
                            set: { controller.setAutoFocus($0) }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                    speedSlider("Speed", value: $controller.zoomSpeed)
                }
                .padding(6)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                        ForEach(1...Self.presetCount, id: \.self) { number in
                            presetButton(number)
                        }
                    }
                    Text(storeMode
                         ? "Click a preset to save the camera's current position to it."
                         : "Click a preset to move the camera there.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(6)
            } label: {
                HStack {
                    Text("Presets")
                    Spacer()
                    Toggle("Store", isOn: $storeMode)
                        .toggleStyle(.button)
                        .controlSize(.small)
                        .tint(.red)
                        .help("Turn on, then click a preset to save the current position")
                }
            }

            HStack {
                Button { controller.setPower(true) } label: { Label("Power On", systemImage: "power") }
                Button { controller.setPower(false) } label: { Label("Standby", systemImage: "moon") }
                Spacer()
                Button("Stop All") { controller.stopEverything() }
                    .help("Stop all pan, tilt, zoom and focus movement")
            }
        }
        .frame(width: 320)
        .confirmationDialog(
            "Save the current position as preset \(presetToStore ?? 0)?",
            isPresented: Binding(get: { presetToStore != nil }, set: { if !$0 { presetToStore = nil } }),
            presenting: presetToStore
        ) { number in
            Button("Save Preset \(number)") {
                controller.savePreset(number)
                storeMode = false
            }
        } message: { _ in
            Text("This replaces whatever is saved in that preset on the camera.")
        }
    }

    // MARK: - Pieces

    @ViewBuilder
    private var statusLine: some View {
        HStack(spacing: 6) {
            switch controller.status {
            case .connecting:
                ProgressView().controlSize(.small)
                Text("Connecting…")
            case let .connected(model):
                Circle().fill(.green).frame(width: 8, height: 8)
                Text("Connected: \(model)")
            case let .failed(message):
                Circle().fill(.red).frame(width: 8, height: 8)
                Text(message).lineLimit(2)
                Spacer()
                Button("Retry") { controller.reconnect() }.controlSize(.small)
            }
        }
        .font(.callout)

        if let error = controller.lastError {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    private var directionPad: some View {
        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            GridRow {
                moveButton(pan: -1, tilt: 1, icon: "arrow.up.left")
                moveButton(pan: 0, tilt: 1, icon: "arrow.up")
                moveButton(pan: 1, tilt: 1, icon: "arrow.up.right")
            }
            GridRow {
                moveButton(pan: -1, tilt: 0, icon: "arrow.left")
                Button { controller.stopMoving() } label: {
                    Image(systemName: "stop.fill").frame(width: 44, height: 36)
                }
                .buttonStyle(.plain)
                .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                .help("Stop")
                moveButton(pan: 1, tilt: 0, icon: "arrow.right")
            }
            GridRow {
                moveButton(pan: -1, tilt: -1, icon: "arrow.down.left")
                moveButton(pan: 0, tilt: -1, icon: "arrow.down")
                moveButton(pan: 1, tilt: -1, icon: "arrow.down.right")
            }
        }
        .font(.title3)
    }

    private func moveButton(pan: Int, tilt: Int, icon: String) -> some View {
        HoldButton(
            onPress: { controller.startMoving(pan: pan, tilt: tilt) },
            onRelease: { controller.stopMoving() }
        ) {
            Image(systemName: icon).frame(width: 44, height: 36)
        }
    }

    private func speedSlider(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title).frame(width: 44, alignment: .leading)
            Slider(value: value, in: 1...49)
            Text("\(Int(value.wrappedValue.rounded()))")
                .monospacedDigit()
                .frame(width: 24, alignment: .trailing)
        }
        .font(.callout)
    }

    private func presetTint(_ number: Int) -> Color? {
        if storeMode { return Color.red }
        if controller.lastPreset == number { return Color.accentColor }
        return nil
    }

    private func presetButton(_ number: Int) -> some View {
        Button {
            if storeMode {
                presetToStore = number
            } else {
                controller.recallPreset(number)
            }
        } label: {
            Text("\(number)")
                .frame(maxWidth: .infinity, minHeight: 28)
        }
        .buttonStyle(.bordered)
        .tint(presetTint(number))
    }
}
