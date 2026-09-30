import Foundation
import Security

/// Secrets rangés dans le trousseau macOS (clé Claude, jetons Spotify).
public enum Trousseau {
    private static let service = "ch.lafleurstudio.app"

    public static func lire(_ compte: String) -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: compte, kSecReturnData as String: true,
                                kSecMatchLimit as String: kSecMatchLimitOne]
        var res: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &res) == errSecSuccess, let d = res as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    public static func ecrire(_ compte: String, _ valeur: String?) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                   kSecAttrAccount as String: compte]
        SecItemDelete(base as CFDictionary)
        guard let v = valeur, !v.isEmpty else { return }
        var ajout = base
        ajout[kSecValueData as String] = Data(v.utf8)
        SecItemAdd(ajout as CFDictionary, nil)
    }

    public static func lireJSON<T: Decodable>(_ compte: String, _ type: T.Type) -> T? {
        lire(compte).flatMap { try? JSONDecoder().decode(T.self, from: Data($0.utf8)) }
    }

    public static func ecrireJSON<T: Encodable>(_ compte: String, _ valeur: T?) {
        ecrire(compte, valeur.flatMap { try? JSONEncoder().encode($0) }.map { String(decoding: $0, as: UTF8.self) })
    }
}

/// Réglages de l'app (hors secrets).
public struct Preferences: Codable, Equatable, Sendable {
    public var conditionsAcceptees = false
    public var spotifyClientID = ""
    public var dossierAudio: URL?
    /// Identifiant CoreAudio (UID) de la sortie vers la platine ; nil = sortie par défaut du Mac.
    public var sortieAudioUID: String?
    public var platine = ReglagesPlatine()
    public var egaliserVolume = false
    public var rechercheWebClaude = true
    public var langue = "fr"
    public var prochainNumero = 1
    public var prefixeCatalogue = "LFS"
    /// Décalage de l'imprimante mesuré sur la page de calibrage (mm, positif = vers la droite / vers le bas).
    public var decalageX = 0.0
    public var decalageY = 0.0
    public var calibrationFaite = false
    enum CodingKeys: String, CodingKey {
        case conditionsAcceptees, spotifyClientID, dossierAudio, sortieAudioUID, platine, egaliserVolume, rechercheWebClaude, langue, prochainNumero, prefixeCatalogue, decalageX, decalageY, calibrationFaite
    }

    /// Décodage tolérant : un réglage absent (ancienne version) prend sa valeur par défaut.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Preferences()
        func v<T: Decodable>(_ k: CodingKeys, _ defaut: T) -> T { ((try? c.decodeIfPresent(T.self, forKey: k)) ?? nil) ?? defaut }
        conditionsAcceptees = v(.conditionsAcceptees, d.conditionsAcceptees)
        spotifyClientID = v(.spotifyClientID, d.spotifyClientID)
        dossierAudio = v(.dossierAudio, d.dossierAudio)
        sortieAudioUID = v(.sortieAudioUID, d.sortieAudioUID)
        platine = v(.platine, d.platine)
        egaliserVolume = v(.egaliserVolume, d.egaliserVolume)
        rechercheWebClaude = v(.rechercheWebClaude, d.rechercheWebClaude)
        langue = v(.langue, d.langue)
        prochainNumero = v(.prochainNumero, d.prochainNumero)
        prefixeCatalogue = v(.prefixeCatalogue, d.prefixeCatalogue)
        decalageX = v(.decalageX, d.decalageX)
        decalageY = v(.decalageY, d.decalageY)
        calibrationFaite = v(.calibrationFaite, d.calibrationFaite)
    }

    public init() {}

    public var premierDemarrageFini: Bool { conditionsAcceptees }
}

/// Sauvegarde sur le Mac : ~/Library/Application Support/LaFleurStudio.
public struct Stockage: Sendable {
    public let racine: URL

    public init(racine: URL? = nil) {
        self.racine = racine ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LaFleurStudio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dossierProjets, withIntermediateDirectories: true)
    }

    var dossierProjets: URL { racine.appendingPathComponent("projets", isDirectory: true) }
    var fichierPreferences: URL { racine.appendingPathComponent("preferences.json") }

    private static let encodeur: JSONEncoder = {
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; e.dateEncodingStrategy = .iso8601; return e
    }()
    private static let decodeur: JSONDecoder = { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }()

    public func preferences() -> Preferences {
        (try? Data(contentsOf: fichierPreferences)).flatMap { try? Self.decodeur.decode(Preferences.self, from: $0) } ?? Preferences()
    }

    public func enregistrer(_ p: Preferences) throws {
        try Self.encodeur.encode(p).write(to: fichierPreferences, options: .atomic)
    }

    public func enregistrer(_ projet: Projet) throws {
        var p = projet; p.modifieLe = Date()
        try Self.encodeur.encode(p).write(to: dossierProjets.appendingPathComponent("\(p.id.uuidString).json"), options: .atomic)
    }

    public func projets() -> [Projet] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: dossierProjets, includingPropertiesForKeys: nil)) ?? []
        return urls.filter { $0.pathExtension == "json" }
            .compactMap { (try? Data(contentsOf: $0)).flatMap { try? Self.decodeur.decode(Projet.self, from: $0) } }
            .sorted { $0.numeroCatalogue.localizedStandardCompare($1.numeroCatalogue) == .orderedAscending }
    }

    public func supprimer(_ projet: Projet) {
        try? FileManager.default.removeItem(at: dossierProjets.appendingPathComponent("\(projet.id.uuidString).json"))
    }

    /// Numéro de catalogue suivant (LFS-001, LFS-002…), et avance le compteur.
    public static func numero(_ prefs: inout Preferences) -> String {
        defer { prefs.prochainNumero += 1 }
        return String(format: "%@-%03d", prefs.prefixeCatalogue, prefs.prochainNumero)
    }
}
