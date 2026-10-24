import PTZCore
import SwiftUI

/// All cameras' live feeds in a grid, with the controls for the selected one beside it.
///
/// Click a feed to control that camera, double-click to open it on its own,
/// or press 1 to 9 to pick a camera by its number.
struct MultiviewView: View {
    let cameras: [Camera]
    @Binding var selection: Camera.ID?
    let onOpen: (Camera.ID) -> Void

    private var selectedCamera: Camera? {
        cameras.first { $0.id == selection }
    }

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                    ForEach(Array(cameras.enumerated()), id: \.element.id) { index, camera in
                        CameraTile(camera: camera, number: index + 1, isSelected: camera.id == selection)
                            .onTapGesture(count: 2) { onOpen(camera.id) }
                            .onTapGesture { selection = camera.id }
                            .help("Click to control, double-click to open")
                    }
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            controlColumn
                .frame(width: 352)
        }
        .background { numberKeyShortcuts }
        .onAppear {
            if selectedCamera == nil { selection = cameras.first?.id }
        }
    }

    @ViewBuilder
    private var controlColumn: some View {
        if let camera = selectedCamera {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(camera.name)
                        .font(.title2.bold())
                    CameraControlPanel(camera: camera)
                        // A new connection for each camera, and again if its settings change.
                        .id(camera)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Text("Click a camera to control it")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Invisible buttons so the number keys 1 to 9 select cameras.
    private var numberKeyShortcuts: some View {
        ForEach(Array(cameras.prefix(9).enumerated()), id: \.element.id) { index, camera in
            Button("Camera \(index + 1)") { selection = camera.id }
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [])
                .opacity(0)
                .accessibilityHidden(true)
        }
    }
}

/// One camera's live feed with its number and name. The selected camera has a colored border.
struct CameraTile: View {
    let camera: Camera
    let number: Int
    let isSelected: Bool

    var body: some View {
        LiveVideoView(camera: camera)
            .id(camera)
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 6) {
                    Text("\(number)")
                        .font(.caption.bold())
                        .monospacedDigit()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            isSelected ? Color.accentColor : Color.black.opacity(0.6),
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                    Text(camera.name)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .shadow(color: .black, radius: 2)
                }
                .foregroundStyle(.white)
                .padding(8)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
            }
            .contentShape(RoundedRectangle(cornerRadius: 10))
    }
}
