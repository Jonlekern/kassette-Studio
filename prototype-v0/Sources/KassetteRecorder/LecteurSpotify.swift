import Foundation

/// Pilote l'application Spotify du Mac par AppleScript : c'est elle qui joue le son,
/// l'app se contente de lancer chaque morceau et de l'arrêter pile à la fin.
@MainActor
enum LecteurSpotify {
    enum Erreur: LocalizedError {
        case script(String)
        var errorDescription: String? {
            switch self { case .script(let m): "Commande Spotify impossible : \(m)" }
        }
    }

    struct Etat { var enLecture: Bool; var uri: String; var position: TimeInterval; var duree: TimeInterval }

    @discardableResult
    private static func executer(_ source: String) throws -> NSAppleEventDescriptor {
        var erreur: NSDictionary?
        guard let script = NSAppleScript(source: source) else { throw Erreur.script("script invalide") }
        let r = script.executeAndReturnError(&erreur)
        if let e = erreur {
            let msg = e[NSAppleScript.errorMessage] as? String ?? "\(e)"
            throw Erreur.script(msg + " — vérifie que l'app Spotify est installée et que Kassette Recorder a le droit de la contrôler (Réglages Système → Confidentialité → Automatisation).")
        }
        return r
    }

    static var estOuvert: Bool {
        (try? executer(#"application "Spotify" is running"#).booleanValue) ?? false
    }

    static func ouvrir() throws { try executer(#"tell application "Spotify" to activate"#) }

    /// Coupe lecture aléatoire et répétition, qui casseraient l'ordre de la face.
    static func preparer() throws {
        try executer(#"tell application "Spotify" to set shuffling to false"#)
        try executer(#"tell application "Spotify" to set repeating to false"#)
    }

    static func jouer(_ uri: String) throws {
        guard uri.hasPrefix("spotify:track:"), !uri.contains("\"") else { throw Erreur.script("URI invalide") }
        try executer("tell application \"Spotify\" to play track \"\(uri)\"")
    }

    static func pause() throws { try executer(#"tell application "Spotify" to pause"#) }

    static func etat() throws -> Etat {
        // Une seule requête : état|uri|position (s)|durée (ms)
        let r = try executer("""
        tell application "Spotify"
            if player state is stopped then return "stopped|||"
            return (player state as string) & "|" & (id of current track) & "|" & (player position as string) & "|" & (duration of current track as string)
        end tell
        """)
        let p = (r.stringValue ?? "").components(separatedBy: "|")
        func nombre(_ s: String) -> Double { Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0 }
        guard p.count == 4 else { return Etat(enLecture: false, uri: "", position: 0, duree: 0) }
        return Etat(enLecture: p[0] == "playing", uri: p[1], position: nombre(p[2]), duree: nombre(p[3]) / 1000)
    }
}
