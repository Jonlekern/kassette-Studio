import AppKit
import SwiftUI

@main
struct KassetteRecorderApp: App {
    @StateObject private var modele = Modele()
    @StateObject private var enregistreur = Enregistreur()

    init() {
        // Lancée avec `swift run`, l'app doit se déclarer comme une vraie app à fenêtres.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("Kassette Recorder") {
            VuePrincipale()
                .environmentObject(modele)
                .environmentObject(enregistreur)
                .frame(minWidth: 1000, minHeight: 640)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Nouvelle mixtape") { modele.nouvelleMixtape() }.keyboardShortcut("n")
            }
        }
        Settings {
            VueReglages().environmentObject(modele).frame(width: 520)
        }
    }
}
