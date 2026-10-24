import Foundation
import PTZCore

/// App-wide state: the camera list, saved to disk after every change.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var library = CameraLibrary()
    @Published var errorMessage: String?

    private let file: CameraLibraryFile?

    init() {
        let file = try? CameraLibraryFile.defaultLocation()
        self.file = file
        guard let file else {
            errorMessage = "Couldn't find the Application Support folder, so cameras won't be saved."
            return
        }
        do {
            library = try file.load()
        } catch {
            errorMessage = "Couldn't read the saved cameras: \(error.localizedDescription)"
        }
    }

    func password(for id: Camera.ID) -> String? {
        Keychain.password(for: id)
    }

    func add(_ camera: Camera, password: String) {
        library.add(camera)
        storePassword(password, for: camera.id)
        save()
    }

    func update(_ camera: Camera, password: String) {
        library.update(camera)
        storePassword(password, for: camera.id)
        save()
    }

    func remove(id: Camera.ID) {
        library.remove(id: id)
        Keychain.deletePassword(for: id)
        save()
    }

    func moveCameras(fromOffsets source: IndexSet, toOffset destination: Int) {
        library.move(fromOffsets: source, toOffset: destination)
        save()
    }

    private func storePassword(_ password: String, for id: Camera.ID) {
        if !Keychain.setPassword(password, for: id) {
            errorMessage = "Couldn't save the password to the Keychain."
        }
    }

    private func save() {
        guard let file else { return }
        do {
            try file.save(library)
        } catch {
            errorMessage = "Couldn't save the camera list: \(error.localizedDescription)"
        }
    }
}
