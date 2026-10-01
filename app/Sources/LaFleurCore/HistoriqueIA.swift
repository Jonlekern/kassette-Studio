import Foundation

/// Un échange avec l'IA, gardé avec la cassette (demande 7). Ne contient jamais de clé API.
public struct EchangeIA: Codable, Hashable, Identifiable, Sendable {
    public var id = UUID()
    public var date = Date()
    /// La demande telle que tapée, ou le bouton utilisé (« Proposer », « Vérifier »…).
    public var demande: String
    /// Moteur et modèle (« Claude · claude-opus-5-5 »).
    public var moteur: String
    public var reponse: String
    /// Ce qui a changé : « titre : 15 pt → 20 pt », « etiquettePochette : petite → aucune »…
    public var changements: [String]
    /// Coût estimé en dollars (nil si inconnu).
    public var cout: Double?
    /// La jaquette juste après cet échange, pour y revenir d'un clic.
    public var designApres: Design?
    /// Peut être refaite telle quelle (une demande tapée, pas un bouton).
    public var refaisable: Bool

    public init(demande: String, moteur: String, reponse: String, changements: [String], cout: Double?, designApres: Design?,
                refaisable: Bool) {
        self.demande = demande; self.moteur = moteur; self.reponse = reponse; self.changements = changements
        self.cout = cout; self.designApres = designApres; self.refaisable = refaisable
    }
}

/// Jetons consommés pendant une demande, pour estimer son coût.
public final class CompteurJetons: @unchecked Sendable {
    private let verrou = NSLock()
    private var entree = 0, sortie = 0, cacheLu = 0
    public init() {}
    public func ajouter(entree e: Int, sortie s: Int, cacheLu c: Int = 0) {
        verrou.lock(); entree += e; sortie += s; cacheLu += c; verrou.unlock()
    }
    public var total: (entree: Int, sortie: Int, cacheLu: Int) { verrou.lock(); defer { verrou.unlock() }; return (entree, sortie, cacheLu) }

    /// Coût approximatif en dollars, d'après les tarifs publics (dollars par million de jetons).
    public func cout(modele: String) -> Double? {
        guard let t = Self.tarif(modele) else { return nil }
        let (e, s, c) = total
        guard e + s > 0 else { return nil }
        return (Double(e) * t.entree + Double(c) * t.cache + Double(s) * t.sortie) / 1_000_000
    }

    /// Tarifs connus (entrée, entrée lue en cache, sortie), en dollars par million de jetons.
    static func tarif(_ modele: String) -> (entree: Double, cache: Double, sortie: Double)? {
        if modele.hasPrefix("claude-opus-5-5") { return (4, 0.2, 20) }
        if modele.hasPrefix("claude-opus") { return (5, 0.5, 25) }
        if modele.hasPrefix("claude-sonnet-5") { return (2, 0.2, 10) }
        if modele.hasPrefix("claude-haiku") { return (1, 0.1, 5) }
        if modele.hasPrefix("gpt-6-astra") { return (10, 1, 50) }
        return nil
    }
}

extension Projet {
    /// Historique des demandes faites à l'IA pour cette cassette (le plus récent à la fin).
    public var echangesIA: [EchangeIA] {
        get { historiqueIA ?? [] }
        set { historiqueIA = newValue.isEmpty ? nil : Array(newValue.suffix(200)) }
    }
}
