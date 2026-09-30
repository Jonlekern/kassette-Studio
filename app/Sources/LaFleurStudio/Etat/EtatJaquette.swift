import AppKit
import LaFleurCore
import SwiftUI
import UniformTypeIdentifiers

/// Un message de la conversation avec Claude sur le design.
struct MessageDesign: Identifiable, Equatable {
    let id = UUID()
    let deClaude: Bool
    let texte: String
}

/// Une vraie édition cassette trouvée en ligne, avec ses scans.
struct EditionK7: Identifiable, Hashable {
    let id: String
    let titre: String
    let detail: String
    let source: String
    let page: URL
    let images: [URL]
}

struct Souci: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

extension EtatApp {
    // MARK: Design courant

    var design: Design {
        get { projet.design ?? designParDefaut }
        set { projet.design = newValue }
    }

    var designParDefaut: Design {
        var d = Design()
        if projet.mode == .mixtape { d.variante.style = .collage }
        return d
    }

    var mise: Mise { Mise(projet: projet, design: design) }
    var alertes: [Alerte] { mise.alertes() }
    var alertesBloquantes: [Alerte] { alertes.filter { $0.gravite == .bloquante } }

    /// Toutes les images dont les rendus ont besoin.
    var imagesNecessaires: [URL?] {
        [projet.pochetteURL, design.imagePerso, design.logoMaison, mise.urlCodeSpotify] + projet.toutes.map(\.morceau.pochetteURL)
    }

    func prechargerImages() async { await Images.partage.precharger(imagesNecessaires) }

    // MARK: Éditions K7 existantes (première proposition d'un album)

    func chercherEditionsK7() {
        guard !projet.titre.isEmpty else { statut = String(localized: "Donne d'abord un titre à la cassette."); return }
        lancer(String(localized: "Recherche des vraies éditions cassette de « \(projet.titre) »…")) { [self] in
            try await trouverEditionsK7()
            let n = editionsK7.count
            statut = n == 0 ? String(localized: "Aucune édition cassette trouvée : Claude partira de la pochette.")
                            : String(localized: "Éditions cassette trouvées : \(n)")
        }
    }

    /// MusicBrainz (Cover Art Archive) et, avec un jeton, Discogs : éditions K7 qui ont des scans.
    func trouverEditionsK7() async throws {
        let artiste = projet.artiste, titre = projet.titre
        var res: [EditionK7] = []
        let albums = try await musicBrainz.chercher(artiste.isEmpty ? titre : "\(artiste) - \(titre)", cassetteSeulement: true)
        for a in albums.prefix(6) {
            let imgs = (try? await musicBrainz.images(a.id)) ?? []
            guard !imgs.isEmpty else { continue }
            res.append(EditionK7(id: "mb-\(a.id)", titre: a.titre,
                                 detail: [a.annee, a.maisonDeDisque, a.catalogue].compactMap { $0 }.joined(separator: " · "),
                                 source: "MusicBrainz", page: URL(string: "https://musicbrainz.org/release/\(a.id)")!,
                                 images: imgs.map(\.vignette)))
        }
        if !jetonDiscogs.isEmpty {
            let dc = ClientDiscogs(jeton: jetonDiscogs)
            for e in ((try? await dc.chercher(artiste: artiste, album: titre)) ?? []).prefix(4) {
                let photos = (try? await dc.photos(e.id)) ?? []
                let imgs = photos.isEmpty ? [e.image].compactMap { $0 } : photos.map(\.url)
                guard !imgs.isEmpty else { continue }
                let infos: [String?] = [e.annee, e.pays, e.maisonsDeDisque.first, e.catalogue]
                res.append(EditionK7(id: "dc-\(e.id)", titre: e.titre, detail: infos.compactMap { $0 }.joined(separator: " · "),
                                     source: "Discogs", page: e.page, images: imgs))
            }
        }
        editionsK7 = res
        editionsCherchees = true
    }

    // MARK: Claude directeur artistique

    /// Demande à Claude un design (3 variantes) ou une retouche ; `regenerer` = lettre d'une seule variante à refaire.
    func dirigerDesign(_ demande: String, regenerer: String? = nil) {
        let texte = demande.trimmingCharacters(in: .whitespacesAndNewlines)
        if !texte.isEmpty { conversation.append(MessageDesign(deClaude: false, texte: texte)) }
        if let r = regenerer, texte.isEmpty { conversation.append(MessageDesign(deClaude: false, texte: "Régénère la variante \(r).")) }
        lancer(regenerer == nil ? String(localized: "Claude prépare le design…") : String(localized: "Claude refait la variante \(regenerer!)…")) { [self] in
            let c = try claude()
            // Album, première proposition : d'abord les vraies éditions cassette.
            if projet.mode == .album && design.propositions.isEmpty && !editionsCherchees && !projet.titre.isEmpty {
                statut = String(localized: "Recherche des vraies éditions cassette…")
                try? await trouverEditionsK7()
                statut = String(localized: "Claude prépare le design…")
            }
            await prechargerImages()
            var images: [Data] = [], legendes: [String] = []
            func joindre(_ url: URL?, _ legende: String) async {
                guard images.count < 8, let url, let d = await Images.partage.jpeg(url) else { return }
                images.append(d); legendes.append(legende)
            }
            await joindre(design.imagePerso, "image perso de l'utilisateur")
            if projet.mode == .album {
                await joindre(projet.pochetteURL, "pochette de l'album")
            } else {
                var vues = Set<URL>()
                for u in projet.toutes.compactMap(\.morceau.pochetteURL) where vues.insert(u).inserted && vues.count <= 4 {
                    await joindre(u, "cover d'un morceau de la mixtape")
                }
            }
            for e in editionsK7.prefix(2) {
                for u in e.images.prefix(2) { await joindre(u, "scan d'une vraie édition cassette (\(e.source) : \(e.titre), \(e.detail))") }
            }
            let r = try await c.dirigerDesign(projet: projet, design: design, demande: texte,
                                              conversation: conversation.map { ($0.deClaude ? "Claude : " : "Utilisateur : ") + $0.texte },
                                              polices: Typo.disponibles, images: images, legendes: legendes, regenerer: regenerer)
            var d = design
            let lettres = ["A", "B", "C", "D", "E"]
            var nouvelles = r.variantesModele
            for i in nouvelles.indices { nouvelles[i].nom = i < lettres.count ? lettres[i] : "\(i + 1)" }
            if let lettre = regenerer, let i = d.propositions.firstIndex(where: { $0.nom == lettre }),
               let n = nouvelles.first(where: { $0.nom == lettre }) {
                d.historique.append(d.propositions[i])
                d.propositions[i] = n
                d.choisir(n)
            } else if let premiere = nouvelles.first {
                d.historique += d.propositions
                d.propositions = nouvelles
                d.choisir(premiere)
            }
            if d.historique.count > 30 { d.historique.removeFirst(d.historique.count - 30) }
            if !r.texte_tranche.isEmpty && r.texte_tranche != projet.trancheAuto { d.texteTranche = r.texte_tranche }
            if d.notes.isEmpty { d.notes = r.notes }
            if d.credits.isEmpty { d.credits = r.credits }
            if d.texteCode == nil && !r.texte_code.isEmpty && r.texte_code != projet.texteCodeAuto { d.texteCode = r.texte_code }
            design = d
            conversation.append(MessageDesign(deClaude: true, texte: r.message))
            statut = String(localized: "Claude a proposé \(nouvelles.count) variantes")
        }
    }

    func choisirVariante(_ v: Variante) { var d = design; d.choisir(v); design = d }

    // MARK: Infos d'édition (recherche web de Claude)

    func chercherInfosWeb() {
        guard prefs.rechercheWebClaude else { statut = String(localized: "La recherche web de Claude est désactivée (Réglages → Claude)."); return }
        lancer(String(localized: "Claude cherche les infos de l'album sur le web…")) { [self] in
            let i = try await claude().chercherInfos(projet: projet)
            if !i.maison_de_disque.isEmpty {
                projet.labelOrigine = i.distributeur.isEmpty ? i.maison_de_disque : "\(i.maison_de_disque) / \(i.distributeur)"
            }
            if !i.catalogue.isEmpty { projet.catalogueOrigine = i.catalogue }
            if !i.annee.isEmpty && projet.annee == nil { projet.annee = i.annee }
            if !i.credits.isEmpty && design.credits.isEmpty { var d = design; d.credits = i.credits; design = d }
            let trouve = [i.maison_de_disque.isEmpty ? nil : "maison de disque \(i.maison_de_disque)",
                          i.distributeur.isEmpty ? nil : "distribution \(i.distributeur)",
                          i.catalogue.isEmpty ? nil : "catalogue \(i.catalogue)", i.annee.isEmpty ? nil : i.annee,
                          i.credits.isEmpty ? nil : "crédits"].compactMap { $0 }
            conversation.append(MessageDesign(deClaude: true, texte: (trouve.isEmpty ? "Rien de sûr trouvé : les cases restent à remplir." : "Trouvé : " + trouve.joined(separator: ", ") + ".")
                                              + (i.sources.isEmpty ? "" : "\nSources : " + i.sources.joined(separator: " · "))))
            statut = String(localized: "Infos de l'album mises à jour")
        }
    }

    // MARK: Vérification avant impression

    /// Corrige tout seul ce qui dépasse : réduit la taille juste ce qu'il faut (jamais sous 5 pt),
    /// puis raccourcit le texte de tranche s'il ne tient toujours pas. Codes illisibles → noir sur blanc.
    func toutCorriger() {
        var d = design
        func deborde(_ z: ZoneTexte) -> Bool { z.largeurTexte > z.largeurZone + 0.05 || z.hauteurTexte > z.hauteurZone + 0.05 }
        for _ in 0..<8 {
            var ratios: [String: Double] = [:]
            var planchers: [String: Double] = [:]
            for z in Mise(projet: projet, design: d).zones() where deborde(z) {
                let r = min(z.largeurZone / max(0.01, z.largeurTexte), z.hauteurZone / max(0.01, z.hauteurTexte)) * 0.97
                ratios[z.nom] = min(ratios[z.nom] ?? 1, r)
                // Échelle qui donnerait 5 pt : on ne descend jamais en dessous.
                let base = z.taillePt / d.echelle(z.nom)
                planchers[z.nom] = max(planchers[z.nom] ?? 0, Verification.tailleMin / max(0.1, base))
            }
            if ratios.isEmpty { break }
            var bouge = false
            for (zone, r) in ratios {
                let nouvelle = max(planchers[zone] ?? 0.45, d.echelle(zone) * r)
                if nouvelle < d.echelle(zone) - 0.001 { d.echelles[zone] = nouvelle; bouge = true }
            }
            if !bouge { break }
        }
        // La tranche ne tient pas même à 5 pt : on essaie des versions plus courtes.
        let tient = { (dd: Design) in !Mise(projet: self.projet, design: dd).zones().contains { $0.nom == "tranche" && deborde($0) } }
        if !tient(d) {
            for t in versionsCourtes(d.texteTranche ?? projet.trancheAuto) {
                var essai = d; essai.texteTranche = t
                if tient(essai) { d = essai; break }
            }
        }
        if alertes.contains(where: { $0.id.hasPrefix("code-inverse") || $0.id.hasPrefix("code-contraste") }) { d.couleursCode = .blanc }
        design = d
        if let avis = avisClaude { appliquer(avis.corrections) }
        statut = alertesBloquantes.isEmpty ? String(localized: "Tout est corrigé ✓") : String(localized: "Alertes à régler à la main : \(alertesBloquantes.count)")
    }

    /// Textes de tranche de plus en plus courts : initiale du prénom, sans article, titre seul, titre coupé.
    func versionsCourtes(_ texte: String) -> [String] {
        let parties = texte.components(separatedBy: " · ")
        var v: [String] = []
        let artiste = parties.first ?? ""
        let reste = parties.dropFirst().joined(separator: " · ")
        let mots = artiste.split(separator: " ")
        let initiale = mots.count > 1 ? "\(mots[0].prefix(1)). " + mots.dropFirst().joined(separator: " ") : artiste
        let sansArticle = reste.replacingOccurrences(of: #"^(THE|AN|A|LE|LA|LES|L')\s+"#, with: "", options: [.regularExpression, .caseInsensitive])
        if !reste.isEmpty {
            v.append("\(initiale) · \(reste)")
            v.append("\(initiale) · \(sansArticle)")
            v.append(reste)
            v.append(sansArticle)
        }
        let base = reste.isEmpty ? texte : sansArticle
        for n in stride(from: base.count - 1, through: 8, by: -2) { v.append(String(base.prefix(n)).trimmingCharacters(in: .whitespaces) + "…") }
        return v
    }

    func appliquer(_ corrections: [AvisRendu.Correction]) {
        var d = design
        for c in corrections {
            switch c.action {
            case "reduire":
                d.echelles[c.zone] = max(0.45, d.echelle(c.zone) * (c.echelle > 0.3 && c.echelle < 1 ? c.echelle : 0.85))
            case "raccourcir", "deux_lignes":
                switch c.zone {
                case "tranche": d.texteTranche = c.texte
                case "obi": d.obiTexte = c.texte
                case "notes": d.notes = c.texte
                case "credits": d.credits = c.texte
                case "code": d.texteCode = c.texte
                default: d.echelles[c.zone] = max(0.45, d.echelle(c.zone) * 0.85)
                }
            default: break
            }
        }
        design = d
        avisClaude = nil
    }

    func ignorer(_ a: Alerte) { var d = design; d.alertesForcees.insert(a.id); design = d }

    func verifierAvecClaude() {
        lancer(String(localized: "Claude regarde la jaquette…")) { [self] in
            let c = try claude()
            await prechargerImages()
            guard let png = Export.planchePourClaude(mise) else { throw Souci(message: "Impossible de faire l'image de la jaquette.") }
            let avis = try await c.verifierRendu(png: png, alertes: alertes, projet: projet, design: design)
            avisClaude = avis
            statut = avis.ok && avis.corrections.isEmpty ? String(localized: "Vérification de Claude : tout est bon ✓") : String(localized: "Corrections proposées par Claude : \(avis.corrections.count)")
        }
    }

    // MARK: Export et impression

    private var nomFichier: String {
        let t = projet.titre.isEmpty ? "Sans titre" : projet.titre
        return "\(projet.numeroCatalogue) \(t)".replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
    }

    func exporterPDF() {
        Task { @MainActor in
            await prechargerImages()
            let panneau = NSSavePanel()
            panneau.allowedContentTypes = [.pdf]
            panneau.nameFieldStringValue = nomFichier + ".pdf"
            guard panneau.runModal() == .OK, let url = panneau.url else { return }
            // PDF pour une boutique : sans le décalage propre à ton imprimante.
            let data = Export.pdf(Export.pages(mise), mise: mise, decalageX: 0, decalageY: 0)
            do {
                try data.write(to: url)
                statut = String(localized: "PDF enregistré (fond perdu, traits de coupe et de pliage)")
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch { statut = "⚠︎ " + error.localizedDescription }
        }
    }

    func exporterPNG() {
        Task { @MainActor in
            await prechargerImages()
            let panneau = NSOpenPanel()
            panneau.canChooseDirectories = true; panneau.canChooseFiles = false; panneau.canCreateDirectories = true
            panneau.prompt = "Enregistrer ici"
            guard panneau.runModal() == .OK, let dossier = panneau.url else { return }
            var n = 0
            for p in Export.pages(mise) {
                guard let data = Export.png(p.vue, dpi: 600) else { continue }
                let nom = "\(nomFichier) - \(p.nom.components(separatedBy: " (").first ?? p.nom).png".replacingOccurrences(of: "/", with: "-")
                if (try? data.write(to: dossier.appendingPathComponent(nom))) != nil { n += 1 }
            }
            statut = n > 1 ? String(localized: "\(n) images PNG 600 DPI enregistrées") : String(localized: "\(n) image PNG 600 DPI enregistrée")
            NSWorkspace.shared.open(dossier)
        }
    }

    /// L'imprimante utilisée et sa correction.
    var imprimanteCourante: String { prefs.imprimante ?? NSPrintInfo.shared.printer.name }
    var calibration: CalibrationImprimante? { prefs.calibrations[imprimanteCourante] }

    func imprimer() {
        Task { @MainActor in
            await prechargerImages()
            let c = calibration ?? CalibrationImprimante()
            let data = Export.pdf(Export.pages(mise), mise: mise, decalageX: c.decalageX, decalageY: c.decalageY,
                                  echelleX: c.echelleX, echelleY: c.echelleY)
            Export.imprimer(data, titre: nomFichier, imprimante: prefs.imprimante)
        }
    }

    var papierCalibrage: Papier { prefs.papierCalibrage == "Letter" ? .letter : .a4 }

    func imprimerCalibrage() {
        Export.imprimer(Export.calibrage(papier: papierCalibrage), titre: "LaFleurStudio - règle de calibrage", imprimante: prefs.imprimante)
    }

    // MARK: Images et polices

    func choisirImagePerso() {
        let panneau = NSOpenPanel()
        panneau.allowedContentTypes = [.image]
        panneau.prompt = "Utiliser cette image"
        guard panneau.runModal() == .OK, let src = panneau.url else { return }
        // Copie dans le dossier de l'app : l'image reste disponible même si l'original bouge.
        let dossier = stockage.racine.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        let dest = dossier.appendingPathComponent("\(UUID().uuidString).\(src.pathExtension.isEmpty ? "jpg" : src.pathExtension)")
        do {
            try FileManager.default.copyItem(at: src, to: dest)
            var d = design; d.imagePerso = dest; d.variante.style = .imagePerso; design = d
            statut = String(localized: "Image ajoutée au recto")
        } catch { statut = "⚠︎ " + error.localizedDescription }
    }

    /// Logo d'une autre maison de disque, depuis tes propres fichiers (usage perso uniquement).
    func importerLogo() {
        let avertissement = NSAlert()
        avertissement.messageText = String(localized: "Usage perso uniquement")
        avertissement.informativeText = String(localized: "Les logos des maisons de disque sont des marques. Importe seulement un fichier que tu as déjà ; l'app ne télécharge ni ne partage jamais de logos.")
        avertissement.addButton(withTitle: String(localized: "Choisir le fichier…"))
        avertissement.addButton(withTitle: String(localized: "Annuler"))
        guard avertissement.runModal() == .alertFirstButtonReturn else { return }
        let panneau = NSOpenPanel()
        panneau.allowedContentTypes = [.image]
        guard panneau.runModal() == .OK, let src = panneau.url else { return }
        let dossier = stockage.racine.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        let dest = dossier.appendingPathComponent("logo-\(UUID().uuidString).\(src.pathExtension.isEmpty ? "png" : src.pathExtension)")
        do {
            try FileManager.default.copyItem(at: src, to: dest)
            var d = design; d.logoMaison = dest; d.afficherLogoMaison = true; design = d
            statut = String(localized: "Logo importé (usage perso uniquement)")
        } catch { statut = "⚠︎ " + error.localizedDescription }
    }

    func importerPolice() {
        let panneau = NSOpenPanel()
        panneau.allowedContentTypes = [UTType(filenameExtension: "ttf"), UTType(filenameExtension: "otf")].compactMap { $0 }
        panneau.allowsMultipleSelection = true
        panneau.prompt = "Importer"
        guard panneau.runModal() == .OK else { return }
        var familles: [String] = []
        for u in panneau.urls { familles += (try? Typo.importer(u)) ?? [] }
        policesDisponibles = Typo.disponibles
        statut = familles.isEmpty ? String(localized: "Aucune police lisible dans ces fichiers") : String(localized: "Police importée : \(Set(familles).sorted().joined(separator: ", "))")
    }
}
