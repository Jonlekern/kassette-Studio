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
    static func pdf(_ pages: [PageExport], mise: Mise, decalageX: CGFloat, decalageY: CGFloat) -> Data {
        let data = NSMutableData()
        var boite = CGRect(x: 0, y: 0, width: 210 * u, height: 297 * u)
        guard let conso = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: conso, mediaBox: &boite, [kCGPDFContextCreator: "LaFleurStudio"] as CFDictionary) else { return Data() }
        for p in pages {
            var b = CGRect(x: 0, y: 0, width: p.papier.largeur * u, height: p.papier.hauteur * u)
            ctx.beginPage(mediaBox: &b)
            let r = ImageRenderer(content: PageVue(page: p, mise: mise, decalageX: p.verso ? -decalageX : decalageX, decalageY: decalageY))
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

    /// Page de calibrage : règles et carré de 100 mm pour mesurer le décalage de l'imprimante.
    static func calibrage() -> Data {
        let vue = PageCalibrage()
        let data = NSMutableData()
        var b = CGRect(x: 0, y: 0, width: 210 * u, height: 297 * u)
        guard let conso = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: conso, mediaBox: &b, nil) else { return Data() }
        ctx.beginPage(mediaBox: &b)
        let r = ImageRenderer(content: vue)
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

/// Page A4 de calibrage : on mesure où tombent les repères pour corriger le décalage de l'imprimante.
struct PageCalibrage: View {
    private let u = Typo.ptParMM
    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Color.white)
            // Carré de 100 mm : sert à vérifier l'échelle (imprimé à 100 %, il mesure exactement 100 mm).
            Rectangle().stroke(Color.black, lineWidth: 0.5).frame(width: 100 * u, height: 100 * u).offset(x: 55 * u, y: 98.5 * u)
            Text("Ce carré doit mesurer exactement 100 mm de côté.\nSinon l'impression n'est pas à 100 % : corrige le réglage de l'imprimante.")
                .font(.system(size: 9)).multilineTextAlignment(.center).frame(width: 100 * u).offset(x: 55 * u, y: 140 * u)
            // Repère vertical à 20 mm du bord gauche, repère horizontal à 20 mm du bord haut.
            Path { p in
                p.move(to: CGPoint(x: 20 * u, y: 30 * u)); p.addLine(to: CGPoint(x: 20 * u, y: 267 * u))
                p.move(to: CGPoint(x: 30 * u, y: 20 * u)); p.addLine(to: CGPoint(x: 180 * u, y: 20 * u))
            }
            .stroke(Color.red, lineWidth: 0.5)
            // Règles graduées en mm depuis ces repères.
            Path { p in
                for i in 0...150 {
                    let l: CGFloat = i % 10 == 0 ? 5 : (i % 5 == 0 ? 3.5 : 2)
                    p.move(to: CGPoint(x: (30 + CGFloat(i)) * u, y: 20 * u)); p.addLine(to: CGPoint(x: (30 + CGFloat(i)) * u, y: (20 + l) * u))
                }
                for i in 0...230 {
                    let l: CGFloat = i % 10 == 0 ? 5 : (i % 5 == 0 ? 3.5 : 2)
                    p.move(to: CGPoint(x: 20 * u, y: (30 + CGFloat(i)) * u)); p.addLine(to: CGPoint(x: (20 + l) * u, y: (30 + CGFloat(i)) * u))
                }
            }
            .stroke(Color.black, lineWidth: 0.3)
            VStack(alignment: .leading, spacing: 4) {
                Text("LaFleurStudio · page de calibrage").font(.system(size: 12, weight: .bold))
                Text("1. Mesure la distance entre le bord GAUCHE de la feuille et la ligne rouge verticale (normalement 20 mm).")
                Text("2. Mesure la distance entre le bord HAUT de la feuille et la ligne rouge horizontale (normalement 20 mm).")
                Text("3. Entre ces deux mesures dans Réglages → Impression : l'app corrige ensuite toutes tes impressions.")
            }
            .font(.system(size: 9)).frame(width: 150 * u, alignment: .leading).offset(x: 30 * u, y: 32 * u)
        }
        .frame(width: 210 * u, height: 297 * u, alignment: .topLeading)
        .environment(\.colorScheme, .light)
    }
}
