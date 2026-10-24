import AppKit
import SwiftUI

@main
struct PEPEPTZControllerApp: App {
    @StateObject private var model = AppModel()

    init() {
        // `swift run` starts the app without a bundle, so make it a regular windowed app.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup("PEPE PTZ Controller") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 800, minHeight: 500)
                .onAppear { NSApplication.shared.activate(ignoringOtherApps: true) }
        }
    }
}
