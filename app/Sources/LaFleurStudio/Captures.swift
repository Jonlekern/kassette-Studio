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
