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

    /// Morceaux du badge de bande, façon K7 d'époque.
    var morceauxBadge: [String] {
        let c = projet.cassette
        let position: [String]
        switch c.bande {
        case .typeI: position = ["NORMAL POSITION", "120 µs"]
        case .typeII: position = ["HIGH POSITION", "70 µs"]
        case .typeIV: position = ["METAL POSITION", "70 µs"]
        }
        return [c.bande.badge] + position + (c.reducteur == .aucun ? [] : ["\(c.reducteur.nom.uppercased()) NR"])
    }

    /// Badge sur autant de lignes qu'il faut pour tenir dans `largeur` (mm) : on regroupe tant que ça rentre.
    func badge(largeur: CGFloat) -> String {
        let f = Typo.nsFont(v.policeTexte, 5 * e("badge"), gras: true)
        var lignes: [String] = []
        for m in morceauxBadge {
            if let d = lignes.last, Typo.largeurMM(d + " · " + m, f) <= largeur { lignes[lignes.count - 1] = d + " · " + m }
            else { lignes.append(m) }
        }
        return lignes.joined(separator: "\n")
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

    func titre(largeur: CGFloat, hauteur: CGFloat = 19) -> SpecTexte {
        SpecTexte(zone: "titre", texte: projet.titre.isEmpty ? "Sans titre" : projet.titre, famille: v.policeTitre, pt: 15 * e("titre"),
                  italique: v.titreItalique, largeur: largeur, hauteur: hauteur, couleur: p.texte, fond: p.fond)
    }

    /// Zones du texte du recto selon l'orientation (largeur du recto `l`, hauteur `h`, en mm).
    func zonesRecto(l: CGFloat, h: CGFloat) -> (titre: SpecTexte, artiste: SpecTexte) {
        if design.cadrage == .pleineHauteur {
            // Image sur tout le recto, bandeau titre en bas (en paysage : en bas du cadre tourné, logo à droite).
            return design.orientation == .paysage
                ? (titre(largeur: h - 36, hauteur: 8), artiste(largeur: h - 36))
                : (titre(largeur: l - 8, hauteur: 11), artiste(largeur: l - 8))
        }
        if design.orientation == .paysage {
            // Cadre tourné : h × l, image carrée l × l à gauche, texte dans la colonne de droite.
            let w = h - l - 6
            return (titre(largeur: w, hauteur: l - 16), artiste(largeur: w))
        }
        return (titre(largeur: l - 8), artiste(largeur: l - 8))
    }

    /// Hauteur du bandeau titre en cadrage pleine hauteur (mm).
    var bandeauRecto: CGFloat { design.orientation == .paysage ? 18 : 26 }

    func artiste(largeur: CGFloat) -> SpecTexte {
        SpecTexte(zone: "artiste", texte: (projet.artiste.isEmpty ? (projet.mode == .mixtape ? "MIXTAPE" : "") : projet.artiste).uppercased(),
                  famille: v.policeTexte, pt: 6.5 * e("artiste"), kerning: 1, largeur: largeur, hauteur: 4, lignes: 1,
                  couleur: p.texte, fond: p.fond)
    }

    func badgeSpec(largeur: CGFloat) -> SpecTexte {
        let lignesBadge = self.badge(largeur: largeur)
        let n = lignesBadge.components(separatedBy: "\n").count
        return SpecTexte(zone: "badge", texte: lignesBadge, famille: v.policeTexte, pt: 5 * e("badge"), gras: true,
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

    /// Couleur des titres « FACE A / FACE B » : l'accent s'il se lit sur le fond (contraste ≥ 3:1,
    /// texte gras), sinon la couleur du texte. Avant, un accent sombre sur fond sombre devenait illisible.
    var couleurTitresFaces: String { Verification.contraste(p.accent, p.fond) >= 3 ? p.accent : p.texte }

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

    /// Crédits imprimés, avec le lien vers les paroles si demandé.
    var texteCredits: String {
        let paroles = design.lienParoles ? String(localized: "Paroles : genius.com") : ""
        return [design.credits.trimmingCharacters(in: .whitespacesAndNewlines), paroles].filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    func creditsSpec(largeur: CGFloat, hauteur: CGFloat) -> SpecTexte {
        SpecTexte(zone: "credits", texte: texteCredits, famille: v.policeTexte, pt: 5 * e("credits"),
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

    enum Bloc: Hashable { case tracklist, notes, credits, notesEtCredits }

    /// Ce qui va dans les volets intérieurs, dans l'ordre.
    var blocs: [Bloc] {
        var b: [Bloc] = [.tracklist]
        if !design.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { b.append(.notes) }
        if !texteCredits.isEmpty { b.append(.credits) }
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
        // Verso : derrière le recto, puis derrière la tranche et le rabat réunis (ou la tranche seule sans rabat).
        let fond: Panneau.Genre = gabaritJ.panneau(.rabat) != nil ? .rabat : .tranche
        for g in [Panneau.Genre.recto, fond] where !reste.isEmpty {
            // Dernière place : notes et crédits ensemble plutôt que d'en perdre un.
            if g == fond && reste == [.notes, .credits] { verso[g] = .notesEtCredits; reste = [] } else { verso[g] = reste.removeFirst() }
        }
        return (ext, verso)
    }

    var aUnVerso: Bool { !repartition.verso.isEmpty }

    /// Largeur d'un emplacement du verso : derrière le rabat, on compte aussi la tranche.
    func largeurVerso(_ g: Panneau.Genre) -> CGFloat {
        let gj = gabaritJ
        let w = gj.panneau(g)?.largeur ?? 0
        return g == .rabat ? w + (gj.panneau(.tranche)?.largeur ?? 0) : w
    }

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
            let r = zonesRecto(l: Gabarits.recto, h: g.hauteur)
            z.append(r.titre); z.append(r.artiste)
            if let r = g.panneau(.rabat) {
                z.append(badgeSpec(largeur: r.largeur - 2))
                if design.codeBarres && design.placeCode == .rabat { z.append(texteCodeSpec(largeur: r.largeur - 2)) }
                if design.codeBarres && design.placeCode == .libre { z.append(texteCodeSpec(largeur: 25)) }
                z.append(droitsSpec(largeur: r.largeur - 2))
            }
            let rep = repartition
            var places: [(Bloc, CGFloat)] = rep.exterieur.map { ($0.value, $0.key.largeur) }
            for (genre, b) in rep.verso { places.append((b, largeurVerso(genre))) }
            for (b, w) in places {
                let l = w - 8, h = g.hauteur - 10
                switch b {
                case .tracklist: z += tracklistSpecs(largeur: l, hauteur: h)
                case .notes: z.append(notesSpec(largeur: l, hauteur: h))
                case .credits: z.append(creditsSpec(largeur: l, hauteur: h))
                case .notesEtCredits:
                    let n = notesSpec(largeur: l, hauteur: h)
                    let hn = Typo.hauteurMM(n.texte, n.nsFont(), largeur: l) + 4
                    z.append(n)
                    z.append(creditsSpec(largeur: l, hauteur: max(1, h - hn)))
                }
            }
        }
        if design.ocard {
            z.append(tranche(longueur: Gabarits.ocard.hauteur, epaisseur: 12.3))
            z.append(zonesRecto(l: 64.3, h: Gabarits.ocard.hauteur).titre)
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
                                message: design.genreCode == .code128
                                    ? String(localized: "Numéro « \(numeroCode) » impossible en Code 128 : caractères ASCII seulement.")
                                    : String(localized: "Numéro « \(numeroCode) » impossible en \(design.genreCode.nom) : chiffres seulement, 12 ou 13 pour l'EAN, 11 ou 12 pour l'UPC.")))
            }
        }
        if design.qr {
            if contenuQR.isEmpty {
                a.append(Alerte(id: "qr-vide", zone: "code", gravite: .bloquante,
                                message: design.contenuQR == .spotify ? String(localized: "QR code : pas de lien Spotify pour cette cassette. Choisis « Lien perso » ou « Texte ».") : String(localized: "QR code vide : écris le lien ou le texte.")))
            } else {
                a += Verification.verifierCode(nom: "QR code", barres: barres, fond: fond, largeurModule: 0.5)
            }
        }
        if design.codeSpotify && projet.uriSpotify == nil {
            a.append(Alerte(id: "spotify-absent", zone: "code", gravite: .bloquante,
                            message: String(localized: "Code Spotify : cette cassette n'a pas été importée depuis Spotify.")))
        }
        return a.filter { !design.alertesForcees.contains($0.id) }
    }

    /// Largeur d'un module du code-barres tel qu'il est dessiné (mm).
    func largeurModule(_ c: CodeBarres1D) -> CGFloat {
        let place: CGFloat
        switch design.placeCode {
        case .rabat: place = 30  // couché dans le rabat : EAN à 80 %, ~30 mm, comme sur les vraies K7
        case .tranche: place = 30
        case .interieur: place = 40
        case .libre: place = 25
        }
        return min(0.33, place / CGFloat(c.modules.count + 20)) * CGFloat(design.echelleCode)
    }

    // MARK: Plan de la cassette pour Claude

    /// Description exacte de chaque format, zone par zone, en mm : Claude sait où est chaque élément.
    func anatomie() -> String {
        let f = { (x: Double) in String(format: "%.1f", x).replacingOccurrences(of: ".0", with: "") }
        var l: [String] = []
        let g = gabaritJ
        l.append("J-CARD (\(design.volets) volets, dos \(design.dos.nom)) : à plat \(f(g.largeur)) × \(f(g.hauteur)) mm, vue de l'extérieur de gauche à droite, fond perdu 3 mm, origine (0,0) en haut à gauche.")
        for p in g.panneaux {
            let zone = "\(f(p.x))–\(f(p.x + p.largeur)) mm"
            switch p.genre {
            case .rabat:
                l.append("• Rabat (dos court, \(zone)) : en haut le badge de bande (« \(badge(largeur: p.largeur - 2).replacingOccurrences(of: "\n", with: " / ")) ») ; en bas, de haut en bas : \(design.qr && design.placeQR == .rabat ? "QR code, " : "")\(design.codeSpotify && design.placeCode == .rabat ? "code Spotify, " : "")\(design.codeBarres && design.placeCode == .rabat ? "texte « \(texteCode) » puis code-barres \(design.genreCode.nom) \(numeroCode) couché dans la longueur (~30 mm de haut, barres de 10 mm), " : "")ligne « \(projet.ligneDroits) ».")
            case .tranche:
                l.append("• Tranche (\(zone), texte tourné, se lit de haut en bas) : logo/nom de la maison de disque « \(projet.maisonDeDisque) » en haut, texte « \(texteTranche) » au centre, \(design.codeBarres && design.placeCode == .tranche ? "code-barres" : "catalogue « \(projet.numeroCatalogue) »") en bas.")
            case .recto:
                if design.cadrage == .pleineHauteur {
                    l.append("• Recto (\(zone)), cadrage PLEINE HAUTEUR\(design.orientation == .paysage ? ", orientation paysage (cadre \(f(g.hauteur)) × \(f(p.largeur)) mm tourné d'un quart de tour)" : "") : l'image (style « \(v.style.nom) ») remplit tout le recto ; bandeau de \(f(bandeauRecto)) mm couleur de fond en bas avec titre « \(projet.titre) », artiste « \(projet.artiste) » et logo de la maison de disque.")
                } else if design.orientation == .paysage {
                    l.append("• Recto (\(zone)), orientation PAYSAGE : composé dans un cadre \(f(g.hauteur)) × \(f(p.largeur)) mm tourné d'un quart de tour ; image carrée \(f(p.largeur)) mm (en bas du recto une fois tourné), titre « \(projet.titre) » et artiste « \(projet.artiste) » dans la colonne de texte (en haut), logo de la maison de disque sous le texte.")
                } else {
                    l.append("• Recto (\(zone)), orientation VERTICALE : image carrée \(f(p.largeur)) × \(f(p.largeur)) mm en haut (style « \(v.style.nom) »), titre « \(projet.titre) » (\(v.policeTitre)) vers \(f(p.largeur + 3)) mm, artiste « \(projet.artiste) » dessous, logo « \(projet.maisonDeDisque) » en bas centré à ~\(f(g.hauteur - 5)) mm.")
                }
            case .interieur(let i):
                let b = repartition.exterieur[p]
                l.append("• Volet intérieur \(i) (\(zone)) : \(b.map { nomBloc($0) } ?? "vide (couleur de fond)").")
            default: break
            }
        }
        if aUnVerso {
            l.append("• Verso (imprimé au dos) : " + repartition.verso.map { "derrière \($0.key == .recto ? "le recto" : "la tranche et le rabat") : \(nomBloc($0.value))" }.joined(separator: " ; ") + ".")
        }
        if design.placeCode == .libre || design.placeQR == .libre {
            l.append("• Codes placés librement à x = \(f(design.codeX)) mm, y = \(f(design.codeY)) mm (depuis le coin haut gauche de la J-card), rotation \(Int(design.rotationCode))°.")
        }
        if !design.imagesPosees.isEmpty {
            l.append("• Images posées sur le recto : " + design.imagesPosees.map { "\($0.source) (x \(f($0.x)), y \(f($0.y)), \(f($0.largeur)) × \(f($0.hauteur)) du recto)" }.joined(separator: " ; ") + ".")
        }
        l.append("O-CARD (cassingle) \(design.ocard ? "cochée" : "non cochée") : 168,4 × 102,5 mm = patte de colle 15,7 | dos 63,8 (tracklist en haut, QR + code Spotify + code-barres côte à côte en bas) | tranche 12,3 (texte de tranche) | recto 64,3 (même recto que la J-card) | tranche 12,3 (catalogue).")
        l.append("ÉTIQUETTES DE K7 \(design.etiquettes ? "cochées" : "non cochées") : 89 × 42 mm par face (A et B) ; titre en haut à gauche, grande lettre de face en haut à droite, bande de couleur accent sous le titre, fenêtre des bobines 55 × 13 mm à x 17, y 17 (découpée), petite pochette à gauche de la fenêtre, longueur (\(projet.cassette.longueur.nom)) et NR à droite, en bas « artiste · maison de disque · catalogue » et le type de bande.")
        l.append("OBI \(design.obi ? "coché" : "non coché") : bande 62 × 108 mm autour du boîtier, côté tranche : dos 22 | tranche 18 (texte « \(obiSpec().texte) » vertical) | recto 22 ; fond couleur accent.")
        l.append("Couleurs actuelles : fond \(v.palette.fond), texte \(v.palette.texte), accent \(v.palette.accent). Codes : \(design.couleursCode.nom) (barres \(couleursCode.barres) sur \(couleursCode.fond)).")
        return l.joined(separator: "\n")
    }

    private func nomBloc(_ b: Bloc) -> String {
        switch b {
        case .tracklist: "tracklist des faces A et B avec les durées"
        case .notes: "notes de présentation"
        case .credits: "crédits"
        case .notesEtCredits: "notes puis crédits"
        }
    }
}
