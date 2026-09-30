import Foundation
import KassetteCore

/// Joue une face du début à la fin, avec l'amorce, les blancs entre morceaux et un arrêt net
/// à la fin de chaque morceau (sinon Spotify enchaîne tout seul sur autre chose).
@MainActor
final class Enregistreur: ObservableObject {
    enum Phase: Equatable {
        case pret, compteARebours(Int), amorce(TimeInterval), lecture(index: Int), blanc(TimeInterval), fini, erreur(String)
    }

    @Published private(set) var phase: Phase = .pret
    @Published private(set) var face: Face = .a
    @Published private(set) var positionMorceau: TimeInterval = 0
    @Published private(set) var ecoule: TimeInterval = 0
    private var tache: Task<Void, Never>?

    var enCours: Bool { tache != nil }

    func demarrer(_ face: Face, morceaux: [Morceau], reglages: ReglagesEnregistrement, compteARebours: Int = 5) {
        guard tache == nil, !morceaux.isEmpty else { return }
        self.face = face
        tache = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.jouerFace(morceaux, reglages, compteARebours)
                self.phase = .fini
            } catch is CancellationError {
                try? LecteurSpotify.pause()
                self.phase = .pret
            } catch {
                try? LecteurSpotify.pause()
                self.phase = .erreur(error.localizedDescription)
            }
            self.tache = nil
        }
    }

    func arreter() { tache?.cancel() }

    func reinitialiser() { if tache == nil { phase = .pret; ecoule = 0; positionMorceau = 0 } }

    private func jouerFace(_ morceaux: [Morceau], _ r: ReglagesEnregistrement, _ decompte: Int) async throws {
        ecoule = 0
        if !LecteurSpotify.estOuvert {
            try LecteurSpotify.ouvrir()
            try await Task.sleep(for: .seconds(4))
        }
        try LecteurSpotify.preparer()
        try LecteurSpotify.pause()

        // Le temps de passer la platine de PAUSE à ENREGISTREMENT.
        for s in stride(from: decompte, to: 0, by: -1) {
            phase = .compteARebours(s)
            try await Task.sleep(for: .seconds(1))
        }
        let debut = Date()
        try await attendre(r.amorce) { self.phase = .amorce($0) }

        for (i, m) in morceaux.enumerated() {
            try Task.checkCancellation()
            phase = .lecture(index: i)
            positionMorceau = 0
            try await jouer(m)
            if i < morceaux.count - 1 { try await attendre(r.blanc) { self.phase = .blanc($0) } }
            ecoule = Date().timeIntervalSince(debut)
        }
        ecoule = Date().timeIntervalSince(debut)
    }

    /// Lance un morceau et l'arrête au plus près de sa fin.
    private func jouer(_ m: Morceau) async throws {
        try LecteurSpotify.jouer(m.uri)
        // Attend que Spotify ait vraiment chargé ce morceau.
        let limite = Date().addingTimeInterval(15)
        while true {
            let e = try LecteurSpotify.etat()
            if e.uri == m.uri && e.enLecture { break }
            if Date() > limite { throw LecteurSpotify.Erreur.script("« \(m.titre) » ne démarre pas (connexion, morceau indisponible ?)") }
            try await Task.sleep(for: .milliseconds(100))
        }
        let lancement = Date()
        while true {
            let e = try LecteurSpotify.etat()
            positionMorceau = e.position
            let duree = e.duree > 0 ? e.duree : m.duree
            let reste = duree - e.position
            // Morceau fini (Spotify s'est arrêté tout seul), ou passé à autre chose : on coupe.
            if e.uri != m.uri || !e.enLecture && Date().timeIntervalSince(lancement) > duree - 1.5 { break }
            if reste <= 0.6 {
                try await Task.sleep(for: .seconds(max(0, reste - 0.08)))
                break
            }
            try await Task.sleep(for: .milliseconds(reste < 3 ? 100 : 250))
        }
        try LecteurSpotify.pause()
        positionMorceau = m.duree
    }

    private func attendre(_ secondes: TimeInterval, _ maj: (TimeInterval) -> Void) async throws {
        let fin = Date().addingTimeInterval(secondes)
        while Date() < fin {
            maj(fin.timeIntervalSinceNow)
            try await Task.sleep(for: .milliseconds(100))
        }
    }
}
