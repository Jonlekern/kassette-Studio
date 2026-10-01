import Foundation
import Security

/// Clés et jetons (Claude, GPT, Gemini, Discogs, Spotify), rangés dans le trousseau du Mac.
///
/// Tout est dans **un seul** élément du trousseau (« coffre »), lu **une seule fois** par lancement :
/// l'app n'étant pas signée par Apple, macOS redemande l'autorisation après chaque mise à jour, et il
/// vaut mieux une seule fenêtre que cinq. La lecture se fait hors du fil principal (voir `EtatApp.chargerCles`),
/// pour que la fenêtre de l'app s'affiche même pendant que macOS pose sa question.
public enum Trousseau {
    private static let service = "ch.lafleurstudio.app"
    private static let compteCoffre = "coffre"
    /// Anciens éléments séparés (versions précédentes), repris une fois dans le coffre puis supprimés.
    private static let anciensComptes = ["claude", "openai", "gemini", "discogs", "spotify-jetons"]
    private static let verrou = NSLock()
    private nonisolated(unsafe) static var cache: [String: String]?

    /// Lit le coffre (et reprend les anciens éléments). Bloquant tant que macOS attend une réponse.
    public static func charger() {
        verrou.lock(); defer { verrou.unlock() }
        guard cache == nil else { return }
        var coffre: [String: String] = [:]
        if let d = lireElement(compteCoffre), let c = try? JSONDecoder().decode([String: String].self, from: d) {
            coffre = c
        } else {
            for compte in anciensComptes {
                if let d = lireElement(compte), let v = String(data: d, encoding: .utf8), !v.isEmpty { coffre[compte] = v }
            }
            if !coffre.isEmpty, enregistrerElement(compteCoffre, try? JSONEncoder().encode(coffre)) {
                anciensComptes.forEach { supprimerElement($0) }
            }
        }
        cache = coffre
    }

    public static var estCharge: Bool { verrou.lock(); defer { verrou.unlock() }; return cache != nil }

    public static func lire(_ compte: String) -> String? {
        charger()
        verrou.lock(); defer { verrou.unlock() }
        return cache?[compte]
    }

    public static func ecrire(_ compte: String, _ valeur: String?) {
        charger()
        verrou.lock(); defer { verrou.unlock() }
        var c = cache ?? [:]
        guard c[compte] != (valeur?.isEmpty == false ? valeur : nil) else { return }
        if let v = valeur, !v.isEmpty { c[compte] = v } else { c[compte] = nil }
        cache = c
        _ = enregistrerElement(compteCoffre, try? JSONEncoder().encode(c))
    }

    public static func lireJSON<T: Decodable>(_ compte: String, _ type: T.Type) -> T? {
        lire(compte).flatMap { try? JSONDecoder().decode(T.self, from: Data($0.utf8)) }
    }

    public static func ecrireJSON<T: Encodable>(_ compte: String, _ valeur: T?) {
        ecrire(compte, valeur.flatMap { try? JSONEncoder().encode($0) }.map { String(decoding: $0, as: UTF8.self) })
    }

    // MARK: Accès bruts au trousseau

    private static func base(_ compte: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: compte]
    }

    private static func lireElement(_ compte: String) -> Data? {
        var q = base(compte)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var res: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &res) == errSecSuccess else { return nil }
        return res as? Data
    }

    /// Met à jour l'élément s'il existe (garde ses autorisations), sinon le crée.
    private static func enregistrerElement(_ compte: String, _ donnees: Data?) -> Bool {
        guard let donnees else { return false }
        let maj = SecItemUpdate(base(compte) as CFDictionary, [kSecValueData as String: donnees] as CFDictionary)
        if maj == errSecSuccess { return true }
        var ajout = base(compte)
        ajout[kSecValueData as String] = donnees
        return SecItemAdd(ajout as CFDictionary, nil) == errSecSuccess
    }

    private static func supprimerElement(_ compte: String) {
        SecItemDelete(base(compte) as CFDictionary)
    }
}

/// Correction d'une imprimante, mesurée sur la règle imprimée.
public struct CalibrationImprimante: Codable, Hashable, Sendable {
    /// Échelle à appliquer (1 = 100 %). Règle de 10 cm imprimée à 9,8 cm → 10 / 9,8 = 102 %.
    public var echelleX = 1.0
    public var echelleY = 1.0
    /// Décalage (mm, positif = vers la droite / vers le bas).
    public var decalageX = 0.0
    public var decalageY = 0.0
    public init() {}

    /// La règle de `attendu` (cm ou in) a été mesurée à `mesure` (même unité).
    public static func echelle(attendu: Double, mesure: Double) -> Double? {
        guard mesure > 0, attendu > 0 else { return nil }
        let e = attendu / mesure
        return (0.8...1.25).contains(e) ? e : nil
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
    /// Calibrage de chaque imprimante (nom de l'imprimante → correction).
    public var calibrations: [String: CalibrationImprimante] = [:]
    /// Imprimante choisie pour imprimer les jaquettes (nil = celle par défaut du Mac).
    public var imprimante: String?
    /// Papier de la page de calibrage : "A4" ou "Letter".
    public var papierCalibrage = "A4"
    /// Unité préférée pour mesurer la règle : "cm" ou "in".
    public var uniteMesure = "cm"
    /// Moteur d'IA choisi (Claude par défaut) et modèle par moteur (vide = modèle par défaut).
    public var fournisseurIA: FournisseurIA = .claude
    public var modelesIA: [String: String] = [:]
    /// Dernière version lancée, et s'il y a des clés dans le trousseau : pour prévenir avant la question de macOS.
    public var derniereVersion = ""
    public var cleEnregistree = false
    enum CodingKeys: String, CodingKey {
        case conditionsAcceptees, spotifyClientID, dossierAudio, sortieAudioUID, platine, egaliserVolume, rechercheWebClaude, langue, prochainNumero, prefixeCatalogue, calibrations, imprimante, papierCalibrage, uniteMesure, fournisseurIA, modelesIA, derniereVersion, cleEnregistree
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
        calibrations = v(.calibrations, d.calibrations)
        imprimante = v(.imprimante, d.imprimante)
        papierCalibrage = v(.papierCalibrage, d.papierCalibrage)
        uniteMesure = v(.uniteMesure, d.uniteMesure)
        fournisseurIA = v(.fournisseurIA, d.fournisseurIA)
        modelesIA = v(.modelesIA, d.modelesIA)
        derniereVersion = v(.derniereVersion, d.derniereVersion)
        cleEnregistree = v(.cleEnregistree, d.cleEnregistree)
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
