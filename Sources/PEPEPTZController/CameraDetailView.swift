import PTZCore
import SwiftUI

/// The main area for the selected camera: details, live view and controls.
struct CameraDetailView: View {
    let camera: Camera
    let onEdit: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .firstTextBaseline) {
                    Text(camera.name).font(.largeTitle.bold())
                    Spacer()
                    Button("Edit…", action: onEdit)
                }

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    GridRow {
                        Text("Address").foregroundStyle(.secondary)
                        if camera.isSimulated {
                            Text("Simulated camera (no hardware)")
                        } else if let url = camera.baseURL {
                            Link(url.absoluteString, destination: url).help("Open the camera's web page")
                        } else {
                            Text(camera.host)
                        }
                    }
                    if !camera.isSimulated {
                        GridRow {
                            Text("Username").foregroundStyle(.secondary)
                            Text(camera.username.isEmpty ? "None" : camera.username)
                        }
                    }
                }

                HStack(alignment: .top, spacing: 20) {
                    LiveVideoView(camera: camera)
                        .frame(minWidth: 320, maxWidth: .infinity)

                    CameraControlPanel(camera: camera)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

/// The control panel for one camera, with its own connection.
/// Leaving it stops any movement.
struct CameraControlPanel: View {
    @StateObject private var controller: CameraController

    init(camera: Camera) {
        _controller = StateObject(wrappedValue: CameraController(
            camera: camera,
            password: camera.isSimulated ? nil : Keychain.password(for: camera.id)
        ))
    }

    var body: some View {
        ControlsView(controller: controller)
            .onDisappear { controller.stopEverything() }
    }
}
