import AppKit
import LaFleurCore
import SwiftUI

@main
struct LaFleurStudioApp: App {
    @StateObject private var etat = EtatApp()
    @StateObject private var moteur = MoteurEnregistrement()

    init() {
        // Lancée avec `swift run`, l'app doit se déclarer comme une vraie app à fenêtres.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("LaFleurStudio") {
            Racine()
                .environmentObject(etat)
                .environmentObject(moteur)
                .frame(minWidth: 1180, minHeight: 760)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Nouvelle cassette") { etat.nouvelleCassette() }.keyboardShortcut("n")
            }
        }
        Settings {
            Reglages().environmentObject(etat).environmentObject(moteur)
        }
    }
}
