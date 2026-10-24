import PTZCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: Camera.ID?
    @State private var editor: EditorMode?
    @State private var pendingRemoval: Camera?

    enum EditorMode: Identifiable {
        case add
        case edit(Camera)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let camera): return camera.id.uuidString
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            if let id = selection, let camera = model.library.camera(id: id) {
                CameraDetailView(camera: camera) { editor = .edit(camera) }
                    // Start a fresh connection whenever the camera or its settings change.
                    .id(camera)
            } else {
                Text(model.library.cameras.isEmpty ? "Add a camera to get started" : "Select a camera")
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(item: $editor) { mode in
            switch mode {
            case .add:
                CameraFormView(title: "Add Camera", camera: Camera(name: "", host: ""), password: "") { camera, password in
                    model.add(camera, password: password)
                    selection = camera.id
                }
            case .edit(let camera):
                CameraFormView(title: "Edit Camera", camera: camera, password: model.password(for: camera.id) ?? "") { camera, password in
                    model.update(camera, password: password)
                }
            }
        }
        .confirmationDialog(
            "Remove this camera?",
            isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
            presenting: pendingRemoval
        ) { camera in
            Button("Remove \(camera.name)", role: .destructive) {
                if selection == camera.id { selection = nil }
                model.remove(id: camera.id)
            }
        } message: { camera in
            Text("\(camera.name) and its saved password will be removed from this Mac.")
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var sidebar: some View {
        List(selection: $selection) {
            ForEach(model.library.cameras) { camera in
                CameraRow(camera: camera)
                    .tag(camera.id)
                    .contextMenu {
                        Button("Edit…") { editor = .edit(camera) }
                        Button("Remove…", role: .destructive) { pendingRemoval = camera }
                    }
            }
            .onMove { source, destination in
                model.moveCameras(fromOffsets: source, toOffset: destination)
            }
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        .overlay {
            if model.library.cameras.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "video.badge.plus").font(.largeTitle).foregroundStyle(.secondary)
                    Text("No cameras yet").font(.headline)
                    Button("Add Camera") { editor = .add }
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Button { editor = .add } label: {
                    Label("Add Camera", systemImage: "plus")
                }
                .help("Add a camera")
            }
        }
    }
}

struct CameraRow: View {
    let camera: Camera

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(camera.name, systemImage: camera.isSimulated ? "video.badge.ellipsis" : "video")
            Text(camera.isSimulated ? "Simulated" : camera.host)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 24)
        }
        .padding(.vertical, 2)
    }
}
