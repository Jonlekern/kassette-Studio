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
              let ctx = CGContext(consumer: conso, mediaBox: &boite, [kCGPDFContextCreator: "STUDIOLAFLEUR"] as CFDictionary) else { return Data() }
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

    static func imprimer(_ data: Data, titre: String, imprimante: String? = nil) {
        guard let doc = PDFDocument(data: data) else { return }
        let info = (NSPrintInfo.shared.copy() as? NSPrintInfo) ?? NSPrintInfo()
        if let nom = imprimante, let p = NSPrinter(name: nom) { info.printer = p }
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
                Text("STUDIOLAFLEUR · \(mise.projet.numeroCatalogue) · \(page.nom)")
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

/// Page de calibrage : une règle de 10 cm et une de 4 pouces (dans les deux sens), à mesurer avec une vraie règle.
struct PageCalibrage: View {
    var papier: Papier = .a4
    private let u = Typo.ptParMM
    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Color.white)
            VStack(alignment: .leading, spacing: 5) {
                Text("STUDIOLAFLEUR · règle de calibrage (\(papier.nom))").font(.system(size: 14, weight: .bold))
                Text("Imprime à 100 %, pas « Ajuster à la page ».").font(.system(size: 11, weight: .bold)).foregroundStyle(.red)
                Text("Mesure la règle de 10 cm (ou celle de 4 pouces) avec une vraie règle, puis tape la valeur dans")
                Text("STUDIOLAFLEUR → Réglages → Impression. C'est tout : l'app corrige toutes tes impressions.")
            }
            .font(.system(size: 10)).offset(x: 25 * u, y: 20 * u)

            Text("Règle de 10 cm").font(.system(size: 9, weight: .bold)).offset(x: 25 * u, y: 52 * u)
            Regle(longueur: 100, pas: 1, tous: 10, moitie: 5, unite: "cm", u: u).offset(x: 25 * u, y: 58 * u)
            Text("Règle de 4 pouces").font(.system(size: 9, weight: .bold)).offset(x: 25 * u, y: 78 * u)
            Regle(longueur: 101.6, pas: 25.4 / 8, tous: 8, moitie: 4, unite: "in", u: u).offset(x: 25 * u, y: 84 * u)

            Text("En option, les mêmes règles à la verticale (si ton imprimante n'a pas la même erreur dans les deux sens) :")
                .font(.system(size: 9)).frame(width: 160 * u, alignment: .leading).offset(x: 25 * u, y: 106 * u)
            Regle(longueur: 100, pas: 1, tous: 10, moitie: 5, unite: "cm", verticale: true, u: u).offset(x: 30 * u, y: 118 * u)
            Regle(longueur: 101.6, pas: 25.4 / 8, tous: 8, moitie: 4, unite: "in", verticale: true, u: u).offset(x: 60 * u, y: 118 * u)

            // Repères de décalage (option) : à 15 mm du bord gauche et du bord haut.
            Path { p in
                p.move(to: CGPoint(x: 15 * u, y: 8 * u)); p.addLine(to: CGPoint(x: 15 * u, y: 16 * u))
                p.move(to: CGPoint(x: 8 * u, y: 15 * u)); p.addLine(to: CGPoint(x: 16 * u, y: 15 * u))
            }
            .stroke(Color.red, lineWidth: 0.5)
            Text("Option : les traits rouges sont à 15 mm du bord gauche et du bord haut. S'ils sont décalés, note de combien.")
                .font(.system(size: 8)).foregroundStyle(Color.gray).frame(width: 100 * u, alignment: .leading).offset(x: 90 * u, y: 125 * u)
        }
        .frame(width: papier.largeur * u, height: papier.hauteur * u, alignment: .topLeading)
        .environment(\.colorScheme, .light)
    }
}
