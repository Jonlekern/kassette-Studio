import AppKit
import LaFleurCore
import SwiftUI

/// `LaFleurStudio --captures <dossier>` : photographie chaque écran et chaque format de jaquette avec une
/// cassette d'exemple, puis quitte. Sert à vérifier le rendu sur la CI sans toucher aux vraies cassettes.
@MainActor
enum Captures {
    static func lancer(_ dossier: URL) async {
        try? FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("lafleurstudio-captures-\(UUID().uuidString)")
        let etat = EtatApp(stockage: Stockage(racine: tmp))
        etat.prefs.conditionsAcceptees = true
        etat.projet = demo(pochette: pochette(dans: tmp))
        let moteur = MoteurEnregistrement()
        await etat.prechargerImages()

        var journal: [String] = []
        func ecran(_ nom: String, _ e: Ecran) async {
            await capturer(FenetrePrincipale(ecranInitial: e).padding(16).background(W98.bureau).w98()
                            .environmentObject(etat).environmentObject(moteur).preferredColorScheme(.light),
                           CGSize(width: 1280, height: 800), dossier.appendingPathComponent(nom))
        }
        await ecran("ecran-1-mixtape.png", .mixtape)
        await ecran("ecran-2-jaquette.png", .jaquette)
        await ecran("ecran-3-enregistrer.png", .enregistrer)
        await ecran("ecran-4-collection.png", .collection)
        await capturer(Apercu3D(mise: etat.mise) {}.environmentObject(etat), CGSize(width: 560, height: 560),
                       dossier.appendingPathComponent("apercu-3d.png"))
        await capturer(CassetteDessin(projet: etat.projet, face: .a, tourne: false, progression: 0.3).padding(8).background(Color(white: 0.12)),
                       CGSize(width: 300, height: 196), dossier.appendingPathComponent("platine-cassette.png"))

        // Chaque format, à plat, comme à l'impression (300 DPI).
        await etat.prechargerImages()
        for p in Export.pages(etat.mise) {
            let nom = "format-" + p.nom.components(separatedBy: " (").first!.replacingOccurrences(of: " · ", with: "-")
                .replacingOccurrences(of: " ", with: "-").lowercased() + ".png"
            if let d = Export.png(p.vue, dpi: 300) { try? d.write(to: dossier.appendingPathComponent(nom)) }
        }
        let pdf = Export.pdf(Export.pages(etat.mise), mise: etat.mise, decalageX: 0, decalageY: 0)
        try? pdf.write(to: dossier.appendingPathComponent("jaquette.pdf"))
        try? Export.calibrage().write(to: dossier.appendingPathComponent("calibrage.pdf"))
        if let d = Export.planchePourClaude(etat.mise) { try? d.write(to: dossier.appendingPathComponent("planche-pour-claude.png")) }

        // Les 5 styles de recto, sur une mixtape avec des covers différentes.
        var mix = etat.projet
        mix.mode = .mixtape; mix.titre = "Summer Drive"; mix.artiste = ""
        let couleurs: [(Double, Double, Double)] = [(0.9, 0.3, 0.3), (0.2, 0.6, 0.4), (0.95, 0.8, 0.2), (0.3, 0.3, 0.8)]
        for (i, c) in couleurs.enumerated() {
            let u = cover(dans: tmp, i, c)
            if i < mix.faceA.count { mix.faceA[i].morceau.pochetteURL = u }
            if i < mix.faceB.count { mix.faceB[i].morceau.pochetteURL = u }
        }
        for i in mix.faceA.indices { mix.faceA[i].morceau.pochetteURL = mix.faceA[i % 4].morceau.pochetteURL }
        for i in mix.faceB.indices { mix.faceB[i].morceau.pochetteURL = mix.faceB[i % 4].morceau.pochetteURL }
        await Images.partage.precharger(mix.toutes.map(\.morceau.pochetteURL))
        let graphique = [
            ElementGraphique(forme: .cercle, x: 0.15, y: 0.1, largeur: 0.7, hauteur: 0.7, couleur: "#F2C14E"),
            ElementGraphique(forme: .rectangle, x: 0, y: 0.62, largeur: 1, hauteur: 0.06, couleur: "#F78154"),
            ElementGraphique(forme: .rectangle, x: 0, y: 0.72, largeur: 1, hauteur: 0.04, couleur: "#F78154", opacite: 0.7),
            ElementGraphique(forme: .rectangle, x: 0, y: 0.8, largeur: 1, hauteur: 0.02, couleur: "#F78154", opacite: 0.5),
            ElementGraphique(forme: .triangle, x: 0.55, y: 0.35, largeur: 0.4, hauteur: 0.3, couleur: "#4D9078"),
            ElementGraphique(forme: .texte, x: 0.06, y: 0.86, largeur: 0.9, hauteur: 0.1, couleur: "#FFFFFF", texte: "SIDE A · SIDE B"),
        ]
        let styles: [(StyleRecto, String, String)] = [(.pochette, "Cormorant Garamond", "#14283A"), (.collage, "Bebas Neue", "#111111"),
                                                      (.imagePerso, "Playfair Display", "#1D1D1D"), (.maison, "Permanent Marker", "#EFE6D2"),
                                                      (.graphique, "Syne", "#2B2D42")]
        let mixFixe = mix
        let demoFixe = etat.projet
        let rectos = HStack(alignment: .top, spacing: 6 * Typo.ptParMM) {
            ForEach(styles.indices, id: \.self) { i in
                let sty = styles[i]
                let st = sty.0, police = sty.1, fond = sty.2
                let dm: Design = {
                    var d = Design()
                    d.variante = Variante(nom: "\(i)", palette: Palette(fond: fond, texte: st == .maison ? "#1B1B1B" : "#F4F1EA", accent: "#F78154"),
                                          policeTitre: police, policeTexte: "Space Mono", titreItalique: st == .pochette, style: st,
                                          elements: st == .graphique ? graphique : [])
                    d.imagePerso = st == .imagePerso ? mixFixe.faceA[2].morceau.pochetteURL : nil
                    return d
                }()
                VStack(spacing: 2) {
                    Text(st.nom).font(.system(size: 9))
                    RectoVue(mise: Mise(projet: st == .pochette ? demoFixe : mixFixe, design: dm), largeur: Gabarits.recto,
                             hauteur: Gabarits.hauteurJ, u: Typo.ptParMM)
                }
            }
        }
        .padding(10).background(Color.white)
        if let data = Export.png(rectos, dpi: 200) { try? data.write(to: dossier.appendingPathComponent("styles-recto.png")) }

        // Artwork en paysage.
        var dp = etat.design; dp.orientation = .paysage; etat.design = dp
        if let data = Export.png(JCardVue(mise: etat.mise, perdu: 3, u: Typo.ptParMM), dpi: 300) {
            try? data.write(to: dossier.appendingPathComponent("format-j-card-paysage.png"))
        }
        // Cadrage pleine hauteur, vertical puis paysage (code-barres couché dans le rabat).
        dp.cadrage = .pleineHauteur; etat.design = dp
        if let data = Export.png(JCardVue(mise: etat.mise, perdu: 3, u: Typo.ptParMM), dpi: 300) {
            try? data.write(to: dossier.appendingPathComponent("format-j-card-pleine-paysage.png"))
        }
        dp.orientation = .vertical; etat.design = dp
        if let data = Export.png(JCardVue(mise: etat.mise, perdu: 3, u: Typo.ptParMM), dpi: 300) {
            try? data.write(to: dossier.appendingPathComponent("format-j-card-pleine.png"))
        }
        dp.cadrage = .carre; etat.design = dp

        // Même cassette avec 3 volets (verso) et un texte de tranche trop long : les alertes doivent le voir.
        var d = etat.design
        d.volets = 3; d.texteTranche = "JEREMY SADIK · AN AFTERNOON AT THE LAKE · THE COMPLETE EDITION"
        etat.design = d
        for p in Export.pages(etat.mise) where p.nom.contains("J-card") {
            let nom = "format-3volets-" + (p.nom.contains("verso") ? "verso" : "exterieur") + ".png"
            if let data = Export.png(p.vue, dpi: 300) { try? data.write(to: dossier.appendingPathComponent(nom)) }
        }
        journal.append("Alertes avec le texte de tranche trop long :")
        journal += etat.alertes.map { "- [\($0.gravite.rawValue)] \($0.message)" }
        etat.toutCorriger()
        journal.append("Après « Tout corriger » : \(etat.alertes.count) alerte(s), échelles \(etat.design.echelles)")
        journal += etat.alertes.map { "- [\($0.gravite.rawValue)] \($0.message)" }
        if let data = Export.png(JCardVue(mise: etat.mise, perdu: 3, u: Typo.ptParMM), dpi: 300) {
            try? data.write(to: dossier.appendingPathComponent("format-3volets-corrige.png"))
        }
        // Recherche réelle sur Wikimedia Commons, comme quand Claude demande un logo.
        let commons = (try? await Commons.chercher("Sony logo")) ?? []
        journal.append("Commons « Sony logo » : \(commons.count) résultat(s)" + (commons.first.map { " · premier : \($0.titre) (\($0.licence))" } ?? ""))
        if let premier = commons.first {
            var dl = etat.design
            await Images.partage.charger(premier.image)
            dl.imagesPosees = [ImagePosee(url: premier.image, source: premier.titre, x: 0.6, y: 0.05, largeur: 0.35, hauteur: 0.12)]
            etat.design = dl
            if let data = Export.png(RectoVue(mise: etat.mise, largeur: Gabarits.recto, hauteur: Gabarits.hauteurJ, u: Typo.ptParMM), dpi: 300) {
                try? data.write(to: dossier.appendingPathComponent("recto-avec-logo.png"))
            }
            dl.imagesPosees = []; etat.design = dl
        }
        journal.append("Plan de la cassette envoyé à Claude :\n" + etat.mise.anatomie())
        journal.append("Polices disponibles : " + Typo.disponibles.joined(separator: ", "))
        try? journal.joined(separator: "\n").write(to: dossier.appendingPathComponent("journal.txt"), atomically: true, encoding: .utf8)
        try? FileManager.default.removeItem(at: tmp)
    }

    /// Rend une vue AppKit/SwiftUI complète (champs, listes…) dans une fenêtre hors écran.
    static func capturer(_ vue: some View, _ taille: CGSize, _ url: URL) async {
        let h = NSHostingView(rootView: vue.frame(width: taille.width, height: taille.height))
        h.frame = CGRect(origin: .zero, size: taille)
        let w = NSWindow(contentRect: h.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        w.contentView = h
        w.orderFrontRegardless()
        h.layoutSubtreeIfNeeded()
        try? await Task.sleep(for: .milliseconds(1200))
        h.layoutSubtreeIfNeeded()
        if let rep = h.bitmapImageRepForCachingDisplay(in: h.bounds) {
            h.cacheDisplay(in: h.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
        }
        w.orderOut(nil)
    }

    /// Pochette de démonstration : un lac au coucher du soleil, dessiné (pas d'accès réseau nécessaire).
    static func pochette(dans dossier: URL) -> URL {
        try? FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        let url = dossier.appendingPathComponent("pochette-demo.png")
        let n = 600
        guard let ctx = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return url }
        let ciel = CGGradient(colorsSpace: nil, colors: [CGColor(srgbRed: 0.95, green: 0.72, blue: 0.55, alpha: 1),
                                                          CGColor(srgbRed: 0.35, green: 0.45, blue: 0.62, alpha: 1)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(ciel, start: CGPoint(x: 0, y: CGFloat(n) * 0.45), end: CGPoint(x: 0, y: CGFloat(n)), options: [])
        ctx.setFillColor(CGColor(srgbRed: 1, green: 0.85, blue: 0.6, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: 380, y: 300, width: 90, height: 90))
        let lac = CGGradient(colorsSpace: nil, colors: [CGColor(srgbRed: 0.08, green: 0.16, blue: 0.23, alpha: 1),
                                                         CGColor(srgbRed: 0.18, green: 0.37, blue: 0.46, alpha: 1)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(lac, start: .zero, end: CGPoint(x: 0, y: CGFloat(n) * 0.45), options: [])
        ctx.setFillColor(CGColor(srgbRed: 0.06, green: 0.12, blue: 0.1, alpha: 1))
        ctx.move(to: CGPoint(x: 0, y: 270)); ctx.addLine(to: CGPoint(x: 140, y: 330)); ctx.addLine(to: CGPoint(x: 260, y: 285))
        ctx.addLine(to: CGPoint(x: 600, y: 300)); ctx.addLine(to: CGPoint(x: 600, y: 265)); ctx.addLine(to: CGPoint(x: 0, y: 265)); ctx.fillPath()
        if let img = ctx.makeImage() { try? NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:])?.write(to: url) }
        return url
    }

    /// Cover de démonstration : un aplat de couleur avec un rond.
    static func cover(dans dossier: URL, _ i: Int, _ c: (Double, Double, Double)) -> URL {
        let url = dossier.appendingPathComponent("cover-\(i).png")
        let n = 300
        guard let ctx = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return url }
        ctx.setFillColor(CGColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: n, height: n))
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.35)); ctx.fillEllipse(in: CGRect(x: 60 + i * 20, y: 80, width: 150, height: 150))
        if let img = ctx.makeImage() { try? NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:])?.write(to: url) }
        return url
    }

    static func demo(pochette: URL) -> Projet {
        var p = Projet(numeroCatalogue: "LFS-001")
        p.titre = "An Afternoon at the Lake"
        p.artiste = "Jeremy Sadik"
        p.annee = "2024"
        p.spotifyAlbumID = "6RUvESEU9esRjOKBMAdXHp"
        p.pochetteURL = pochette
        p.cassette.longueur = .c60; p.cassette.bande = .typeII; p.cassette.reducteur = .dolbyB; p.cassette.marque = "TDK SA60"
        let a: [(String, Int)] = [("Sun Cream at the Lake", 212), ("The Muse", 187), ("Pre-Packaged Sandwich", 164),
                                  ("After Rain", 241), ("Glad to Know You", 198), ("Glass", 226)]
        let b: [(String, Int)] = [("Mushroom Forest", 205), ("Parked in the Front of the Mall", 233), ("Seeking Adventure", 176),
                                  ("The Guy from Paris", 219), ("Clouds in Budapest", 251), ("Unknown Number", 190)]
        func pistes(_ l: [(String, Int)], _ debut: Int) -> [Piste] {
            l.enumerated().map { e in
                Piste(morceau: Morceau(titre: e.element.0, artistes: ["Jeremy Sadik"], album: "An Afternoon at the Lake", dateSortie: "2024",
                                       dureeMs: e.element.1 * 1000, numeroPiste: debut + e.offset, pochetteURL: pochette))
            }
        }
        p.faceA = pistes(a, 1); p.faceB = pistes(b, 7)
        var d = Design()
        d.volets = 4
        d.ocard = true; d.obi = true
        d.qr = true; d.codeSpotify = true
        d.notes = "Un après-midi au bord du lac, enregistré sur une TDK SA60. Face A pour la lumière, face B pour le retour."
        d.credits = "Écrit, joué et produit par Jeremy Sadik.\nCassette LAFLEURSTUDIO LFS-001."
        d.obiTexte = "AN AFTERNOON AT THE LAKE"
        p.design = d
        return p
    }
}
