import AppKit
import KassetteCore
import SwiftUI
import UniformTypeIdentifiers

/// État de l'app : la mixtape en cours (sauvegardée automatiquement) et les connexions Spotify / Claude.
@MainActor
final class Modele: ObservableObject {
    @Published var mix: Mixtape { didSet { sauvegarder() } }
    @Published var statut = ""
    @Published var occupe = false
    @Published var playlists: [ClientSpotify.Playlist] = []
    @Published var resultats: [Morceau] = []
    @Published var commentaireClaude = ""
    @Published private(set) var spotifyConnecte = false

    @Published var cleClaude: String { didSet { Trousseau.ecrire("claude", cleClaude) } }
    @Published var clientIDSpotify: String {
        didSet { Trousseau.ecrire("spotify-client-id", clientIDSpotify); spotify = nil; spotifyConnecte = false }
    }

    private var spotify: ClientSpotify?
    private let retour = RetourConnexion()

    init() {
        mix = (try? Data(contentsOf: Self.fichierMix)).flatMap { try? JSONDecoder().decode(Mixtape.self, from: $0) } ?? Mixtape()
        cleClaude = Trousseau.lire("claude") ?? ""
        clientIDSpotify = Trousseau.lire("spotify-client-id") ?? ""
        spotifyConnecte = Trousseau.lireJSON("spotify-jetons", ClientSpotify.Jetons.self) != nil
    }

    // MARK: Sauvegarde automatique

    private static var fichierMix: URL {
        let dossier = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Kassette Recorder", isDirectory: true)
        try? FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        return dossier.appendingPathComponent("mixtape.json")
    }

    private func sauvegarder() { try? JSONEncoder().encode(mix).write(to: Self.fichierMix, options: .atomic) }

    // MARK: Tâches longues

    /// Lance une action asynchrone en affichant son avancement et ses erreurs.
    func lancer(_ message: String, _ action: @escaping () async throws -> Void) {
        guard !occupe else { return }
        occupe = true; statut = message
        Task {
            do { try await action() } catch { statut = "⚠︎ " + error.localizedDescription }
            occupe = false
        }
    }

    // MARK: Spotify

    private func clientSpotify() throws -> ClientSpotify {
        if let spotify { return spotify }
        guard !clientIDSpotify.isEmpty else { throw ClientSpotify.Erreur.nonConnecte }
        let c = ClientSpotify(clientID: clientIDSpotify, jetons: Trousseau.lireJSON("spotify-jetons", ClientSpotify.Jetons.self)) {
            Trousseau.ecrireJSON("spotify-jetons", $0)
        }
        spotify = c
        return c
    }

    func connecterSpotify() {
        lancer("Connexion à Spotify dans ton navigateur…") { [self] in
            let c = try clientSpotify()
            let demande = c.preparerConnexion()
            async let reponse = retour.attendre(port: ClientSpotify.portRedirection)
            try await Task.sleep(for: .milliseconds(200))
            NSWorkspace.shared.open(demande.url)
            let p = try await reponse
            guard p["state"] == demande.etat, let code = p["code"] else {
                throw ClientSpotify.Erreur.http(0, p["error"] ?? "réponse inattendue")
            }
            try await c.terminerConnexion(code: code, verificateur: demande.verificateur)
            spotifyConnecte = true
            statut = "Spotify connecté ✓"
            playlists = try await c.mesPlaylists()
        }
    }

    func annulerConnexion() { retour.annuler() }

    func deconnecterSpotify() {
        Trousseau.ecrireJSON("spotify-jetons", Optional<ClientSpotify.Jetons>.none)
        spotify = nil; spotifyConnecte = false; playlists = []
    }

    func chargerPlaylists() {
        lancer("Chargement de tes playlists…") { [self] in
            playlists = try await clientSpotify().mesPlaylists()
            statut = "\(playlists.count) playlists"
        }
    }

    func importer(playlist: ClientSpotify.Playlist) {
        lancer("Import de « \(playlist.name) »…") { [self] in
            ajouterEnReserve(try await clientSpotify().morceauxDePlaylist(playlist.id))
        }
    }

    func importer(lien: String) {
        lancer("Import du lien…") { [self] in ajouterEnReserve(try await clientSpotify().importer(lien: lien)) }
    }

    func chercher(_ requete: String) {
        guard !requete.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        lancer("Recherche…") { [self] in
            resultats = try await clientSpotify().chercher(requete)
            statut = resultats.isEmpty ? "Rien trouvé" : ""
        }
    }

    func ajouterEnReserve(_ l: [Morceau]) {
        let deja = Set(mix.tous.map(\.id))
        let nouveaux = l.filter { !deja.contains($0.id) }
        mix.reserve += nouveaux
        statut = "\(nouveaux.count) morceau(x) ajouté(s) à la réserve" + (nouveaux.count < l.count ? " (doublons ignorés)" : "")
    }

    // MARK: Claude

    private func claude() throws -> ClientClaude {
        guard !cleClaude.isEmpty else {
            throw ClientClaude.Erreur.http(401, "ajoute ta clé API Claude dans les Réglages (⌘,)")
        }
        return ClientClaude(cleAPI: cleClaude)
    }

    func composer(ambiance: String) {
        lancer("Claude compose ta mixtape…") { [self] in
            let proposition = try await claude().composer(ambiance: ambiance, cassette: mix.cassette,
                                                         dejaChoisis: mix.faceA + mix.faceB)
            statut = "Recherche des \(proposition.morceaux.count) morceaux sur Spotify…"
            let sp = try clientSpotify()
            var trouves: [Morceau] = [], introuvables: [String] = []
            for idee in proposition.morceaux {
                if let m = try await sp.trouver(artiste: idee.artiste, titre: idee.titre) { trouves.append(m) }
                else { introuvables.append("\(idee.artiste) - \(idee.titre)") }
            }
            if mix.faceA.isEmpty && mix.faceB.isEmpty { mix.jaquette.titre = proposition.titre }
            ajouterEnReserve(trouves)
            if !introuvables.isEmpty { statut += " — introuvables : " + introuvables.joined(separator: ", ") }
        }
    }

    func equilibrer() {
        let tous = mix.faceA + mix.faceB + mix.reserve
        guard !tous.isEmpty else { return }
        lancer("Claude répartit les faces…") { [self] in
            let ordre = try await claude().equilibrer(tous, cassette: mix.cassette, reglages: mix.reglages)
            let (a, b, reste) = appliquerOrdre(tous, indicesA: ordre.face_a, indicesB: ordre.face_b, mix.cassette, mix.reglages)
            mix.faceA = a; mix.faceB = b; mix.reserve = reste
            commentaireClaude = ordre.commentaire
            statut = "Faces réparties ✓" + (reste.isEmpty ? "" : " — \(reste.count) morceau(x) laissé(s) en réserve")
        }
    }

    func repartirSimplement() {
        let (a, b, reste) = repartirDansLOrdre(mix.faceA + mix.faceB + mix.reserve, mix.cassette, mix.reglages)
        mix.faceA = a; mix.faceB = b; mix.reserve = reste
    }

    func ecrireJaquette(idee: String) {
        lancer("Claude écrit la jaquette…") { [self] in
            let t = try await claude().jaquette(mix, idee: idee)
            mix.jaquette.titre = t.titre; mix.jaquette.artiste = t.artiste; mix.jaquette.tranche = t.tranche
            mix.jaquette.rabat = t.rabat; mix.jaquette.production = t.production
            statut = "Jaquette écrite ✓"
        }
    }

    // MARK: Faces

    func deplacer(_ m: Morceau, vers destination: Face?) {
        mix.faceA.removeAll { $0.id == m.id }; mix.faceB.removeAll { $0.id == m.id }; mix.reserve.removeAll { $0.id == m.id }
        switch destination {
        case .a: mix.faceA.append(m)
        case .b: mix.faceB.append(m)
        case nil: mix.reserve.append(m)
        }
    }

    func supprimer(_ m: Morceau) {
        mix.faceA.removeAll { $0.id == m.id }; mix.faceB.removeAll { $0.id == m.id }; mix.reserve.removeAll { $0.id == m.id }
    }

    func nouvelleMixtape() {
        var m = Mixtape(); m.cassette = mix.cassette; m.reglages = mix.reglages
        mix = m; commentaireClaude = ""; resultats = []
    }

    // MARK: Exports

    struct Pochette: Identifiable { let album: String; let url: URL; var id: URL { url } }

    /// Une pochette par album présent dans la mixtape.
    var pochettes: [Pochette] {
        var vues = Set<URL>(), l: [Pochette] = []
        for m in mix.faceA + mix.faceB + mix.reserve { if let u = m.pochetteURL, vues.insert(u).inserted { l.append(Pochette(album: m.album, url: u)) } }
        return l
    }

    func exporterKassetteCreator() {
        lancer("Export…") { [self] in
            var dataURL: String?
            if let u = mix.jaquette.pochetteURL ?? pochettes.first?.url {
                let (d, _) = try await URLSession.shared.data(from: u)
                dataURL = "data:image/jpeg;base64," + d.base64EncodedString()
            }
            let data = try Export.projetKassetteCreator(mix, pochetteDataURL: dataURL)
            enregistrer(data, nom: Export.nomFichier(mix) + ".json", type: .json)
            statut = "Ouvre ce fichier dans Kassette Creator : Fichier → Ouvrir un projet (.json)"
        }
    }

    func exporterM3U() {
        enregistrer(Data(Export.m3u(mix).utf8), nom: Export.nomFichier(mix) + ".m3u", type: UTType(filenameExtension: "m3u") ?? .plainText)
    }

    func copierTracklist() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Export.tracklistTexte(mix), forType: .string)
        statut = "Tracklist copiée : colle-la dans l'onglet Tracklist de Kassette Creator"
    }

    private func enregistrer(_ data: Data, nom: String, type: UTType) {
        let p = NSSavePanel()
        p.nameFieldStringValue = nom
        p.allowedContentTypes = [type]
        guard p.runModal() == .OK, let url = p.url else { return }
        do { try data.write(to: url) } catch { statut = "⚠︎ " + error.localizedDescription }
    }
}
