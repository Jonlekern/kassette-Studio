import AppKit
import LaFleurCore
import SwiftUI

@main
struct LaFleurStudioApp: App {
    init() {
        // Lancée avec `swift run`, l'app doit se déclarer comme une vraie app à fenêtres.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("LaFleurStudio") {
            Text("LaFleurStudio").frame(minWidth: 1100, minHeight: 720)
        }
    }
}
