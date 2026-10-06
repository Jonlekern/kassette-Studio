import LaFleurCore
import SwiftUI

// Tous les formats sont dessinés en millimètres : `u` = points par mm (2,835 pour l'impression à 100 %).

/// Un texte d'une zone, à sa taille d'impression. S'il est trop long, il déborde (comme il le ferait sur le papier).
struct TexteMM: View {
    let spec: SpecTexte
    let u: CGFloat
    var alignement: Alignment = .center
    var couleur: Color?

    var body: some View {
        Text(spec.texte)
            .font(Font(spec.nsFont(u) as CTFont))
            .kerning(spec.kerning * u / Typo.ptParMM)
            .foregroundStyle(couleur ?? Color(hex: spec.couleur))
            .multilineTextAlignment(alignement == .leading ? .leading : alignement == .trailing ? .trailing : .center)
            .lineLimit(spec.lignes)
            .fixedSize(horizontal: spec.lignes != nil, vertical: true)
            .frame(width: spec.largeur * u, alignment: alignement)
    }
}

extension View {
    /// Place la vue dans un cadre en mm, à une position en mm (dans un ZStack aligné en haut à gauche).
    func placer(_ x: CGFloat, _ y: CGFloat, _ l: CGFloat, _ h: CGFloat, _ u: CGFloat, _ a: Alignment = .topLeading) -> some View {
        frame(width: max(0, l) * u, height: max(0, h) * u, alignment: a).offset(x: x * u, y: y * u)
    }
}

struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        Path { p in p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.closeSubpath() }
    }
}

/// Les formes du design graphique de Claude (coordonnées de 0 à 1 dans le cadre).
struct ElementsGraphiques: View {
    let elements: [ElementGraphique]
    let police: String
    let largeur: CGFloat
    let hauteur: CGFloat
    let u: CGFloat
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(elements.indices, id: \.self) { i in
                let e = elements[i]
                let w = max(0.2, e.largeur * largeur), h = max(0.2, e.hauteur * hauteur)
                let c = Color(hex: e.couleur).opacity(max(0, min(1, e.opacite)))
                Group {
                    switch e.forme {
                    case .rectangle: Rectangle().fill(c)
                    case .cercle: Ellipse().fill(c)
                    case .triangle: Triangle().fill(c)
                    case .ligne: Rectangle().fill(c)
                    case .texte:
                        Text(e.texte ?? "").font(Typo.font(police, h * u * 0.8)).foregroundStyle(c)
                            .lineLimit(1).fixedSize()
                    }
                }
                .frame(width: w * u, height: h * u)
                .rotationEffect(.degrees(e.rotation))
                .offset(x: e.x * largeur * u, y: e.y * hauteur * u)
            }
        }
        .frame(width: largeur * u, height: hauteur * u, alignment: .topLeading)
        .clipped()
    }
}

/// L'image du recto selon le style choisi (pochette, collage, image perso, K7 maison, graphique).
struct ImageRecto: View {
    let mise: Mise
    let largeur: CGFloat
    let hauteur: CGFloat
    let u: CGFloat

    var covers: [URL] {
        var vues = Set<URL>()
        return mise.projet.toutes.compactMap(\.morceau.pochetteURL).filter { vues.insert($0).inserted }.prefix(16).map { $0 }
    }
    var principale: URL? { mise.design.imagePerso ?? mise.projet.pochetteURL ?? covers.first }
    /// Recadrage (demande 1) et agrandissement de l'image, réglés à la souris, au curseur ou par l'IA.
    var cadre: CGPoint { CGPoint(x: mise.design.cadrageX, y: mise.design.cadrageY) }
    var zoom: CGFloat { CGFloat(mise.design.ajustement("recto-image").echelle) }

    var body: some View {
        let v = mise.design.variante
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Color(hex: v.palette.fond))
            switch v.style {
            case .pochette:
                ImageCache(url: mise.projet.pochetteURL ?? covers.first, opacite: v.opaciteImage, position: cadre, zoom: zoom)
                    .frame(width: largeur * u, height: hauteur * u).clipped()
            case .imagePerso:
                ImageCache(url: principale, opacite: v.opaciteImage, position: cadre, zoom: zoom)
                    .frame(width: largeur * u, height: hauteur * u).clipped()
            case .collage:
                let n = max(1, Int(ceil(sqrt(Double(max(1, covers.count))))))
                let c = largeur / CGFloat(n), l = hauteur / CGFloat(n)
                ForEach(0..<(n * n), id: \.self) { i in
                    ImageCache(url: covers.isEmpty ? nil : covers[i % covers.count], opacite: v.opaciteImage)
                        .frame(width: c * u, height: l * u).clipped()
                        .offset(x: CGFloat(i % n) * c * u, y: CGFloat(i / n) * l * u)
                }
            case .maison:
                // Papier, photo scotchée de travers, comme une K7 faite main.
                Rectangle().fill(Color(hex: "#EFE6D2"))
                ImageCache(url: principale, opacite: v.opaciteImage)
                    .frame(width: largeur * 0.72 * u, height: hauteur * 0.72 * u).clipped()
                    .border(Color.white, width: 1.2 * u)
                    .rotationEffect(.degrees(-3))
                    .offset(x: largeur * 0.14 * u, y: hauteur * 0.12 * u)
                ForEach(0..<2, id: \.self) { i in
                    Rectangle().fill(Color(hex: "#F6F0C8").opacity(0.75))
                        .frame(width: 14 * u, height: 4.5 * u)
                        .rotationEffect(.degrees(i == 0 ? -35 : 32))
                        .offset(x: (i == 0 ? largeur * 0.08 : largeur * 0.68) * u, y: hauteur * (i == 0 ? 0.1 : 0.08) * u)
                }
            case .graphique:
                EmptyView()
            }
            ElementsGraphiques(elements: v.elements, police: v.policeTitre, largeur: largeur, hauteur: hauteur, u: u)
        }
        .frame(width: largeur * u, height: hauteur * u, alignment: .topLeading)
        .clipped()
    }
}

/// Recto d'une J-card ou d'une O-card : image carrée en haut, titre, artiste, logo.
struct RectoVue: View {
    let mise: Mise
    let largeur: CGFloat
    let hauteur: CGFloat
    /// Fond perdu à ajouter en haut et à droite (mm) ; en paysage, l'image déborde aussi en bas.
    var perduHaut: CGFloat = 0
    var perduDroite: CGFloat = 0
    let u: CGFloat

    var body: some View {
        let p = mise.design.variante.palette
        let r = mise.zonesRecto(l: largeur, h: hauteur)
        Group {
            if mise.design.cadrage == .pleineHauteur {
                pleineHauteur(r)
            } else if mise.design.orientation == .paysage {
                // Composé à l'horizontale (hauteur × largeur), puis tourné d'un quart de tour :
                // l'image carrée se retrouve en bas du recto, le texte en haut, à lire en penchant la tête.
                ZStack(alignment: .topLeading) {
                    ImageRecto(mise: mise, largeur: largeur + perduHaut, hauteur: largeur + perduDroite, u: u).cadrageImage(mise, u, angle: -90)
                        .offset(x: -perduHaut * u)
                    ImagesPosees(images: mise.design.imagesPosees, largeur: hauteur, hauteur: largeur, u: u)
                    VStack(spacing: 1.5 * u) {
                        TexteMM(spec: r.titre, u: u).element("recto-titre", mise, u, angle: -90)
                        TexteMM(spec: r.artiste, u: u).element("recto-artiste", mise, u, angle: -90)
                    }
                    .placer(largeur + 3, 4, hauteur - largeur - 6, largeur - 14, u, .center)
                    if mise.design.afficherLogoMaison {
                        LogoMaison(mise: mise, u: u).element("recto-logo", mise, u, angle: -90).placer(largeur + (hauteur - largeur) / 2 - 12, largeur - 7, 24, 5, u, .center)
                    }
                }
                .frame(width: hauteur * u, height: largeur * u, alignment: .topLeading)
                .rotationEffect(.degrees(-90))
                .frame(width: largeur * u, height: hauteur * u)
            } else {
                ZStack(alignment: .topLeading) {
                    ImageRecto(mise: mise, largeur: largeur + perduDroite, hauteur: largeur + perduHaut, u: u).cadrageImage(mise, u)
                        .offset(y: -perduHaut * u)
                    ImagesPosees(images: mise.design.imagesPosees, largeur: largeur, hauteur: hauteur, u: u)
                    VStack(spacing: 1.5 * u) {
                        TexteMM(spec: r.titre, u: u).element("recto-titre", mise, u)
                        TexteMM(spec: r.artiste, u: u).element("recto-artiste", mise, u)
                    }
                    .placer(4, largeur + 2.5, largeur - 8, hauteur - largeur - 9, u, .top)
                    if mise.design.afficherLogoMaison {
                        LogoMaison(mise: mise, u: u).element("recto-logo", mise, u).placer(largeur / 2 - 12, hauteur - 9, 24, 6, u, .bottom)
                    }
                }
                .frame(width: largeur * u, height: hauteur * u, alignment: .topLeading)
            }
        }
        .background(Color(hex: p.fond))
    }

    /// Image sur tout le recto, bandeau titre en bas (famille Nirvana, The Cure, Nas).
    @ViewBuilder
    private func pleineHauteur(_ r: (titre: SpecTexte, artiste: SpecTexte)) -> some View {
        let p = mise.design.variante.palette
        let paysage = mise.design.orientation == .paysage
        // Cadre de composition : tourné d'un quart de tour en paysage.
        let w = paysage ? hauteur : largeur, h = paysage ? largeur : hauteur
        let b = mise.bandeauRecto
        let pw = paysage ? perduHaut : perduDroite, ph = paysage ? perduDroite : perduHaut
        let cadre = ZStack(alignment: .topLeading) {
            // En paysage, l'image touche le haut et le bas du recto : fond perdu des deux côtés.
            ImageRecto(mise: mise, largeur: w + (paysage ? 2 * pw : pw), hauteur: h - b + (paysage ? 0 : ph), u: u).cadrageImage(mise, u, angle: paysage ? -90 : 0)
                .offset(x: paysage ? -pw * u : 0, y: paysage ? 0 : -ph * u)
            ImagesPosees(images: mise.design.imagesPosees, largeur: w, hauteur: h, u: u)
            Rectangle().fill(Color(hex: p.fond))
                .frame(width: (w + (paysage ? 2 * pw : pw)) * u, height: b * u)
                .offset(x: paysage ? -pw * u : 0, y: (h - b) * u)
            Rectangle().fill(Color(hex: p.accent)).frame(width: (w + (paysage ? 2 * pw : pw)) * u, height: 0.8 * u)
                .offset(x: paysage ? -pw * u : 0, y: (h - b) * u)
            if paysage {
                VStack(alignment: .leading, spacing: 1 * u) {
                    TexteMM(spec: r.titre, u: u).element("recto-titre", mise, u, angle: paysage ? -90 : 0)
                    TexteMM(spec: r.artiste, u: u).element("recto-artiste", mise, u, angle: paysage ? -90 : 0)
                }
                .placer(4, h - b + 2, w - 36, b - 4, u, .leading)
                if mise.design.afficherLogoMaison {
                    LogoMaison(mise: mise, u: u).element("recto-logo", mise, u, angle: paysage ? -90 : 0).placer(w - 29, h - b + 5, 25, 8, u, .center)
                }
            } else {
                VStack(spacing: 1.5 * u) {
                    TexteMM(spec: r.titre, u: u).element("recto-titre", mise, u, angle: paysage ? -90 : 0)
                    TexteMM(spec: r.artiste, u: u).element("recto-artiste", mise, u, angle: paysage ? -90 : 0)
                }
                .placer(4, h - b + 2, w - 8, b - 9.5, u, .top)
                if mise.design.afficherLogoMaison {
                    LogoMaison(mise: mise, u: u).element("recto-logo", mise, u, angle: paysage ? -90 : 0).placer(w / 2 - 12, h - 6.5, 24, 4.5, u, .bottom)
                }
            }
        }
        .frame(width: w * u, height: h * u, alignment: .topLeading)
        if paysage {
            cadre.rotationEffect(.degrees(-90)).frame(width: largeur * u, height: hauteur * u)
        } else {
            cadre
        }
    }
}

/// Images posées sur le recto (logos, écussons…), coordonnées de 0 à 1.
struct ImagesPosees: View {
    let images: [ImagePosee]
    let largeur: CGFloat
    let hauteur: CGFloat
    let u: CGFloat
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(images) { i in
                ImageCache(url: i.url, remplir: false)
                    .frame(width: i.largeur * largeur * u, height: i.hauteur * hauteur * u)
                    .offset(x: i.x * largeur * u, y: i.y * hauteur * u)
            }
        }
        .frame(width: largeur * u, height: hauteur * u, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}

/// Logo de la maison de disque : STUDIOLAFLEUR dessiné, un logo importé, ou le nom en texte.
struct LogoMaison: View {
    let mise: Mise
    let u: CGFloat
    var body: some View {
        let p = mise.design.variante.palette
        if Mise.estLaMaison(mise.projet.maisonDeDisque) {
            LogoForme().fill(Color(hex: p.texte)).frame(width: 24 * u, height: 1.8 * u)
        } else if let logo = mise.design.logoMaison {
            ImageCache(url: logo, remplir: false)
        } else {
            Text(mise.projet.maisonDeDisque.uppercased()).font(Typo.font(mise.design.variante.policeTexte, 1.6 * u))
                .foregroundStyle(Color(hex: p.texte)).lineLimit(1).minimumScaleFactor(0.5)
        }
    }
}

/// Tranche : catalogue d'un côté, texte au milieu, maison de disque (ou code) de l'autre. Se lit de haut en bas.
struct TrancheVue: View {
    let mise: Mise
    let longueur: CGFloat
    let epaisseur: CGFloat
    var avecCode = false
    let u: CGFloat

    var body: some View {
        let p = mise.design.variante.palette
        let petit = Typo.font(mise.design.variante.policeTexte, 4.6 * u / Typo.ptParMM)
        // Comme sur les vraies K7 : maison de disque en haut, artiste · titre, catalogue en bas.
        HStack(spacing: 0) {
            Group {
                if Mise.estLaMaison(mise.projet.maisonDeDisque) {
                    LogoForme().fill(Color(hex: p.texte)).frame(width: 12 * u, height: 1.2 * u)
                } else if let logo = mise.design.logoMaison {
                    ImageCache(url: logo, remplir: false).frame(width: 12 * u, height: 8 * u).rotationEffect(.degrees(-90))
                } else {
                    Text(mise.projet.maisonDeDisque.uppercased()).font(petit).foregroundStyle(Color(hex: p.texte))
                        .lineLimit(1).minimumScaleFactor(0.4)
                }
            }
            .frame(width: 14 * u)
            .element("tranche-logo", mise, u, angle: 90)
            TexteMM(spec: mise.tranche(longueur: longueur, epaisseur: epaisseur), u: u).element("tranche-texte", mise, u, angle: 90)
            Group {
                if avecCode, let c = CodesBarres.generer(mise.design.genreCode, mise.numeroCode) {
                    let (b, f) = mise.couleursCode
                    let m = min(0.13, 13 / CGFloat(c.modules.count + 20))
                    CodeBarresVue(code: c, module: m, hauteur: epaisseur - 3.5, barres: Color(hex: b), fond: Color(hex: f), chiffres: false, u: u)
                } else {
                    Text(mise.projet.numeroCatalogue)
                        .font(Typo.font(mise.design.variante.policeTexte, 4.6 * mise.e("catalogue") * u / Typo.ptParMM))
                        .foregroundStyle(Color(hex: p.texte))
                        .lineLimit(1).minimumScaleFactor(0.5)
                }
            }
            .frame(width: 14 * u)
            .element("tranche-catalogue", mise, u, angle: 90)
        }
        .frame(width: longueur * u, height: epaisseur * u)
        .rotationEffect(.degrees(90))
        .frame(width: epaisseur * u, height: longueur * u)
    }
}

/// Rabat (dos court de la J-card) : badge de bande en haut, codes et ligne ℗/© en bas.
struct RabatVue: View {
    let mise: Mise
    let largeur: CGFloat
    let hauteur: CGFloat
    let u: CGFloat
    var body: some View {
        let l = largeur - 2
        VStack(spacing: 1.2 * u) {
            TexteMM(spec: mise.badgeSpec(largeur: l), u: u).element("rabat-badge", mise, u)
            Spacer(minLength: 0)
            PileCodes(mise: mise, largeur: l, u: u,
                      avecQR: mise.design.placeQR == .rabat, avecBarres: mise.design.placeCode == .rabat, vertical: true)
                .element("rabat-codes", mise, u)
            TexteMM(spec: mise.droitsSpec(largeur: l), u: u).element("rabat-droits", mise, u)
        }
        .padding(.vertical, 3 * u)
        .frame(width: largeur * u, height: hauteur * u)
    }
}

/// Un volet intérieur : tracklist, notes ou crédits.
struct BlocVue: View {
    let mise: Mise
    let bloc: Mise.Bloc
    let largeur: CGFloat
    let hauteur: CGFloat
    /// O-card : tous les codes cochés vont sous la tracklist, côte à côte.
    var tousLesCodes = false
    let u: CGFloat

    var body: some View {
        let v = mise.design.variante
        let l = largeur - 8
        VStack(alignment: .leading, spacing: 0) {
            switch bloc {
            case .tracklist:
                let t = mise.tracklistTaille()
                let f = Typo.font(v.policeTexte, t * u / Typo.ptParMM)
                let fg = Typo.font(v.policeTexte, t * u / Typo.ptParMM, gras: true)
                let ligne = Typo.hauteurLigneMM(Typo.nsFont(v.policeTexte, t)) * Mise.interligne
                VStack(alignment: .leading, spacing: 0) {
                    ForEach([Face.a, .b], id: \.self) { face in
                        let lignes = mise.lignes(face)
                        if !lignes.isEmpty {
                            Text("FACE \(face.rawValue) · \(formaterDuree(Faces.duree(mise.projet.pistes(face), ReglagesPlatine())))")
                                .font(fg).foregroundStyle(Color(hex: mise.couleurTitresFaces))
                                .frame(height: ligne * u, alignment: .leading)
                            ForEach(lignes.indices, id: \.self) { i in
                                let ln = lignes[i]
                                HStack(spacing: 1.5 * u) {
                                    Text(ln.0).font(fg).frame(width: 5 * u, alignment: .leading)
                                    Text(ln.1).font(f).lineLimit(1).fixedSize()
                                    Spacer(minLength: 1 * u)
                                    Text(ln.2).font(f)
                                }
                                .foregroundStyle(Color(hex: v.palette.texte))
                                .frame(width: l * u, height: ligne * u, alignment: .leading)
                            }
                            Spacer().frame(height: ligne * u)
                        }
                    }
                }
                .element("volets-tracklist", mise, u)
                Spacer(minLength: 0)
                if tousLesCodes {
                    PileCodes(mise: mise, largeur: 26, u: u, cote: true).frame(maxWidth: .infinity)
                } else {
                    PileCodes(mise: mise, largeur: min(l, 30), u: u,
                              avecQR: mise.design.placeQR == .interieur, avecBarres: mise.design.placeCode == .interieur)
                        .frame(maxWidth: .infinity)
                }
            case .notes:
                TexteMM(spec: mise.notesSpec(largeur: l, hauteur: hauteur - 10), u: u, alignement: .leading).element("volets-notes", mise, u)
                Spacer(minLength: 0)
            case .credits:
                TexteMM(spec: mise.creditsSpec(largeur: l, hauteur: hauteur - 10), u: u, alignement: .leading).element("volets-credits", mise, u)
                Spacer(minLength: 0)
            case .notesEtCredits:
                TexteMM(spec: mise.notesSpec(largeur: l, hauteur: hauteur - 10), u: u, alignement: .leading).element("volets-notes", mise, u)
                Spacer().frame(height: 4 * u)
                TexteMM(spec: mise.creditsSpec(largeur: l, hauteur: hauteur - 10), u: u, alignement: .leading).element("volets-credits", mise, u)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 4 * u).padding(.vertical, 5 * u)
        .frame(width: largeur * u, height: hauteur * u, alignment: .topLeading)
    }
}

enum CoteJCard { case exterieur, verso }

/// Codes placés librement sur la J-card ; dans l'aperçu, on les glisse à la souris.
struct CodesLibres: View {
    let mise: Mise
    let u: CGFloat
    var deplacer: ((Double, Double) -> Void)?
    @State private var glisse: CGSize = .zero

    var body: some View {
        let d = mise.design
        PileCodes(mise: mise, largeur: 25, u: u, avecQR: d.placeQR == .libre, avecBarres: d.placeCode == .libre)
            .fixedSize()
            .rotationEffect(.degrees(d.rotationCode))
            .offset(x: d.codeX * u + glisse.width, y: d.codeY * u + glisse.height)
            .gesture(DragGesture()
                .onChanged { glisse = $0.translation }
                .onEnded { v in
                    deplacer?(d.codeX + v.translation.width / u, d.codeY + v.translation.height / u)
                    glisse = .zero
                },
                including: deplacer == nil ? .none : .all)
            .help(deplacer == nil ? "" : "Glisse les codes où tu veux")
    }
}

/// J-card à plat. `perdu` : fond perdu en mm (0 à l'écran, 3 pour l'impression).
struct JCardVue: View {
    let mise: Mise
    var cote: CoteJCard = .exterieur
    var perdu: CGFloat = 0
    var guides = false
    /// Aperçu : appelé quand on a glissé les codes placés librement (nouvelle position en mm).
    var deplacerCode: ((Double, Double) -> Void)?
    let u: CGFloat

    var body: some View {
        let g = mise.gabaritJ
        let p = mise.design.variante.palette
        let rep = mise.repartition
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Color(hex: p.fond))
            ZStack(alignment: .topLeading) {
                if cote == .exterieur {
                    ForEach(g.panneaux, id: \.self) { pan in
                        let dernier = pan == g.panneaux.last
                        Group {
                            switch pan.genre {
                            case .rabat: RabatVue(mise: mise, largeur: pan.largeur, hauteur: g.hauteur, u: u)
                            case .tranche: TrancheVue(mise: mise, longueur: g.hauteur, epaisseur: pan.largeur,
                                                      avecCode: mise.design.codeBarres && mise.design.placeCode == .tranche, u: u)
                            case .recto: RectoVue(mise: mise, largeur: pan.largeur, hauteur: g.hauteur,
                                                  perduHaut: perdu, perduDroite: dernier ? perdu : 0, u: u)
                            default:
                                if let b = rep.exterieur[pan] { BlocVue(mise: mise, bloc: b, largeur: pan.largeur, hauteur: g.hauteur, u: u) }
                            }
                        }
                        .frame(width: pan.largeur * u, height: g.hauteur * u, alignment: .topLeading)
                        .offset(x: pan.x * u)
                    }
                } else {
                    // Verso : les volets sont vus de dos, donc dans l'ordre inverse.
                    ForEach(g.panneaux, id: \.self) { pan in
                        if let b = rep.verso[pan.genre] {
                            let w = mise.largeurVerso(pan.genre)
                            BlocVue(mise: mise, bloc: b, largeur: w, hauteur: g.hauteur, u: u)
                                .offset(x: (g.largeur - pan.x - w) * u)
                        }
                    }
                }
                if guides { Plis(plis: cote == .exterieur ? g.plis : g.plis.map { g.largeur - $0 }, hauteur: g.hauteur, u: u) }
                if cote == .exterieur && (mise.design.placeCode == .libre || mise.design.placeQR == .libre) {
                    CodesLibres(mise: mise, u: u, deplacer: deplacerCode)
                }
            }
            .offset(x: perdu * u, y: perdu * u)
        }
        .frame(width: (g.largeur + 2 * perdu) * u, height: (g.hauteur + 2 * perdu) * u, alignment: .topLeading)
        .clipped()
    }
}

/// Plis en pointillés (aperçu seulement).
struct Plis: View {
    let plis: [Double]
    let hauteur: CGFloat
    let u: CGFloat
    var body: some View {
        Path { p in for x in plis { p.move(to: CGPoint(x: x * u, y: 0)); p.addLine(to: CGPoint(x: x * u, y: hauteur * u)) } }
            .stroke(Color.gray.opacity(0.7), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
    }
}

/// O-card de cassingle : patte de colle | dos (tracklist, codes) | tranche | recto | tranche (catalogue).
struct OCardVue: View {
    let mise: Mise
    var perdu: CGFloat = 0
    var guides = false
    let u: CGFloat
    var body: some View {
        let g = Gabarits.ocard
        let p = mise.design.variante.palette
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Color(hex: p.fond))
            ZStack(alignment: .topLeading) {
                ForEach(g.panneaux, id: \.self) { pan in
                    Group {
                        switch pan.genre {
                        case .colle:
                            Rectangle().fill(Color(hex: p.accent))
                        case .dos:
                            BlocVue(mise: mise, bloc: .tracklist, largeur: pan.largeur, hauteur: g.hauteur, tousLesCodes: true, u: u)
                        case .tranche:
                            TrancheVue(mise: mise, longueur: g.hauteur, epaisseur: pan.largeur, u: u)
                        case .recto:
                            RectoVue(mise: mise, largeur: pan.largeur, hauteur: g.hauteur, perduHaut: perdu, u: u)
                        default:
                            Text(mise.projet.numeroCatalogue).font(Typo.font(mise.design.variante.policeTexte, 2 * u, gras: true))
                                .foregroundStyle(Color(hex: p.texte)).fixedSize()
                                .rotationEffect(.degrees(90)).frame(width: pan.largeur * u, height: g.hauteur * u)
                        }
                    }
                    .frame(width: pan.largeur * u, height: g.hauteur * u, alignment: .topLeading)
                    .offset(x: pan.x * u)
                }
                if guides { Plis(plis: g.plis, hauteur: g.hauteur, u: u) }
            }
            .offset(x: perdu * u, y: perdu * u)
        }
        .frame(width: (g.largeur + 2 * perdu) * u, height: (g.hauteur + 2 * perdu) * u, alignment: .topLeading)
        // Patte de colle en biais.
        .mask(FormeOCard(perdu: perdu, u: u))
    }
}

struct FormeOCard: Shape {
    let perdu: CGFloat
    let u: CGFloat
    func path(in r: CGRect) -> Path {
        let b = perdu * u, biais = 5 * u, colle = 15.7 * u
        return Path { p in
            p.move(to: CGPoint(x: b + biais, y: 0))
            p.addLine(to: CGPoint(x: b + colle, y: 0))
            p.addLine(to: CGPoint(x: r.maxX, y: 0)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: b + colle, y: r.maxY)); p.addLine(to: CGPoint(x: b + biais, y: r.maxY))
            p.addLine(to: CGPoint(x: 0, y: r.maxY - b - biais)); p.addLine(to: CGPoint(x: 0, y: b + biais))
            p.closeSubpath()
        }
    }
}

/// Étiquette d'une face de la K7 (89 × 42 mm) avec sa fenêtre. Sert aussi à la K7 de la platine.
struct EtiquetteVue: View {
    let mise: Mise
    let face: Face
    var perdu: CGFloat = 0
    /// Pour l'impression : la fenêtre est laissée blanche avec un trait de coupe.
    var fenetreADecouper = true
    let u: CGFloat

    var body: some View {
        let p = mise.design.variante.palette
        let fe = Gabarits.fenetreEtiquette
        let petit = Typo.font(mise.design.variante.policeTexte, 4.8 * u / Typo.ptParMM)
        let d = mise.design
        let pochette = mise.projet.pochetteURL ?? mise.projet.toutes.first?.morceau.pochetteURL
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Color(hex: p.fond))
            // « Pochette en fond » : l'image remplit toute l'étiquette (fond perdu compris), un voile garde les textes lisibles.
            if d.etiquettePochette == .fond {
                ImageCache(url: pochette, position: CGPoint(x: d.cadrageEtiquetteX, y: d.cadrageEtiquetteY),
                           zoom: CGFloat(d.ajustement("etiquette-pochette").echelle))
                    .frame(width: (89 + 2 * perdu) * u, height: (42 + 2 * perdu) * u).clipped()
                    .cadrageImage(mise, u, id: "etiquette-pochette", largeur: 89, hauteur: 42)
                Rectangle().fill(Color(hex: p.fond).opacity(min(0.9, max(0, d.voileEtiquette)))).allowsHitTesting(false)
            }
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color(hex: p.accent)).frame(width: 89 * u, height: 2 * u).offset(y: 13.5 * u)
                TexteMM(spec: mise.etiquetteTitre(), u: u, alignement: .leading).element("etiquette-titre", mise, u)
                    .placer(4, 4, 67, 8, u, .leading)
                Text(face.rawValue).font(Typo.font(mise.design.variante.policeTitre, 9 * u, gras: true))
                    .foregroundStyle(Color(hex: p.texte)).element("etiquette-face", mise, u).placer(74, 1.5, 12, 11, u, .center)
                if d.etiquettePochette == .petite {
                    ImageCache(url: pochette)
                        .frame(width: 11 * u, height: 11 * u).clipped()
                        .element("etiquette-pochette", mise, u)
                        .offset(x: 4 * u, y: 18 * u)
                }
                VStack(spacing: 0.6 * u) {
                    Text(mise.projet.cassette.longueur.nom).font(Typo.font(mise.design.variante.policeTexte, 2.6 * u, gras: true))
                    Text(mise.projet.cassette.reducteur == .aucun ? "" : "NR").font(petit)
                }
                .foregroundStyle(Color(hex: p.texte)).element("etiquette-longueur", mise, u).placer(74, 18, 12, 11, u, .center)
                if fenetreADecouper {
                    RoundedRectangle(cornerRadius: 2 * u).fill(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 2 * u).stroke(Color.gray, style: StrokeStyle(lineWidth: 0.4, dash: [2, 2])))
                        .placer(fe.x, fe.y, fe.largeur, fe.hauteur, u)
                }
                HStack {
                    Text("\(mise.projet.artiste.uppercased())\(mise.projet.artiste.isEmpty ? "" : " · ")\(mise.projet.maisonDeDisque) · \(mise.projet.numeroCatalogue)")
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Spacer(minLength: 2 * u)
                    Text(mise.projet.cassette.bande.badge).lineLimit(1)
                }
                .font(petit).foregroundStyle(Color(hex: p.texte))
                .element("etiquette-bas", mise, u)
                .placer(4, 32.5, 81, 6, u, .leading)
            }
            .offset(x: perdu * u, y: perdu * u)
        }
        .frame(width: (89 + 2 * perdu) * u, height: (42 + 2 * perdu) * u, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: perdu > 0 ? 0 : 2.5 * u))
        // Sur la K7 de la platine, la fenêtre est un vrai trou : on voit les bobines.
        .mask {
            if fenetreADecouper {
                Rectangle()
            } else {
                TrouFenetre(u: u).fill(style: FillStyle(eoFill: true))
            }
        }
    }
}

struct TrouFenetre: Shape {
    let u: CGFloat
    func path(in r: CGRect) -> Path {
        let f = Gabarits.fenetreEtiquette
        var p = Path(r)
        p.addRoundedRect(in: CGRect(x: f.x * u, y: f.y * u, width: f.largeur * u, height: f.hauteur * u),
                         cornerSize: CGSize(width: 2 * u, height: 2 * u))
        return p
    }
}

/// Obi : bande autour du boîtier, côté tranche. Texte vertical façon K7 japonaise.
struct ObiVue: View {
    let mise: Mise
    var perdu: CGFloat = 0
    var guides = false
    let u: CGFloat
    var body: some View {
        let g = Gabarits.obi
        let p = mise.design.variante.palette
        let spec = mise.obiSpec()
        let vertical = { (t: String, taille: CGFloat, largeur: CGFloat) in
            Text(t).font(Typo.font(mise.design.variante.policeTexte, taille * u / Typo.ptParMM, gras: true))
                .foregroundStyle(Color(hex: mise.couleurObi)).lineLimit(1).minimumScaleFactor(0.5)
                .frame(width: (g.hauteur - 12) * u, height: largeur * u)
                .rotationEffect(.degrees(90)).frame(width: largeur * u, height: g.hauteur * u)
        }
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Color(hex: p.accent))
            ZStack(alignment: .topLeading) {
                vertical("\(mise.projet.numeroCatalogue) · \(mise.projet.cassette.bande.badge)", 5.5, 22)
                TexteMM(spec: spec, u: u).frame(width: spec.largeur * u, height: 18 * u)
                    .element("obi-texte", mise, u, angle: 90)
                    .rotationEffect(.degrees(90)).frame(width: 18 * u, height: g.hauteur * u).offset(x: 22 * u)
                vertical(mise.projet.artiste.uppercased() + " · CASSETTE", 6, 22).offset(x: 40 * u)
                if guides { Plis(plis: g.plis, hauteur: g.hauteur, u: u) }
            }
            .offset(x: perdu * u, y: perdu * u)
        }
        .frame(width: (g.largeur + 2 * perdu) * u, height: (g.hauteur + 2 * perdu) * u, alignment: .topLeading)
        .clipped()
    }
}
