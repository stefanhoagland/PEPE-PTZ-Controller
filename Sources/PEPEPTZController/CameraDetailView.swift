import PTZCore
import SwiftUI

/// The main area for the selected camera. Controls and live view come in later steps.
struct CameraDetailView: View {
    let camera: Camera
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text(camera.name).font(.largeTitle.bold())
                Spacer()
                Button("Edit…", action: onEdit)
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Text("Address").foregroundStyle(.secondary)
                    if let url = camera.baseURL {
                        Link(url.absoluteString, destination: url).help("Open the camera's web page")
                    } else {
                        Text(camera.host)
                    }
                }
                GridRow {
                    Text("Username").foregroundStyle(.secondary)
                    Text(camera.username.isEmpty ? "None" : camera.username)
                }
            }

            HStack(spacing: 16) {
                placeholder("Live view", systemImage: "play.rectangle", note: "Coming in step 3")
                placeholder("Controls", systemImage: "dpad", note: "Coming in step 2")
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func placeholder(_ title: String, systemImage: String, note: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage).font(.system(size: 36)).foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(note).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}
