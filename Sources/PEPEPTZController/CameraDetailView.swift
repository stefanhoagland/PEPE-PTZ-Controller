import PTZCore
import SwiftUI

/// The main area for the selected camera: details, live view (step 3) and controls.
struct CameraDetailView: View {
    let camera: Camera
    let onEdit: () -> Void

    @StateObject private var controller: CameraController

    init(camera: Camera, onEdit: @escaping () -> Void) {
        self.camera = camera
        self.onEdit = onEdit
        _controller = StateObject(wrappedValue: CameraController(
            camera: camera,
            password: camera.isSimulated ? nil : Keychain.password(for: camera.id)
        ))
    }

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
                    VStack(spacing: 8) {
                        Image(systemName: "play.rectangle").font(.system(size: 36)).foregroundStyle(.secondary)
                        Text("Live view").font(.headline)
                        Text("Coming in step 3").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))

                    ControlsView(controller: controller)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .onDisappear { controller.stopEverything() }
    }
}
