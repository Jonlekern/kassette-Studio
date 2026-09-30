import AppKit
import LaFleurCore
import SwiftUI
import UniformTypeIdentifiers

/// Une question posée à l'utilisateur pour associer un morceau à son fichier.
struct QuestionFichier: Identifiable, Equatable {
    let id = UUID()
    let pisteID: UUID
    let titre: String
    let artiste: String
    let duree: TimeInterval
    let candidats: [InfosFichier]
}

/// Une idée de Claude pour la mixtape, trouvée (ou non) sur Spotify, que l'utilisateur coche ou pas.
struct Proposition: Identifiable, Equatable {
    let id = UUID()
    let idee: PropositionMixtape.Idee
    var morceau: Morceau?
    var gardee = true
}

/// L'état de l'app : réglages, cassette en cours, collection, connexions.
@MainActor
final class EtatApp: ObservableObject {
    let stockage: Stockage

    @Published var prefs: Preferences { didSet { if prefs != oldValue { try? stockage.enregistrer(prefs) } } }
    @Published var projet: Projet { didSet { if projet != oldValue { try? stockage.enregistrer(projet) } } }
    @Published private(set) var collection: [Projet] = []
    @Published var cleClaude: String { didSet { Trousseau.ecrire("claude", cleClaude) } }
    @Published private(set) var spotifyConnecte: Bool

    @Published var statut = String(localized: "Prêt")
    @Published var occupe = false
    @Published var commentaireClaude = ""
    @Published var propositions: [Proposition] = []
    @Published var albumsTrouves: [ClientSpotify.AlbumResume] = []
    @Published var albumsMusicBrainz: [ClientMusicBrainz.Album] = []
    let musicBrainz = ClientMusicBrainz()
    @Published var playlists: [ClientSpotify.Playlist] = []
    @Published var questions: [QuestionFichier] = []
    @Published private(set) var fichiers: [InfosFichier] = []

    // Jaquette
    @Published var conversation: [MessageDesign] = []
    @Published var editionsK7: [EditionK7] = []
    @Published var editionsCherchees = false
    @Published var avisClaude: AvisRendu?
    @Published var policesDisponibles: [String] = Typo.disponibles
    @Published var jetonDiscogs: String { didSet { Trousseau.ecrire("discogs", jetonDiscogs) } }

    private var spotify: ClientSpotify?
    private let retour = RetourConnexion()

    /// `stockage` : un autre dossier pour les captures automatiques (sans toucher aux vraies cassettes).
    init(stockage s: Stockage = Stockage()) {
        stockage = s
        var p = s.preferences()
        let projets = s.projets()
        let courant: Projet
        if let dernier = projets.max(by: { $0.modifieLe < $1.modifieLe }) {
            courant = dernier
        } else {
            courant = Projet(numeroCatalogue: Stockage.numero(&p))
        }
        prefs = p
        projet = courant
        collection = projets
        cleClaude = Trousseau.lire("claude") ?? ""
        jetonDiscogs = Trousseau.lire("discogs") ?? ""
        spotifyConnecte = Trousseau.lireJSON("spotify-jetons", ClientSpotify.Jetons.self) != nil
        try? s.enregistrer(p)
        // Une cassette neuve est enregistrée tout de suite : son numéro n'est jamais perdu.
        try? s.enregistrer(courant)
        collection = s.projets()
    }

    // MARK: Tâches

    func lancer(_ message: String, _ action: @escaping () async throws -> Void) {
        guard !occupe else { return }
        occupe = true; statut = message
        Task {
            do { try await action() } catch { statut = "⚠︎ " + error.localizedDescription }
            occupe = false
        }
    }

    var langueClaude: String {
        switch prefs.langue { case "en": "English"; case "ru": "русский"; case "de": "Deutsch"; default: "français" }
    }

    func claude() throws -> ClientClaude {
        guard !cleClaude.isEmpty else { throw ClientClaude.Erreur.http(401, "ajoute ta clé API Claude dans Réglages") }
        return ClientClaude(cleAPI: cleClaude, langue: langueClaude)
    }

    // MARK: Collection

    func rafraichirCollection() { collection = stockage.projets() }

    func nouvelleCassette(mode: ModeCassette = .album) {
        var p = prefs
        var nouveau = Projet(numeroCatalogue: Stockage.numero(&p))
        nouveau.mode = mode
        nouveau.cassette = projet.cassette
        prefs = p
        projet = nouveau
        commentaireClaude = ""; propositions = []; questions = []
        conversation = []; editionsK7 = []; editionsCherchees = false; avisClaude = nil
        rafraichirCollection()
    }

    func ouvrir(_ p: Projet) {
        projet = p; commentaireClaude = ""; propositions = []; questions = []
        conversation = []; editionsK7 = []; editionsCherchees = false; avisClaude = nil
    }

    func dupliquer(_ p: Projet) {
        var prefs = self.prefs
        var copie = p
        copie.id = UUID(); copie.numeroCatalogue = Stockage.numero(&prefs); copie.enregistree = []
        copie.creeLe = Date()
        self.prefs = prefs
        try? stockage.enregistrer(copie)
        rafraichirCollection()
    }

    func supprimer(_ p: Projet) {
        stockage.supprimer(p)
        rafraichirCollection()
        if p.id == projet.id { nouvelleCassette() }
    }

    // MARK: Spotify

    private func clientSpotify() throws -> ClientSpotify {
        if let spotify { return spotify }
        guard !prefs.spotifyClientID.isEmpty else { throw ClientSpotify.Erreur.nonConnecte }
        let c = ClientSpotify(clientID: prefs.spotifyClientID,
                              jetons: Trousseau.lireJSON("spotify-jetons", ClientSpotify.Jetons.self)) {
            Trousseau.ecrireJSON("spotify-jetons", $0)
        }
        spotify = c
        return c
    }

    func connecterSpotify() {
        spotify = nil
        lancer(String(localized: "Connexion à Spotify dans ton navigateur…")) { [self] in
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
            statut = String(localized: "Spotify connecté ✓")
        }
    }

    func annulerConnexionSpotify() { retour.annuler() }

    func deconnecterSpotify() {
        Trousseau.ecrireJSON("spotify-jetons", Optional<ClientSpotify.Jetons>.none)
        spotify = nil; spotifyConnecte = false; playlists = []
    }

    func chercherAlbums(_ requete: String) {
        guard !requete.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if ClientSpotify.analyserLien(requete) != nil { importerLien(requete); return }
        lancer(String(localized: "Recherche sur Spotify…")) { [self] in
            albumsTrouves = try await clientSpotify().chercherAlbums(requete)
            statut = albumsTrouves.isEmpty ? String(localized: "Rien trouvé") : String(localized: "Albums trouvés : \(albumsTrouves.count)")
        }
    }

    func chargerPlaylists() {
        lancer(String(localized: "Chargement de tes playlists…")) { [self] in playlists = try await clientSpotify().mesPlaylists() }
    }

    func importerAlbum(_ a: ClientSpotify.AlbumResume) {
        lancer(String(localized: "Import de « \(a.titre) »…")) { [self] in
            let morceaux = try await clientSpotify().morceauxDAlbum(a.id)
            projet.titre = a.titre; projet.artiste = a.artiste; projet.pochetteURL = a.pochetteURL
            projet.spotifyAlbumID = a.id; projet.mode = .album
            projet.annee = morceaux.first?.annee
            if let e = try? await clientSpotify().edition(a.id) {
                projet.droits = e.droits
                if let m = e.maison { projet.labelOrigine = m }
            }
            remplir(morceaux)
        }
    }

    func importerPlaylist(_ p: ClientSpotify.Playlist) {
        lancer(String(localized: "Import de « \(p.name) »…")) { [self] in
            let morceaux = try await clientSpotify().morceauxDePlaylist(p.id)
            if projet.titre.isEmpty { projet.titre = p.name }
            projet.mode = .mixtape
            remplir(morceaux)
        }
    }

    func importerLien(_ lien: String) {
        lancer(String(localized: "Import du lien Spotify…")) { [self] in
            let morceaux = try await clientSpotify().importer(lien: lien)
            if let m = morceaux.first, ClientSpotify.analyserLien(lien)?.0 == "album" {
                projet.titre = m.album; projet.artiste = m.artiste; projet.pochetteURL = m.pochetteURL; projet.mode = .album
            }
            remplir(morceaux)
        }
    }

    /// Place les morceaux sur les faces : ordre gardé, coupure A/B la plus équilibrée. Puis association des fichiers.
    private func remplir(_ morceaux: [Morceau]) {
        let pistes = morceaux.map { Piste(morceau: $0) }
        repartirDansLOrdre(pistes)
        Task { await associerFichiers() }
    }

    func repartirDansLOrdre(_ pistes: [Piste]? = nil) {
        let l = pistes ?? projet.toutes
        if let (a, b) = Faces.couperAlbum(l, projet.cassette, prefs.platine) {
            projet.faceA = a; projet.faceB = b
            let da = Faces.duree(a, prefs.platine), db = Faces.duree(b, prefs.platine)
            commentaireClaude = "Ordre gardé. Face A \(formaterDuree(da)), face B \(formaterDuree(db)) : \(formaterDuree(abs(da - db))) d'écart."
        } else {
            let moitie = (l.count + 1) / 2
            projet.faceA = Array(l.prefix(moitie)); projet.faceB = Array(l.dropFirst(moitie))
            commentaireClaude = "Tout ne tient pas sur une \(projet.cassette.longueur.nom) : choisis une cassette plus longue ou retire des morceaux."
        }
    }

    // MARK: MusicBrainz

    func chercherMusicBrainz(_ texte: String) {
        guard !texte.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        lancer(String(localized: "Recherche sur MusicBrainz…")) { [self] in
            albumsMusicBrainz = try await musicBrainz.chercher(texte)
            statut = albumsMusicBrainz.isEmpty ? String(localized: "Rien trouvé sur MusicBrainz (les petits artistes n'y sont pas toujours)") : String(localized: "Éditions trouvées : \(albumsMusicBrainz.count)")
        }
    }

    func importerMusicBrainz(_ a: ClientMusicBrainz.Album) {
        lancer(String(localized: "Import de « \(a.titre) » depuis MusicBrainz…")) { [self] in
            let d = try await musicBrainz.detail(a.id)
            projet.titre = a.titre; projet.artiste = a.artiste; projet.mode = .album
            projet.annee = a.annee; projet.labelOrigine = a.maisonDeDisque; projet.catalogueOrigine = a.catalogue
            projet.codeBarresOrigine = d.codeBarres; projet.musicBrainzID = a.id
            projet.pochetteURL = d.aUnePochette ? a.pochetteURL : projet.pochetteURL
            albumsMusicBrainz = []
            remplir(d.morceaux)
        }
    }

    // MARK: Dossier audio

    func choisirDossier() {
        let panneau = NSOpenPanel()
        panneau.canChooseDirectories = true; panneau.canChooseFiles = false; panneau.prompt = "Choisir"
        guard panneau.runModal() == .OK, let url = panneau.url else { return }
        prefs.dossierAudio = url
        Task { await associerFichiers() }
    }

    func relireDossier() async {
        guard let d = prefs.dossierAudio else { fichiers = []; return }
        statut = String(localized: "Lecture du dossier audio…")
        fichiers = await DossierAudio.lireTout(d)
    }

    /// Cassette faite uniquement à partir du dossier (sans Spotify), dans l'ordre des pistes.
    func importerDossierSeul() {
        lancer(String(localized: "Lecture du dossier…")) { [self] in
            await relireDossier()
            guard !fichiers.isEmpty else { statut = String(localized: "Aucun fichier audio dans ce dossier"); return }
            var pistes = DossierAudio.pistes(depuis: fichiers)
            // Covers intégrées aux fichiers : une par album, copiée dans le dossier de l'app.
            var covers: [String: URL] = [:]
            for i in pistes.indices {
                guard let f = pistes[i].fichier else { continue }
                let album = pistes[i].morceau.album
                if covers[album] == nil, let data = await DossierAudio.pochette(f) {
                    let dossier = stockage.racine.appendingPathComponent("images", isDirectory: true)
                    try? FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
                    let dest = dossier.appendingPathComponent("cover-\(UUID().uuidString).\(data.starts(with: [0x89, 0x50]) ? "png" : "jpg")")
                    if (try? data.write(to: dest)) != nil { covers[album] = dest }
                }
                pistes[i].morceau.pochetteURL = covers[album]
            }
            if projet.pochetteURL == nil { projet.pochetteURL = pistes.first?.morceau.pochetteURL }
            if projet.titre.isEmpty { projet.titre = pistes.first?.morceau.album ?? "" }
            if projet.artiste.isEmpty { projet.artiste = pistes.first?.morceau.artiste ?? "" }
            repartirDansLOrdre(pistes)
            statut = String(localized: "\(pistes.count) fichiers chargés dans l'ordre des pistes")
        }
    }

    /// Associe chaque morceau à son fichier ; les cas douteux deviennent des questions.
    func associerFichiers() async {
        await relireDossier()
        guard !fichiers.isEmpty else { statut = prefs.dossierAudio == nil ? String(localized: "Choisis ton dossier audio") : String(localized: "Aucun fichier audio dans le dossier"); return }
        var nouvelles: [QuestionFichier] = []
        var trouves = 0
        func traiter(_ face: inout [Piste]) {
            for i in face.indices where face[i].fichier == nil {
                switch Association.chercher(face[i].morceau, dans: fichiers) {
                case .certain(let f):
                    face[i].fichier = f.url; face[i].dureeFichier = f.duree; trouves += 1
                case .aConfirmer(let c):
                    nouvelles.append(QuestionFichier(pisteID: face[i].id, titre: face[i].morceau.titre, artiste: face[i].morceau.artiste,
                                                     duree: face[i].morceau.duree, candidats: c))
                case .introuvable:
                    nouvelles.append(QuestionFichier(pisteID: face[i].id, titre: face[i].morceau.titre, artiste: face[i].morceau.artiste,
                                                     duree: face[i].morceau.duree, candidats: []))
                }
            }
        }
        var p = projet
        traiter(&p.faceA); traiter(&p.faceB)
        projet = p
        questions = nouvelles
        let total = projet.toutes.count, associes = projet.toutes.filter { $0.fichier != nil }.count
        statut = nouvelles.isEmpty ? String(localized: "\(associes) / \(total) morceaux associés à un fichier")
            : String(localized: "\(associes) / \(total) morceaux associés à un fichier · \(nouvelles.count) à confirmer")
    }

    /// Réponse à une question : un fichier choisi, ou nil pour retirer le morceau de la cassette.
    func repondre(_ q: QuestionFichier, fichier: URL?, duree: TimeInterval?) {
        questions.removeAll { $0.id == q.id }
        if let fichier {
            modifierPiste(q.pisteID) { $0.fichier = fichier; $0.dureeFichier = duree }
        } else {
            retirer(q.pisteID)
        }
    }

    func choisirFichierAMain(_ q: QuestionFichier) {
        let panneau = NSOpenPanel()
        panneau.allowedContentTypes = [.audio]
        panneau.directoryURL = prefs.dossierAudio
        guard panneau.runModal() == .OK, let url = panneau.url else { return }
        Task {
            let infos = await DossierAudio.lire(url)
            repondre(q, fichier: url, duree: infos?.duree)
        }
    }

    // MARK: Faces

    private func modifierPiste(_ id: UUID, _ f: (inout Piste) -> Void) {
        if let i = projet.faceA.firstIndex(where: { $0.id == id }) { f(&projet.faceA[i]) }
        if let i = projet.faceB.firstIndex(where: { $0.id == id }) { f(&projet.faceB[i]) }
    }

    /// Retire le morceau de la cassette : il ne sera pas enregistré. Rien n'est supprimé sur le Mac.
    func retirer(_ id: UUID) {
        if let i = projet.faceA.firstIndex(where: { $0.id == id }) { dernierRetire = (projet.faceA.remove(at: i), .a, i) }
        if let i = projet.faceB.firstIndex(where: { $0.id == id }) { dernierRetire = (projet.faceB.remove(at: i), .b, i) }
        if let r = dernierRetire { statut = String(localized: "« \(r.piste.morceau.titre) » retiré de la cassette (il ne sera pas enregistré)") }
        commentaireClaude = ""
    }

    /// Dernier morceau retiré, pour pouvoir le remettre à sa place.
    @Published private(set) var dernierRetire: (piste: Piste, face: Face, index: Int)?

    func annulerRetrait() {
        guard let r = dernierRetire else { return }
        if r.face == .a { projet.faceA.insert(r.piste, at: min(r.index, projet.faceA.count)) }
        else { projet.faceB.insert(r.piste, at: min(r.index, projet.faceB.count)) }
        dernierRetire = nil
        statut = String(localized: "« \(r.piste.morceau.titre) » remis à sa place")
    }

    func monter(_ id: UUID, de pas: Int) {
        func bouger(_ l: inout [Piste]) {
            guard let i = l.firstIndex(where: { $0.id == id }) else { return }
            let j = i + pas
            guard l.indices.contains(j) else { return }
            l.swapAt(i, j)
        }
        bouger(&projet.faceA); bouger(&projet.faceB)
        commentaireClaude = ""
    }

    /// La fin de la face A continue au début de la face B, et inversement : l'ordre d'écoute est gardé.
    func changerDeFace(_ id: UUID) {
        commentaireClaude = ""
        if let i = projet.faceA.firstIndex(where: { $0.id == id }) { projet.faceB.insert(projet.faceA.remove(at: i), at: 0) }
        else if let i = projet.faceB.firstIndex(where: { $0.id == id }) { projet.faceA.append(projet.faceB.remove(at: i)) }
    }

    func deplacer(_ face: Face, depuis: IndexSet, vers: Int) {
        commentaireClaude = ""
        if face == .a { projet.faceA.move(fromOffsets: depuis, toOffset: vers) } else { projet.faceB.move(fromOffsets: depuis, toOffset: vers) }
    }

    func viderFaces() { projet.faceA = []; projet.faceB = []; commentaireClaude = "" }

    // MARK: Claude

    func equilibrerAvecClaude() {
        let tout = projet.toutes
        guard !tout.isEmpty else { return }
        lancer(String(localized: "Claude répartit les faces…")) { [self] in
            let o = try await claude().equilibrer(tout, cassette: projet.cassette, reglages: prefs.platine,
                                                  garderOrdre: projet.mode == .album)
            let r = Faces.appliquerOrdre(tout, indicesA: o.face_a, indicesB: o.face_b, projet.cassette, prefs.platine)
            projet.faceA = r.faceA; projet.faceB = r.faceB
            commentaireClaude = o.commentaire + (r.horsBande.isEmpty ? "" : " (\(r.horsBande.count) morceau(x) ne tiennent pas et sont retirés.)")
            statut = String(localized: "Faces réparties par Claude ✓")
        }
    }

    func composer(ambiance: String) {
        lancer(String(localized: "Claude compose la sélection…")) { [self] in
            let prop = try await claude().composer(ambiance: ambiance, cassette: projet.cassette, reglages: prefs.platine, deja: projet.toutes)
            if projet.titre.isEmpty { projet.titre = prop.titre }
            statut = String(localized: "Recherche des titres sur Spotify…")
            let sp = try clientSpotify()
            var liste: [Proposition] = []
            for idee in prop.morceaux {
                let m = try? await sp.trouver(artiste: idee.artiste, titre: idee.titre)
                liste.append(Proposition(idee: idee, morceau: m, gardee: m != nil))
            }
            propositions = liste
            statut = String(localized: "\(liste.filter { $0.morceau != nil }.count) titres trouvés : coche ceux que tu gardes")
        }
    }

    func ajouterPropositions() {
        let nouveaux = propositions.filter(\.gardee).compactMap(\.morceau).map { Piste(morceau: $0) }
        propositions = []
        projet.mode = .mixtape
        repartirDansLOrdre(projet.toutes + nouveaux)
        Task { await associerFichiers() }
    }
}
