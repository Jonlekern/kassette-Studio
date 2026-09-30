import AppKit
import LaFleurCore
import SwiftUI

/// Un texte placé dans une zone de la jaquette : la même description sert au dessin et à la vérification.
struct SpecTexte {
    let zone: String
    let texte: String
    let famille: String
    /// Taille à l'impression, en points.
    let pt: CGFloat
    var gras = false
    var italique = false
    var kerning: CGFloat = 0
    /// Place disponible, en mm.
    let largeur: CGFloat
    let hauteur: CGFloat
    /// nil = le texte passe à la ligne tout seul ; sinon nombre de lignes imposé (retours « \n »).
    var lignes: Int?
    var couleur: String
    var fond: String

    func nsFont(_ echelle: CGFloat = Typo.ptParMM) -> NSFont {
        Typo.nsFont(famille, pt * echelle / Typo.ptParMM, gras: gras, italique: italique)
    }

    /// Mesure à l'impression, pour la vérification.
    var zoneTexte: ZoneTexte {
        let f = nsFont()
        let lt = lignes != nil ? Typo.largeurMM(texte, f, kerning: kerning) : min(Typo.largeurMM(texte, f, kerning: kerning), largeur)
        // Un mot plus long que la zone déborde même quand le texte passe à la ligne.
        let motLePlusLong = texte.split(whereSeparator: { $0 == " " || $0 == "\n" }).map { Typo.largeurMM(String($0), f, kerning: kerning) }.max() ?? 0
        let ht = lignes.map { CGFloat($0) * Typo.hauteurLigneMM(f) } ?? Typo.hauteurMM(texte, f, largeur: largeur, kerning: kerning)
        return ZoneTexte(nom: zone, texte: texte, largeurZone: Double(largeur), largeurTexte: Double(max(lt, motLePlusLong)),
                         hauteurZone: Double(hauteur), hauteurTexte: Double(ht), taillePt: Double(pt),
                         couleurTexte: couleur, couleurFond: fond)
    }
}

/// Les règles de mise en page de chaque format (tailles en points à l'impression, places en mm).
struct Mise {
    /// Espacement des lignes de la tracklist (en hauteurs de ligne).
    static let interligne: CGFloat = 1.15
    let projet: Projet
    let design: Design

    var v: Variante { design.variante }
    var p: Palette { v.palette }
    func e(_ zone: String) -> CGFloat { CGFloat(design.echelle(zone)) }

    // MARK: Textes

    var texteTranche: String { design.texteTranche ?? projet.trancheAuto }
    var texteCode: String { design.texteCode ?? projet.texteCodeAuto }
    var numeroCode: String { design.numeroCode.isEmpty ? projet.numeroCodeAuto : design.numeroCode }

    var badge: String {
        let c = projet.cassette
        let position: String
        switch c.bande {
        case .typeI: position = "NORMAL POSITION · 120 µs"
        case .typeII: position = "HIGH POSITION · 70 µs"
        case .typeIV: position = "METAL POSITION · 70 µs"
        }
        let nr = c.reducteur == .aucun ? "" : "\(c.reducteur.nom.uppercased()) NR"
        let lignes = [c.bande.badge] + position.components(separatedBy: " · ") + (nr.isEmpty ? [] : [nr])
        // Deux éléments par ligne au plus, pour tenir dans un rabat étroit.
        return stride(from: 0, to: lignes.count, by: 2).map { lignes[$0..<min($0 + 2, lignes.count)].joined(separator: " · ") }
            .joined(separator: "\n")
    }

    /// Lignes de la tracklist : (face, numéro, titre, durée).
    func lignes(_ f: Face) -> [(String, String, String)] {
        projet.pistes(f).enumerated().map { i, piste in
            let t = projet.mode == .mixtape ? "\(piste.morceau.titre) — \(piste.morceau.artiste)" : piste.morceau.titre
            return ("\(f.rawValue)\(i + 1)", t, formaterDuree(piste.duree))
        }
    }

    // MARK: Zones

    func tranche(longueur: CGFloat, epaisseur: CGFloat) -> SpecTexte {
        let n = texteTranche.components(separatedBy: "\n").count
        return SpecTexte(zone: "tranche", texte: texteTranche, famille: v.policeTexte, pt: (n > 1 ? 6.5 : 8) * e("tranche"), gras: true,
                         kerning: 0.4, largeur: longueur - 28, hauteur: epaisseur - 2, lignes: n, couleur: p.texte, fond: p.fond)
    }

    func titre(largeur: CGFloat) -> SpecTexte {
        SpecTexte(zone: "titre", texte: projet.titre.isEmpty ? "Sans titre" : projet.titre, famille: v.policeTitre, pt: 15 * e("titre"),
                  italique: v.titreItalique, largeur: largeur, hauteur: 19, couleur: p.texte, fond: p.fond)
    }

    func artiste(largeur: CGFloat) -> SpecTexte {
        SpecTexte(zone: "artiste", texte: (projet.artiste.isEmpty ? (projet.mode == .mixtape ? "MIXTAPE" : "") : projet.artiste).uppercased(),
                  famille: v.policeTexte, pt: 6.5 * e("artiste"), kerning: 1, largeur: largeur, hauteur: 4, lignes: 1,
                  couleur: p.texte, fond: p.fond)
    }

    func badgeSpec(largeur: CGFloat) -> SpecTexte {
        let n = badge.components(separatedBy: "\n").count
        return SpecTexte(zone: "badge", texte: badge, famille: v.policeTexte, pt: 5 * e("badge"), gras: true,
                         largeur: largeur, hauteur: CGFloat(n) * 2.6, lignes: n, couleur: p.texte, fond: p.fond)
    }

    /// Ligne au-dessus du code-barres : passe sur deux lignes si besoin.
    func texteCodeSpec(largeur: CGFloat) -> SpecTexte {
        SpecTexte(zone: "code", texte: texteCode, famille: v.policeTexte, pt: 5 * e("code"),
                  largeur: largeur, hauteur: 5.5, couleur: p.texte, fond: p.fond)
    }

    func droitsSpec(largeur: CGFloat) -> SpecTexte {
        SpecTexte(zone: "droits", texte: projet.ligneDroits, famille: v.policeTexte, pt: 5 * e("droits"),
                  largeur: largeur, hauteur: 5.5, couleur: p.texte, fond: p.fond)
    }

    /// Hauteur de la tracklist (mm) pour une taille donnée.
    func tracklistTaille() -> CGFloat { 5.6 * e("tracklist") }

    func tracklistSpecs(largeur: CGFloat, hauteur: CGFloat) -> [SpecTexte] {
        let l = [Face.a, .b].flatMap { lignes($0) }
        let entetes = [Face.a, .b].filter { !projet.pistes($0).isEmpty }.count
        // Chaque ligne prend `interligne` fois la hauteur d'une ligne ; chaque face a un titre et un espace.
        let lignesTotales = Double(l.count + entetes * 2) * Double(Mise.interligne)
        // Première zone : la liste entière, pour vérifier qu'elle tient en hauteur.
        var specs = [SpecTexte(zone: "tracklist", texte: l.isEmpty ? "" : "FACE A", famille: v.policeTexte, pt: tracklistTaille(),
                               largeur: largeur, hauteur: hauteur, lignes: max(1, Int(lignesTotales.rounded(.up))),
                               couleur: p.texte, fond: p.fond)]
        for (num, t, d) in l {
            specs.append(SpecTexte(zone: "tracklist", texte: "\(num)  \(t)  \(d)", famille: v.policeTexte, pt: tracklistTaille(),
                                   largeur: largeur, hauteur: hauteur, lignes: 1, couleur: p.texte, fond: p.fond))
        }
        return specs
    }

    func notesSpec(largeur: CGFloat, hauteur: CGFloat) -> SpecTexte {
        SpecTexte(zone: "notes", texte: design.notes, famille: v.policeTexte, pt: 6 * e("notes"),
                  largeur: largeur, hauteur: hauteur, couleur: p.texte, fond: p.fond)
    }

    func creditsSpec(largeur: CGFloat, hauteur: CGFloat) -> SpecTexte {
        SpecTexte(zone: "credits", texte: design.credits, famille: v.policeTexte, pt: 5 * e("credits"),
                  largeur: largeur, hauteur: hauteur, couleur: p.texte, fond: p.fond)
    }

    func etiquetteTitre() -> SpecTexte {
        SpecTexte(zone: "etiquette", texte: projet.titre.isEmpty ? "Sans titre" : projet.titre, famille: v.policeTitre, pt: 10 * e("etiquette"),
                  italique: v.titreItalique, largeur: 89 - 8 - 14, hauteur: 7, lignes: 1, couleur: p.texte, fond: p.fond)
    }

    func obiSpec() -> SpecTexte {
        let t = design.obiTexte.isEmpty ? texteTranche : design.obiTexte
        return SpecTexte(zone: "obi", texte: t, famille: v.policeTitre, pt: 9 * e("obi"), gras: true,
                         largeur: 108 - 16, hauteur: 16, lignes: 1, couleur: couleurObi, fond: p.accent)
    }

    /// Texte de l'obi : la couleur de la palette qui se lit le mieux sur l'accent.
    var couleurObi: String {
        [p.fond, p.texte, "#FFFFFF", "#000000"].max { Verification.contraste($0, p.accent) < Verification.contraste($1, p.accent) }!
    }

    // MARK: Blocs intérieurs

    enum Bloc: Hashable { case tracklist, notes, credits }

    /// Ce qui va dans les volets intérieurs, dans l'ordre.
    var blocs: [Bloc] {
        var b: [Bloc] = [.tracklist]
        if !design.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { b.append(.notes) }
        if !design.credits.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { b.append(.credits) }
        return b
    }

    var gabaritJ: Gabarit { Gabarits.jcard(volets: design.volets, dos: design.dos) }

    /// Volets intérieurs côté extérieur (imprimés avec le reste, ils se replient à l'intérieur).
    var voletsInterieurs: [Panneau] { gabaritJ.panneaux.filter { if case .interieur = $0.genre { true } else { false } } }

    /// Répartition : d'abord les volets intérieurs, puis le verso (impression recto verso) derrière le recto et le rabat.
    var repartition: (exterieur: [Panneau: Bloc], verso: [Panneau.Genre: Bloc]) {
        var ext: [Panneau: Bloc] = [:]
        var verso: [Panneau.Genre: Bloc] = [:]
        var reste = blocs
        for pan in voletsInterieurs where !reste.isEmpty { ext[pan] = reste.removeFirst() }
        for g in [Panneau.Genre.recto, .rabat] where !reste.isEmpty && gabaritJ.panneau(g) != nil { verso[g] = reste.removeFirst() }
        return (ext, verso)
    }

    var aUnVerso: Bool { !repartition.verso.isEmpty }

    // MARK: Couleurs des codes

    var couleursCode: (barres: String, fond: String) {
        switch design.couleursCode {
        case .blanc: return ("#000000", "#FFFFFF")
        case .perso: return (design.barresPerso, design.fondPerso)
        case .design:
            let a = [p.fond, p.texte, p.accent].sorted { Verification.luminance($0) < Verification.luminance($1) }
            return (a.first!, a.last!)
        }
    }

    var contenuQR: String {
        switch design.contenuQR {
        case .spotify: projet.lienSpotify?.absoluteString ?? ""
        case .lienPerso, .texte: design.texteQR
        }
    }

    var urlCodeSpotify: URL? {
        guard let uri = projet.uriSpotify else { return nil }
        let (_, fond) = couleursCode
        return CodeSpotify.url(uri: uri, fond: fond, barresBlanches: Verification.luminance(fond) < 0.35)
    }

    // MARK: Tout ce qu'il faut vérifier

    func zones() -> [ZoneTexte] {
        var z: [SpecTexte] = []
        let g = gabaritJ
        if design.jcard {
            z.append(tranche(longueur: g.hauteur, epaisseur: Gabarits.tranche))
            z.append(titre(largeur: Gabarits.recto - 8))
            z.append(artiste(largeur: Gabarits.recto - 8))
            if let r = g.panneau(.rabat) {
                z.append(badgeSpec(largeur: r.largeur - 2))
                if design.codeBarres && design.placeCode == .rabat { z.append(texteCodeSpec(largeur: r.largeur - 2)) }
                z.append(droitsSpec(largeur: r.largeur - 2))
            }
            let rep = repartition
            var places: [(Bloc, CGFloat)] = rep.exterieur.map { ($0.value, $0.key.largeur) }
            for (genre, b) in rep.verso { places.append((b, g.panneau(genre)?.largeur ?? 0)) }
            for (b, w) in places {
                let l = w - 8, h = g.hauteur - 10
                switch b {
                case .tracklist: z += tracklistSpecs(largeur: l, hauteur: h)
                case .notes: z.append(notesSpec(largeur: l, hauteur: h))
                case .credits: z.append(creditsSpec(largeur: l, hauteur: h))
                }
            }
        }
        if design.ocard {
            z.append(tranche(longueur: Gabarits.ocard.hauteur, epaisseur: 12.3))
            z.append(titre(largeur: 64.3 - 8))
            z += tracklistSpecs(largeur: 63.8 - 8, hauteur: Gabarits.ocard.hauteur - 34)
        }
        if design.etiquettes { z.append(etiquetteTitre()) }
        if design.obi { z.append(obiSpec()) }
        return z.map(\.zoneTexte)
    }

    /// Alertes de l'app (texte + codes), sans celles que l'utilisateur a choisi d'ignorer.
    func alertes() -> [Alerte] {
        var a = Verification.verifier(zones())
        let (barres, fond) = couleursCode
        if design.codeBarres {
            if let c = CodesBarres.generer(design.genreCode, numeroCode) {
                a += Verification.verifierCode(nom: design.genreCode.nom, barres: barres, fond: fond,
                                               largeurModule: Double(largeurModule(c)))
            } else {
                a.append(Alerte(id: "code-numero", zone: "code", gravite: .bloquante,
                                message: "Numéro « \(numeroCode) » impossible en \(design.genreCode.nom) (\(design.genreCode == .code128 ? "caractères ASCII seulement" : "chiffres seulement, 12 ou 13 pour l'EAN, 11 ou 12 pour l'UPC")."))
            }
        }
        if design.qr {
            if contenuQR.isEmpty {
                a.append(Alerte(id: "qr-vide", zone: "code", gravite: .bloquante,
                                message: design.contenuQR == .spotify ? "QR code : pas de lien Spotify pour cette cassette. Choisis « Lien perso » ou « Texte »." : "QR code vide : écris le lien ou le texte."))
            } else {
                a += Verification.verifierCode(nom: "QR code", barres: barres, fond: fond, largeurModule: 0.5)
            }
        }
        if design.codeSpotify && projet.uriSpotify == nil {
            a.append(Alerte(id: "spotify-absent", zone: "code", gravite: .bloquante,
                            message: "Code Spotify : cette cassette n'a pas été importée depuis Spotify."))
        }
        return a.filter { !design.alertesForcees.contains($0.id) }
    }

    /// Largeur d'un module du code-barres tel qu'il est dessiné (mm).
    func largeurModule(_ c: CodeBarres1D) -> CGFloat {
        let place: CGFloat
        switch design.placeCode {
        case .rabat: place = (gabaritJ.panneau(.rabat)?.largeur ?? Gabarits.recto) - 3
        case .tranche: place = 30
        case .interieur: place = 40
        }
        return min(0.33, place / CGFloat(c.modules.count + 20)) * CGFloat(design.echelleCode)
    }
}
