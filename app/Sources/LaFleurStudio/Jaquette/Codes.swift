import LaFleurCore
import SwiftUI

/// Code-barres dessiné en vectoriel : barres, chiffres liés au numéro, zones blanches.
struct CodeBarresVue: View {
    let code: CodeBarres1D
    /// Largeur d'un module (mm).
    let module: CGFloat
    /// Hauteur des barres (mm), chiffres non compris.
    let hauteur: CGFloat
    let barres: Color
    let fond: Color
    var chiffres = true
    let u: CGFloat

    static let marge = 10
    var tailleChiffres: CGFloat { module * 8.5 }
    var largeurTotale: CGFloat { CGFloat(code.modules.count + 2 * Self.marge) * module }
    var hauteurTotale: CGFloat { hauteur + (chiffres ? tailleChiffres * 1.1 : 0) + module * 2 }

    var body: some View {
        let m = module * u, x0 = CGFloat(Self.marge) * m, h = hauteur * u
        let depasse = chiffres ? tailleChiffres * 0.55 * u : 0
        ZStack(alignment: .topLeading) {
            Rectangle().fill(fond)
            Path { p in
                var i = 0
                let n = code.modules.count
                while i < n {
                    guard code.modules[i] else { i += 1; continue }
                    var j = i
                    while j < n && code.modules[j] && code.longues[j] == code.longues[i] { j += 1 }
                    let hh = h + (code.longues[i] ? depasse : 0)
                    p.addRect(CGRect(x: x0 + CGFloat(i) * m, y: module * u, width: CGFloat(j - i) * m, height: hh))
                    i = j
                }
            }
            .fill(barres)
            if chiffres {
                ForEach(code.groupes.indices, id: \.self) { g in
                    let gr = code.groupes[g]
                    let centre = x0 + CGFloat(gr.debut + gr.fin) / 2 * m
                    Text(gr.texte)
                        .font(Typo.font(code.genre == .code128 ? "Menlo" : "Helvetica Neue", tailleChiffres * u))
                        .kerning(code.genre == .code128 ? 0 : module * 1.6 * u)
                        .foregroundStyle(barres)
                        .fixedSize()
                        .frame(width: 0, alignment: .center)
                        .offset(x: centre, y: (module + hauteur) * u)
                }
            }
        }
        .frame(width: largeurTotale * u, height: hauteurTotale * u, alignment: .topLeading)
        .accessibilityLabel("Code-barres \(code.genre.nom) \(code.numero)")
    }
}

/// QR code dessiné en vectoriel, avec sa zone blanche de 2 modules.
struct QRVue: View {
    let modules: [[Bool]]
    /// Côté total (mm), marge comprise.
    let cote: CGFloat
    let barres: Color
    let fond: Color
    let u: CGFloat
    var body: some View {
        let n = CGFloat(modules.count + 4)
        let m = cote * u / n
        ZStack(alignment: .topLeading) {
            Rectangle().fill(fond)
            Path { p in
                for (y, ligne) in modules.enumerated() {
                    for (x, noir) in ligne.enumerated() where noir {
                        p.addRect(CGRect(x: CGFloat(x + 2) * m, y: CGFloat(y + 2) * m, width: m, height: m))
                    }
                }
            }
            .fill(barres)
        }
        .frame(width: cote * u, height: cote * u)
        .accessibilityLabel("QR code")
    }
}

/// Les codes cochés (QR, code Spotify, code-barres), empilés, pour une zone de largeur donnée.
struct PileCodes: View {
    let mise: Mise
    let largeur: CGFloat
    let u: CGFloat
    var avecQR = true
    var avecBarres = true

    var body: some View {
        let d = mise.design
        let (b, f) = mise.couleursCode
        VStack(spacing: 1.2 * u) {
            if avecQR && d.qr, let m = CodeQR.modules(mise.contenuQR) {
                QRVue(modules: m, cote: min(largeur, 15), barres: Color(hex: b), fond: Color(hex: f), u: u)
            }
            if avecBarres && d.codeSpotify, let url = mise.urlCodeSpotify {
                ImageCache(url: url, remplir: false).frame(width: largeur * u, height: largeur / 4 * u)
            }
            if avecBarres && d.codeBarres, let c = CodesBarres.generer(d.genreCode, mise.numeroCode) {
                VStack(spacing: 0.4 * u) {
                    TexteMM(spec: mise.texteCodeSpec(largeur: largeur), u: u)
                    let m = mise.largeurModule(c)
                    CodeBarresVue(code: c, module: m, hauteur: min(12, 42 * m), barres: Color(hex: b), fond: Color(hex: f),
                                  chiffres: d.chiffresCode, u: u)
                }
            }
        }
    }
}
