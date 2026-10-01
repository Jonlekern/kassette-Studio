import AppKit
import LaFleurCore
import SwiftUI

/// Une ligne du fil de la boîte « Modifier avec l'IA ».
struct MessageModif: Identifiable, Hashable {
    let id = UUID()
    let deIA: Bool
    let texte: String
    var changements: [String] = []
    /// Échange correspondant (pour « Annuler » et l'historique).
    var echange: UUID?
    var annule = false
}

/// État d'avant un échange avec l'IA : de quoi tout remettre (cassette, réglages, cassettes créées).
struct InstantaneIA {
    let projet: Projet
    let prefs: Preferences
    var creees: [UUID] = []
}

/// Boîte « Modifier avec l'IA », mode expert et historique IA (demandes 6, 7 et 8).
extension EtatApp {
    var modeExpert: Bool { prefs.modeExpertIA }

    // MARK: Historique

    /// Note un échange dans l'historique de la cassette (jamais de clé API dedans).
    @discardableResult
    func noterEchange(_ demande: String, _ reponse: String, _ changements: [String], client: ClientClaude,
                      refaisable: Bool = true) -> UUID {
        var d = design
        d.propositions = []; d.historique = []
        let e = EchangeIA(demande: demande, moteur: "\(client.fournisseur.nom) · \(client.modele)", reponse: reponse,
                          changements: changements, cout: client.compteur?.cout(modele: client.modele), designApres: d,
                          refaisable: refaisable)
        projet.echangesIA.append(e)
        return e.id
    }

    /// Revient à la jaquette telle qu'elle était juste après cet échange.
    func revenir(a e: EchangeIA) {
        guard let apres = e.designApres else { return }
        modifierDesign { d in
            let (propositions, historique) = (d.propositions, d.historique)
            d = apres
            d.propositions = propositions; d.historique = historique
        }
        statut = String(localized: "Jaquette remise comme après « \(e.demande) »")
    }

    func effacerHistoriqueIA() { projet.echangesIA = [] }

    // MARK: Boîte « Modifier avec l'IA »

    /// Envoie une demande en langage courant ; l'IA applique directement, puis résume ce qui a changé.
    func modifierAvecIA(_ demande: String) {
        let texte = demande.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !texte.isEmpty else { return }
        filModif.append(MessageModif(deIA: false, texte: texte))
        lancer(String(localized: "\(fournisseurIA.nom) modifie la cassette…")) { [self] in
            let c = try claude()
            await prechargerImages()
            var images: [Data] = []
            if let rendu = Export.planchePourClaude(mise), let img = NSImage(data: rendu), let jpg = Images.jpeg(img, cote: 1400) {
                images.append(jpg)
            }
            let fil = filModif.dropLast().suffix(12).map { ($0.deIA ? "IA : " : "Utilisateur : ") + $0.texte + ($0.changements.isEmpty ? "" : " [" + $0.changements.joined(separator: " ; ") + "]") }
            let r = try await c.modifier(projet: projet, design: design, reglages: prefs, demande: texte, fil: fil, expert: modeExpert,
                                         polices: Typo.disponibles, images: images, anatomie: mise.anatomie(),
                                         fichiers: fichiers.map(nomFichier), collection: collection.map { "\($0.numeroCatalogue) \($0.titre)" })
            // « Remets comme avant » : on annule le dernier échange de la boîte.
            if r.actions.contains(where: { $0.type == "annuler" }) {
                let msg = annulerDernierEchange() ? r.message : String(localized: "Il n'y a rien à annuler.")
                filModif.append(MessageModif(deIA: true, texte: msg))
                return
            }
            var instantane = InstantaneIA(projet: projet, prefs: prefs)
            var lignes: [String] = []
            var refus: [String] = r.impossible.map { String(localized: "Impossible : \($0)") }

            // 1. Actions sur la Collection d'abord (une nouvelle cassette reçoit ensuite les autres changements).
            if modeExpert {
                for a in r.actions where ["nouvelle_cassette", "dupliquer_cassette", "ouvrir_cassette", "renommer_cassette", "supprimer_cassette"].contains(a.type) {
                    executerCollection(a, &instantane, &lignes, &refus)
                }
            }
            // 2. Réglages (jaquette, cassette, platine).
            var p = projet, d = design, reglages = prefs
            for ch in r.changements {
                do { lignes.append(try appliquerChemin(ch.chemin, ch.valeur, &p, &d, &reglages)) } catch { refus.append(error.localizedDescription) }
            }
            // 3. Morceaux et faces (mode expert).
            if modeExpert {
                for a in r.actions where ["deplacer_piste", "retirer_piste", "ajouter_piste", "longueur"].contains(a.type) {
                    executerPiste(a, &p, &lignes, &refus)
                }
            }
            if d != design { memoriser(design) }
            p.design = d
            projet = p
            if reglages != prefs { prefs = reglages }
            for di in r.images {
                await poserImage(di)
                lignes.append(String(localized: "Image « \(di.requete) » (\(di.usage))"))
            }
            let resume = lignes.isEmpty && refus.isEmpty ? [String(localized: "Rien n'a été changé.")] : lignes + refus
            let id = noterEchange(texte, r.message, resume, client: c)
            instantanesIA[id] = instantane
            filModif.append(MessageModif(deIA: true, texte: r.message, changements: resume, echange: id))
            statut = lignes.isEmpty ? String(localized: "\(fournisseurIA.nom) n'a rien changé") : String(localized: "\(lignes.count) changement(s) appliqué(s) ✓")
        }
    }

    /// Annule l'échange `id` : cassette, réglages et cassettes créées reviennent comme avant.
    func annulerEchange(_ id: UUID) {
        guard let avant = instantanesIA[id] else { return }
        for c in avant.creees { if let p = collection.first(where: { $0.id == c }) { stockage.supprimer(p) } }
        let historique = projet.id == avant.projet.id ? projet.echangesIA : avant.projet.echangesIA
        var p = avant.projet
        p.echangesIA = historique
        if projet.id != p.id { ouvrir(p) }
        memoriser(design)
        projet = p
        prefs = avant.prefs
        rafraichirCollection()
        instantanesIA[id] = nil
        if let i = filModif.firstIndex(where: { $0.echange == id }) { filModif[i].annule = true }
        statut = String(localized: "Changements de l'IA annulés")
    }

    @discardableResult
    func annulerDernierEchange() -> Bool {
        guard let m = filModif.last(where: { $0.echange != nil && !$0.annule }), let id = m.echange, instantanesIA[id] != nil else { return false }
        annulerEchange(id)
        return true
    }

    func effacerFilModif() { filModif = [] }

    // MARK: Application des changements

    private func nomFichier(_ f: InfosFichier) -> String { f.titre ?? f.url.deletingPathExtension().lastPathComponent }

    /// Applique un changement « chemin = valeur » et renvoie « chemin : avant → après ».
    func appliquerChemin(_ chemin: String, _ valeur: String, _ p: inout Projet, _ d: inout Design, _ reglages: inout Preferences) throws -> String {
        let c = chemin.trimmingCharacters(in: .whitespaces)
        if c.hasPrefix("design.") {
            let sous = String(c.dropFirst(7))
            let avant = Chemins.lire(sous, dans: d) ?? "—"
            try Chemins.ecrire(sous, valeur, dans: &d)
            return "\(sous) : \(avant) → \(Chemins.lire(sous, dans: d) ?? valeur)"
        }
        if c.hasPrefix("projet.") {
            let sous = String(c.dropFirst(7))
            let libres = ["titre", "artiste", "maisonDeDisque", "annee", "droits"]
            let interdits = ["id", "faceA", "faceB", "design", "historiqueIA", "creeLe", "modifieLe", "enregistree"]
            let racine = sous.split(separator: ".").first.map(String.init) ?? sous
            guard libres.contains(racine) || (modeExpert && !interdits.contains(racine)) else {
                throw Souci(message: String(localized: "« \(sous) » demande le mode expert (Réglages → IA)."))
            }
            let avant = Chemins.lire(sous, dans: p) ?? "—"
            try Chemins.ecrire(sous, valeur, dans: &p)
            return "\(sous) : \(avant) → \(Chemins.lire(sous, dans: p) ?? valeur)"
        }
        if c.hasPrefix("reglages.") {
            let sous = String(c.dropFirst(9))
            guard modeExpert else { throw Souci(message: String(localized: "Les réglages de la cassette demandent le mode expert (Réglages → IA).")) }
            guard sous.hasPrefix("platine.") || sous == "egaliserVolume" else {
                throw Souci(message: String(localized: "L'IA ne touche pas à « \(sous) » (clés, comptes, fichiers et sorties restent à toi)."))
            }
            let avant = Chemins.lire(sous, dans: reglages) ?? "—"
            try Chemins.ecrire(sous, valeur, dans: &reglages)
            return "\(sous) : \(avant) → \(Chemins.lire(sous, dans: reglages) ?? valeur)"
        }
        // Ancien nom de champ (« taille_titre », « orientation »…), sinon chemin du design sans préfixe.
        if ChampsDesign.tous.contains(c) {
            guard ChampsDesign.appliquer(c, valeur, projet: &p, design: &d) else { throw Chemins.Erreur.valeurInvalide(c, valeur) }
            return "\(c) → \(valeur)"
        }
        let avant = Chemins.lire(c, dans: d) ?? "—"
        try Chemins.ecrire(c, valeur, dans: &d)
        return "\(c) : \(avant) → \(Chemins.lire(c, dans: d) ?? valeur)"
    }

    private func trouverPiste(_ titre: String, _ p: Projet) -> (Face, Int)? {
        let n = Association.normaliser(titre)
        for f in [Face.a, .b] {
            let l = p.pistes(f)
            if let i = l.firstIndex(where: { Association.normaliser($0.morceau.titre) == n }) ?? l.firstIndex(where: { Association.normaliser($0.morceau.titre).contains(n) }) {
                return (f, i)
            }
        }
        return nil
    }

    private func executerPiste(_ a: ReponseModification.Action, _ p: inout Projet, _ lignes: inout [String], _ refus: inout [String]) {
        let face: Face = a.face.uppercased().hasPrefix("B") ? .b : .a
        switch a.type {
        case "longueur":
            let m = Int(Double(a.valeur.filter { $0.isNumber || $0 == "." }) ?? 0)
            guard m >= 10 else { refus.append(String(localized: "Longueur de cassette incomprise : \(a.valeur)")); return }
            let avant = p.cassette.longueur.nom
            p.cassette.longueur = m == 60 ? .c60 : m == 90 ? .c90 : .custom(minutesParFace: m / 2)
            lignes.append(String(localized: "Cassette : \(avant) → \(p.cassette.longueur.nom)"))
        case "retirer_piste":
            guard let trouve = trouverPiste(a.cible, p) else { refus.append(String(localized: "Morceau introuvable : \(a.cible)")); return }
            let (f, i) = trouve
            let t = p.pistes(f)[i].morceau.titre
            if f == .a { p.faceA.remove(at: i) } else { p.faceB.remove(at: i) }
            lignes.append(String(localized: "« \(t) » retiré"))
        case "deplacer_piste":
            guard let trouve = trouverPiste(a.cible, p) else { refus.append(String(localized: "Morceau introuvable : \(a.cible)")); return }
            let (f, i) = trouve
            let piste = f == .a ? p.faceA.remove(at: i) : p.faceB.remove(at: i)
            let rang = max(0, Int(a.position) - 1)
            if face == .a { p.faceA.insert(piste, at: min(rang, p.faceA.count)) } else { p.faceB.insert(piste, at: min(rang, p.faceB.count)) }
            lignes.append(String(localized: "« \(piste.morceau.titre) » → face \(face.rawValue), position \(min(rang, p.pistes(face).count - 1) + 1)"))
        case "ajouter_piste":
            let n = Association.normaliser(a.cible)
            guard let fichier = fichiers.first(where: { Association.normaliser(nomFichier($0)) == n })
                    ?? fichiers.first(where: { Association.normaliser(nomFichier($0)).contains(n) }),
                  let piste = DossierAudio.pistes(depuis: [fichier]).first else {
                refus.append(String(localized: "Fichier introuvable dans le dossier audio : \(a.cible)")); return
            }
            let rang = a.position >= 1 ? Int(a.position) - 1 : p.pistes(face).count
            if face == .a { p.faceA.insert(piste, at: min(rang, p.faceA.count)) } else { p.faceB.insert(piste, at: min(rang, p.faceB.count)) }
            lignes.append(String(localized: "« \(piste.morceau.titre) » ajouté en face \(face.rawValue)"))
        default: break
        }
    }

    private func executerCollection(_ a: ReponseModification.Action, _ inst: inout InstantaneIA, _ lignes: inout [String], _ refus: inout [String]) {
        switch a.type {
        case "nouvelle_cassette":
            nouvelleCassette()
            if !a.valeur.isEmpty { projet.titre = a.valeur }
            inst.creees.append(projet.id)
            lignes.append(String(localized: "Nouvelle cassette \(projet.numeroCatalogue)"))
        case "dupliquer_cassette":
            var reglages = prefs
            var copie = projet
            copie.id = UUID(); copie.numeroCatalogue = Stockage.numero(&reglages); copie.enregistree = []; copie.creeLe = Date()
            copie.echangesIA = []
            prefs = reglages
            try? stockage.enregistrer(copie)
            ouvrir(copie)
            inst.creees.append(copie.id)
            lignes.append(String(localized: "Copie \(copie.numeroCatalogue) créée et ouverte"))
        case "ouvrir_cassette":
            guard let p = collection.first(where: { $0.numeroCatalogue.caseInsensitiveCompare(a.cible) == .orderedSame }) else {
                refus.append(String(localized: "Cassette introuvable : \(a.cible)")); return
            }
            ouvrir(p)
            lignes.append(String(localized: "Cassette \(p.numeroCatalogue) ouverte"))
        case "renommer_cassette":
            let avant = projet.titre
            projet.titre = a.valeur
            lignes.append(String(localized: "Titre : \(avant) → \(a.valeur)"))
        case "supprimer_cassette":
            // Jamais sans confirmation : l'app pose la question.
            if let p = collection.first(where: { $0.numeroCatalogue.caseInsensitiveCompare(a.cible) == .orderedSame }) {
                suppressionDemandee = p
                lignes.append(String(localized: "Suppression de \(p.numeroCatalogue) à confirmer"))
            } else {
                refus.append(String(localized: "Cassette introuvable : \(a.cible)"))
            }
        default: break
        }
    }
}
