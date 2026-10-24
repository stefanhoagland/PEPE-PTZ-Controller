import PTZCore
import SwiftUI

/// Sheet for adding or editing a camera.
struct CameraFormView: View {
    let title: String
    let onSave: (Camera, String) -> Void

    @State private var camera: Camera
    @State private var password: String
    @State private var showErrors = false
    @Environment(\.dismiss) private var dismiss

    init(title: String, camera: Camera, password: String, onSave: @escaping (Camera, String) -> Void) {
        self.title = title
        self.onSave = onSave
        _camera = State(initialValue: camera)
        _password = State(initialValue: password)
    }

    private var trimmed: Camera {
        var copy = camera
        copy.name = copy.name.trimmingCharacters(in: .whitespaces)
        copy.host = copy.host.trimmingCharacters(in: .whitespaces)
        copy.username = copy.username.trimmingCharacters(in: .whitespaces)
        return copy
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Form {
                Section(title) {
                    TextField("Name", text: $camera.name, prompt: Text("Stage Left"))
                    Toggle("Simulated camera (no hardware)", isOn: $camera.isSimulated)
                    if !camera.isSimulated {
                        TextField("IP address", text: $camera.host, prompt: Text("192.168.0.10"))
                        TextField("Port", value: $camera.port, format: .number.grouping(.never))
                    }
                }
                if !camera.isSimulated {
                    Section("Login") {
                        TextField("Username", text: $camera.username, prompt: Text("admin"))
                        SecureField("Password", text: $password)
                    }
                }
                if showErrors {
                    let errors = trimmed.validate()
                    if !errors.isEmpty {
                        Section {
                            ForEach(errors, id: \.self) { error in
                                Label(error.description, systemImage: "exclamationmark.triangle")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 420)
    }

    private func save() {
        let result = trimmed
        guard result.validate().isEmpty else {
            showErrors = true
            return
        }
        onSave(result, password)
        dismiss()
    }
}
