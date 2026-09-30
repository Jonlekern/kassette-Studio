import AppKit
import LaFleurCore
import PDFKit
import SwiftUI

/// Une page à imprimer : un objet (J-card, O-card…) centré sur son papier, avec ses repères.
struct PageExport {
    let nom: String
    let papier: Papier
    /// Taille de l'objet fini (sans fond perdu), en mm.
    let largeur: CGFloat
    let hauteur: CGFloat
    /// Plis verticaux (mm depuis le bord gauche de l'objet).
    let plis: [Double]
    /// Objets en plus sur la même page (étiquettes A et B) : décalage vertical de chacun (mm).
    let copies: [CGFloat]
    /// La vue de l'objet, fond perdu compris, à l'échelle de l'impression.
    let vue: AnyView
    /// Verso : le décalage horizontal de l'imprimante s'applique à l'envers.
    var verso = false
}

@MainActor
enum Export {
    static let u = Typo.ptParMM
    static let perdu = CGFloat(Gabarits.fondPerdu)

    static func pages(_ mise: Mise) -> [PageExport] {
        let d = mise.design
        let b = d.reperes ? perdu : 0
        var pages: [PageExport] = []
        func page(_ nom: String, _ l: Double, _ h: Double, _ plis: [Double], copies: [CGFloat] = [0], verso: Bool = false, _ vue: some View) {
            let hauteurTotale = h + Double(copies.last ?? 0)
            pages.append(PageExport(nom: nom, papier: Papier.pour(largeur: l, hauteur: hauteurTotale), largeur: l, hauteur: h,
                                    plis: plis, copies: copies, vue: AnyView(vue), verso: verso))
        }
        if d.jcard {
            let g = mise.gabaritJ
            page("J-card · extérieur", g.largeur, g.hauteur, g.plis, JCardVue(mise: mise, perdu: b, u: u))
            if mise.aUnVerso {
                page("J-card · verso (imprimer au dos, retourner sur le grand côté)", g.largeur, g.hauteur,
                     g.plis.map { g.largeur - $0 }, verso: true, JCardVue(mise: mise, cote: .verso, perdu: b, u: u))
            }
        }
        if d.ocard {
            let g = Gabarits.ocard
            page("O-card", g.largeur, g.hauteur, g.plis, OCardVue(mise: mise, perdu: b, u: u))
        }
        if d.etiquettes {
            let ecart: CGFloat = 42 + 2 * b + 14
            page("Étiquettes de K7 · faces A et B", 89, 42, [], copies: [0, ecart],
                 VStack(spacing: 14 * u) {
                     EtiquetteVue(mise: mise, face: .a, perdu: b, u: u)
                     EtiquetteVue(mise: mise, face: .b, perdu: b, u: u)
                 })
        }
        if d.obi {
            let g = Gabarits.obi
            page("Obi", g.largeur, g.hauteur, g.plis, ObiVue(mise: mise, perdu: b, u: u))
        }
        return pages
    }

    /// PDF vectoriel, une page par objet, à imprimer à 100 %.
    /// `echelleX/Y` : correction d'échelle mesurée sur la page de calibrage (1 = aucune).
    static func pdf(_ pages: [PageExport], mise: Mise, decalageX: CGFloat, decalageY: CGFloat,
                    echelleX: CGFloat = 1, echelleY: CGFloat = 1) -> Data {
        let data = NSMutableData()
        var boite = CGRect(x: 0, y: 0, width: 210 * u, height: 297 * u)
        guard let conso = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: conso, mediaBox: &boite, [kCGPDFContextCreator: "LaFleurStudio"] as CFDictionary) else { return Data() }
        for p in pages {
            var b = CGRect(x: 0, y: 0, width: p.papier.largeur * u, height: p.papier.hauteur * u)
            ctx.beginPage(mediaBox: &b)
            let r = ImageRenderer(content: PageVue(page: p, mise: mise, decalageX: p.verso ? -decalageX : decalageX, decalageY: decalageY)
                .scaleEffect(x: echelleX, y: echelleY, anchor: .topLeading)
                .frame(width: b.width, height: b.height, alignment: .topLeading))
            r.proposedSize = ProposedViewSize(width: b.width, height: b.height)
            r.render { _, dessiner in dessiner(ctx) }
            ctx.endPage()
        }
        ctx.closePDF()
        return data as Data
    }

    /// Image PNG d'une vue à la résolution voulue.
    static func png(_ vue: some View, dpi: CGFloat) -> Data? {
        let r = ImageRenderer(content: vue.environment(\.colorScheme, .light))
        r.scale = dpi / 72
        guard let cg = r.cgImage else { return nil }
        let rep = NSBitmapImageRep(cgImage: cg)
        rep.size = NSSize(width: CGFloat(cg.width) * 72 / dpi, height: CGFloat(cg.height) * 72 / dpi)
        return rep.representation(using: .png, properties: [:])
    }

    /// Tous les formats cochés, à plat, pour que Claude regarde le rendu.
    static func planchePourClaude(_ mise: Mise) -> Data? {
        let ps = pages(mise)
        let vue = VStack(alignment: .leading, spacing: 8 * u) {
            ForEach(ps.indices, id: \.self) { i in
                let p = ps[i]
                VStack(alignment: .leading, spacing: 2 * u) {
                    Text(p.nom).font(.system(size: 10))
                    p.vue
                }
            }
        }
        .padding(6 * u).background(Color.white)
        return png(vue, dpi: 150)
    }

    static func imprimer(_ data: Data, titre: String) {
        guard let doc = PDFDocument(data: data) else { return }
        let info = (NSPrintInfo.shared.copy() as? NSPrintInfo) ?? NSPrintInfo()
        info.topMargin = 0; info.bottomMargin = 0; info.leftMargin = 0; info.rightMargin = 0
        info.horizontalPagination = .clip; info.verticalPagination = .clip
        info.isHorizontallyCentered = false; info.isVerticallyCentered = false
        guard let op = doc.printOperation(for: info, scalingMode: .pageScaleNone, autoRotate: true) else { return }
        op.jobTitle = titre
        op.showsPrintPanel = true
        op.showsProgressPanel = true
        op.run()
    }

    /// Page de calibrage : règles en cm et en pouces, repères pour le décalage. Jamais corrigée elle-même.
    static func calibrage(papier: Papier = .a4) -> Data {
        let data = NSMutableData()
        var b = CGRect(x: 0, y: 0, width: papier.largeur * u, height: papier.hauteur * u)
        guard let conso = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: conso, mediaBox: &b, nil) else { return Data() }
        ctx.beginPage(mediaBox: &b)
        let r = ImageRenderer(content: PageCalibrage(papier: papier))
        r.proposedSize = ProposedViewSize(width: b.width, height: b.height)
        r.render { _, dessiner in dessiner(ctx) }
        ctx.endPage()
        ctx.closePDF()
        return data as Data
    }
}

/// Une page imprimée : objet centré, traits de coupe, repères de pliage, légende.
struct PageVue: View {
    let page: PageExport
    let mise: Mise
    let decalageX: CGFloat
    let decalageY: CGFloat
    private let u = Typo.ptParMM

    var body: some View {
        let pl = page.papier.largeur, ph = page.papier.hauteur
        let hauteurBloc = page.hauteur + (page.copies.last ?? 0)
        let x0 = (pl - page.largeur) / 2 + decalageX
        let y0 = (ph - hauteurBloc) / 2 + decalageY
        let b: CGFloat = mise.design.reperes ? Export.perdu : 0
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Color.white)
            page.vue.offset(x: (x0 - b) * u, y: (y0 - b) * u)
            if mise.design.reperes {
                ForEach(page.copies.indices, id: \.self) { i in
                    Reperes(x: x0, y: y0 + page.copies[i], largeur: page.largeur, hauteur: page.hauteur, plis: page.plis, u: u)
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("LaFleurStudio · \(mise.projet.numeroCatalogue) · \(page.nom)")
                Text("Imprimer à 100 % (jamais « ajuster à la page ») · traits pleins : coupe · pointillés : pliage · usage personnel, non commercial")
            }
            .font(.system(size: 6.5)).foregroundStyle(Color.gray)
            .offset(x: 10 * u, y: (ph - 12) * u)
        }
        .frame(width: pl * u, height: ph * u, alignment: .topLeading)
        .environment(\.colorScheme, .light)
    }
}

/// Traits de coupe aux coins et repères de pliage, hors du fond perdu.
struct Reperes: View {
    let x: CGFloat, y: CGFloat, largeur: CGFloat, hauteur: CGFloat
    let plis: [Double]
    let u: CGFloat
    var body: some View {
        let e = Export.perdu + 1, l: CGFloat = 5
        ZStack(alignment: .topLeading) {
            Path { p in
                for xx in [x, x + largeur] {
                    p.move(to: CGPoint(x: xx * u, y: (y - e - l) * u)); p.addLine(to: CGPoint(x: xx * u, y: (y - e) * u))
                    p.move(to: CGPoint(x: xx * u, y: (y + hauteur + e) * u)); p.addLine(to: CGPoint(x: xx * u, y: (y + hauteur + e + l) * u))
                }
                for yy in [y, y + hauteur] {
                    p.move(to: CGPoint(x: (x - e - l) * u, y: yy * u)); p.addLine(to: CGPoint(x: (x - e) * u, y: yy * u))
                    p.move(to: CGPoint(x: (x + largeur + e) * u, y: yy * u)); p.addLine(to: CGPoint(x: (x + largeur + e + l) * u, y: yy * u))
                }
            }
            .stroke(Color.black, lineWidth: 0.25)
            Path { p in
                for f in plis {
                    let xx = x + f
                    p.move(to: CGPoint(x: xx * u, y: (y - e - l) * u)); p.addLine(to: CGPoint(x: xx * u, y: (y - e) * u))
                    p.move(to: CGPoint(x: xx * u, y: (y + hauteur + e) * u)); p.addLine(to: CGPoint(x: xx * u, y: (y + hauteur + e + l) * u))
                }
            }
            .stroke(Color.black, style: StrokeStyle(lineWidth: 0.25, dash: [1.5, 1.5]))
        }
    }
}

/// Une règle graduée : `longueur` en mm, `pas` = plus petite graduation (mm), étiquettes tous les `tous` pas.
struct Regle: View {
    let longueur: CGFloat
    let pas: CGFloat
    let tous: Int
    let moitie: Int
    let unite: String
    var verticale = false
    let u: CGFloat
    var body: some View {
        let n = Int((longueur / pas).rounded())
        ZStack(alignment: .topLeading) {
            Path { p in
                p.move(to: .zero)
                p.addLine(to: verticale ? CGPoint(x: 0, y: longueur * u) : CGPoint(x: longueur * u, y: 0))
                for i in 0...n {
                    let l: CGFloat = i % tous == 0 ? 6 : (i % moitie == 0 ? 4 : 2.2)
                    let t = CGFloat(i) * pas * u
                    if verticale { p.move(to: CGPoint(x: 0, y: t)); p.addLine(to: CGPoint(x: l * u, y: t)) }
                    else { p.move(to: CGPoint(x: t, y: 0)); p.addLine(to: CGPoint(x: t, y: l * u)) }
                }
            }
            .stroke(Color.black, lineWidth: 0.35)
            ForEach(0...(n / tous), id: \.self) { k in
                Text(k == n / tous ? "\(k) \(unite)" : "\(k)").font(.system(size: 7)).fixedSize()
                    .offset(x: verticale ? 7 * u : CGFloat(k * tous) * pas * u - 2, y: verticale ? CGFloat(k * tous) * pas * u - 4 : 6.5 * u)
            }
        }
    }
}

/// Page de calibrage : on mesure les règles et les repères au réglet, on entre les valeurs dans Réglages → Impression.
struct PageCalibrage: View {
    var papier: Papier = .a4
    private let u = Typo.ptParMM
    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Color.white)
            // Repères de décalage : à 15 mm du bord gauche et du bord haut.
            Path { p in
                p.move(to: CGPoint(x: 15 * u, y: 8 * u)); p.addLine(to: CGPoint(x: 15 * u, y: 28 * u))
                p.move(to: CGPoint(x: 8 * u, y: 15 * u)); p.addLine(to: CGPoint(x: 28 * u, y: 15 * u))
            }
            .stroke(Color.red, lineWidth: 0.5)
            Text("A").font(.system(size: 8, weight: .bold)).foregroundStyle(.red).offset(x: 16.5 * u, y: 20 * u)
            // Règles horizontales : 15 cm et 6 pouces.
            Text("Règle horizontale en cm (15 cm)").font(.system(size: 8, weight: .bold)).offset(x: 40 * u, y: 24 * u)
            Regle(longueur: 150, pas: 1, tous: 10, moitie: 5, unite: "cm", u: u).offset(x: 40 * u, y: 30 * u)
            Text("Règle horizontale en pouces (6 in)").font(.system(size: 8, weight: .bold)).offset(x: 40 * u, y: 46 * u)
            Regle(longueur: 152.4, pas: 25.4 / 8, tous: 8, moitie: 4, unite: "in", u: u).offset(x: 40 * u, y: 52 * u)
            // Règles verticales : 20 cm et 8 pouces.
            Regle(longueur: 200, pas: 1, tous: 10, moitie: 5, unite: "cm", verticale: true, u: u).offset(x: 22 * u, y: 70 * u)
            Regle(longueur: 203.2, pas: 25.4 / 8, tous: 8, moitie: 4, unite: "in", verticale: true, u: u).offset(x: 42 * u, y: 70 * u)
            // Carré de 10 cm pour un contrôle d'un coup d'œil.
            Rectangle().stroke(Color.black, lineWidth: 0.5).frame(width: 100 * u, height: 100 * u).offset(x: 90 * u, y: 150 * u)
            Text("Carré de 10 cm × 10 cm (3,94 in)").font(.system(size: 8)).frame(width: 100 * u).offset(x: 90 * u, y: 196 * u)
            VStack(alignment: .leading, spacing: 5) {
                Text("LaFleurStudio · page de calibrage (\(papier.nom))").font(.system(size: 12, weight: .bold))
                Text("Imprime cette page à 100 % (jamais « ajuster à la page »), puis mesure avec une règle :")
                Text("1. La longueur réelle de la règle horizontale (15 cm ou 6 in).")
                Text("2. La longueur réelle de la règle verticale (20 cm ou 8 in).")
                Text("3. La distance entre le bord gauche de la feuille et le trait rouge vertical A (15 mm si tout est parfait).")
                Text("4. La distance entre le bord haut de la feuille et le trait rouge horizontal A (15 mm si tout est parfait).")
                Text("Entre les mesures dans Réglages → Impression. L'app corrige ensuite l'échelle et le décalage de toutes tes impressions.")
            }
            .font(.system(size: 8.5)).frame(width: 125 * u, alignment: .leading).offset(x: 70 * u, y: 72 * u)
        }
        .frame(width: papier.largeur * u, height: papier.hauteur * u, alignment: .topLeading)
        .environment(\.colorScheme, .light)
    }
}
