import AVFoundation
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
        // La cassette d'exemple est enregistrée avant le démarrage : la Collection n'a pas de cassette vide en plus.
        let stockage = Stockage(racine: tmp)
        var prefs = stockage.preferences()
        prefs.conditionsAcceptees = true
        prefs.prochainNumero = 2
        try? stockage.enregistrer(prefs)
        try? stockage.enregistrer(demo(pochette: pochette(dans: tmp)))
        let etat = EtatApp(stockage: stockage)
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
        // Étiquettes « pochette en fond » et jaquette retouchée (titre agrandi et déplacé, pochette de l'étiquette masquée).
        var dr = etat.design
        dr.etiquettePochette = .fond; dr.voileEtiquette = 0.4
        dr.echelles["titre"] = 1.3
        var aj = Ajustement(); aj.dy = -4; aj.couleur = "#F2C14E"
        dr.ajustements["recto-titre"] = aj
        let sauvegarde = etat.design
        etat.design = dr
        if let data = Export.png(VStack(spacing: 18) { EtiquetteVue(mise: etat.mise, face: .a, u: Typo.ptParMM); EtiquetteVue(mise: etat.mise, face: .b, u: Typo.ptParMM) }
                                    .padding(10).background(Color.white), dpi: 300) {
            try? data.write(to: dossier.appendingPathComponent("etiquettes-pochette-en-fond.png"))
        }
        etat.elementSelectionne = "recto-titre"
        await capturer(JCardVue(mise: etat.mise, guides: true, u: 4).environment(\.editionJaquette, etat.edition).padding(12).background(W98.grisFonce),
                       CGSize(width: 900, height: 470), dossier.appendingPathComponent("jaquette-element-selectionne.png"))
        etat.elementSelectionne = nil
        etat.design = sauvegarde
        for r in ["Audio", "IA"] {
            await capturer(Reglages(rubrique: r).environmentObject(etat).environmentObject(moteur), CGSize(width: 760, height: 560),
                           dossier.appendingPathComponent("reglages-\(r.lowercased()).png"))
        }
        await capturer(Apercu3D(mise: etat.mise) {}.environmentObject(etat), CGSize(width: 560, height: 560),
                       dossier.appendingPathComponent("apercu-3d.png"))
        if let img = Boitier3D.image(etat.mise, taille: CGSize(width: 600, height: 600)), let t = img.tiffRepresentation,
           let png = NSBitmapImageRep(data: t)?.representation(using: .png, properties: [:]) {
            try? png.write(to: dossier.appendingPathComponent("boitier-3d.png"))
        }
        await capturer(CassetteDessin(projet: etat.projet, face: .a, tourne: false, progression: 0.3).padding(8).background(W98.gris),
                       CGSize(width: 300, height: 196), dossier.appendingPathComponent("platine-cassette.png"))
        // Les 4 couleurs de coque, sur le gris de l'écran.
        let coques = HStack(spacing: 10) {
            ForEach(CouleurCoque.allCases, id: \.self) { c in
                CassetteDessin(projet: Self.avecCoque(etat.projet, c), face: .a, tourne: false, progression: 0.3)
            }
        }
        .padding(10).background(W98.gris)
        await capturer(coques, CGSize(width: 4 * 281 + 50, height: 199), dossier.appendingPathComponent("coques.png"))

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
        // Colonnes longues (réponses de l'IA, fil, panneau Élément) : elles doivent défiler à la molette, et Exporter rester visible.
        let long = "Je pars de ta pochette : bleu nuit, papier crème, titre en Cormorant italique. La tranche reprend l'accent et le badge Type II reste discret en haut du rabat."
        etat.conversation = (0..<6).map { MessageDesign(deClaude: $0 % 2 == 1, texte: long) }
        etat.filModif = (0..<10).map { MessageModif(deIA: $0 % 2 == 1, texte: long, changements: $0 % 2 == 1 ? ["echelles.titre : 1 → 1.3"] : []) }
        etat.elementSelectionne = "recto-titre"
        journal += await testerDefilement(FenetrePrincipale(ecranInitial: .jaquette).padding(16).background(W98.bureau).w98()
                                            .environmentObject(etat).environmentObject(moteur).preferredColorScheme(.light),
                                          CGSize(width: 1180, height: 760), dossier, "defilement-jaquette")
        journal += await testerDefilement(FenetrePrincipale(ecranInitial: .jaquette).padding(16).background(W98.bureau).w98()
                                            .environmentObject(etat).environmentObject(moteur).preferredColorScheme(.light),
                                          CGSize(width: 1920, height: 1050), dossier, "defilement-jaquette-plein-ecran")
        etat.prefs.modeExpertIA = true
        journal += await testerDefilement(FenetrePrincipale(ecranInitial: .mixtape).padding(16).background(W98.bureau).w98()
                                            .environmentObject(etat).environmentObject(moteur).preferredColorScheme(.light),
                                          CGSize(width: 1180, height: 760), dossier, "defilement-mixtape")
        etat.prefs.modeExpertIA = false
        etat.conversation = []; etat.filModif = []; etat.elementSelectionne = nil

        // Glisser-déposer d'une face à l'autre : la dernière de la face A va avant la 2e de la face B, puis à la fin de la face A.
        let sauvegardeProjet = etat.projet
        if let glass = etat.projet.faceA.last, etat.projet.faceB.count > 1 {
            let cible = etat.projet.faceB[1]
            etat.deplacer(glass.id, avant: cible.id, face: .b)
            let ok1 = etat.projet.faceB.firstIndex { $0.id == glass.id } == 1 && !etat.projet.faceA.contains { $0.id == glass.id }
            etat.deplacer(glass.id, avant: nil, face: .a)
            let ok2 = etat.projet.faceA.last?.id == glass.id && !etat.projet.faceB.contains { $0.id == glass.id }
            journal.append("Glisser vers l'autre face : « \(glass.morceau.titre) » avant « \(cible.morceau.titre) » en face B \(ok1 ? "OK" : "RATÉ"), puis fin de la face A \(ok2 ? "OK" : "RATÉ")")
        }
        etat.projet = sauvegardeProjet

        // Dos du boîtier 3D : le rabat et la cassette à travers le plastique.
        if let img = Boitier3D.image(etat.mise, taille: CGSize(width: 600, height: 600), dos: true), let t = img.tiffRepresentation,
           let png = NSBitmapImageRep(data: t)?.representation(using: .png, properties: [:]) {
            try? png.write(to: dossier.appendingPathComponent("boitier-3d-dos.png"))
        }
        // Mixtape avec plusieurs artistes et des titres longs : la durée ne doit jamais disparaître.
        var mx = etat.projet
        mx.mode = .mixtape
        mx.faceA[1].morceau.titre = "Parked In The Front Of The Mall (Extended Night Version)"
        mx.faceA[1].morceau.artistes = ["The Long Name Orchestra"]
        mx.faceA[2].morceau.artistes = ["Nick Drake"]
        let mxMise = Mise(projet: mx, design: etat.design)
        for (i, p) in Export.pages(mxMise).enumerated() where !p.nom.contains("Obi") {
            if let data = Export.png(p.vue, dpi: 300) { try? data.write(to: dossier.appendingPathComponent("mixtape-\(i + 1).png")) }
        }
        journal.append("Alertes mixtape (titres longs) : " + mxMise.alertes().map(\.message).joined(separator: " | "))

        // VU-mètres pendant la musique (pas seulement avec la tonalité) : un fichier à −12 dBFS doit les mettre vers 0 VU.
        journal.append(await testerVU(moteur, tmp))

        journal.append("Plan de la cassette envoyé à Claude :\n" + etat.mise.anatomie())
        journal.append("Polices disponibles : " + Typo.disponibles.joined(separator: ", "))
        try? journal.joined(separator: "\n").write(to: dossier.appendingPathComponent("journal.txt"), atomically: true, encoding: .utf8)
        try? FileManager.default.removeItem(at: tmp)
    }

    /// Rend une vue AppKit/SwiftUI complète (champs, listes…) dans une fenêtre hors écran.
    static func avecCoque(_ projet: Projet, _ c: CouleurCoque) -> Projet {
        var p = projet
        p.cassette.coque = c
        return p
    }

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

    static func testerVU(_ moteur: MoteurEnregistrement, _ dossier: URL) async -> String {
        let url = dossier.appendingPathComponent("sinus-12dB.caf")
        let taux = 44100.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: taux, channels: 2),
              let fichier = try? AVAudioFile(forWriting: url, settings: format.settings),
              let tampon = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(taux * 6)) else { return "VU : fichier de test impossible" }
        tampon.frameLength = tampon.frameCapacity
        for c in 0..<2 {
            for i in 0..<Int(tampon.frameLength) { tampon.floatChannelData![c][i] = Float(0.355 * sin(2 * Double.pi * 440 * Double(i) / taux)) }
        }
        try? fichier.write(from: tampon)
        var p = Projet(numeroCatalogue: "TEST-VU")
        p.faceA = [Piste(morceau: Morceau(titre: "Sinus", artistes: ["Test"], dureeMs: 6000), fichier: url, dureeFichier: 6)]
        var r = ReglagesPlatine(); r.amorce = 0.2; r.compteARebours = 0
        moteur.charger(p, face: .a, reglages: r, sortieUID: nil, egaliser: false)
        if case .erreur(let e) = moteur.etat { return "VU : moteur audio indisponible sur cette machine (\(e))" }
        moteur.demarrer()
        try? await Task.sleep(for: .milliseconds(2500))
        let (g, d) = moteur.niveauMesure
        let affiche = moteur.niveaux
        moteur.arreter()
        let ok = g > -20 && affiche.gauche > -20
        return String(format: "VU pendant la musique : mesuré %.1f / %.1f dBFS, aiguilles %.1f / %.1f dBFS (attendu ≈ −12) → %@",
                      g, d, affiche.gauche, affiche.droite, ok ? "OK" : "IMMOBILES")
    }

    /// Affiche la vue, fait tourner la molette (comme un vrai utilisateur) sur chaque zone qui défile,
    /// et capture avant / après. Renvoie ce qui a bougé, pour le journal.
    static func testerDefilement(_ vue: some View, _ taille: CGSize, _ dossier: URL, _ nom: String) async -> [String] {
        let h = NSHostingView(rootView: vue.frame(width: taille.width, height: taille.height))
        h.frame = CGRect(origin: .zero, size: taille)
        let w = NSWindow(contentRect: h.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        w.contentView = h
        w.orderFrontRegardless()
        try? await Task.sleep(for: .milliseconds(1200))
        h.layoutSubtreeIfNeeded()
        func photo(_ suffixe: String) {
            if let rep = h.bitmapImageRepForCachingDisplay(in: h.bounds) {
                h.cacheDisplay(in: h.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: dossier.appendingPathComponent("\(nom)-\(suffixe).png"))
            }
        }
        photo("avant")
        func defilantes(_ v: NSView) -> [NSScrollView] { ((v as? NSScrollView).map { [$0] } ?? []) + v.subviews.flatMap(defilantes) }
        let zones = defilantes(h).filter { ($0.documentView?.frame.height ?? 0) > $0.contentView.bounds.height + 1 }
        func decrire(_ sv: NSScrollView) -> String {
            let r = sv.convert(sv.bounds, to: nil)
            return "zone x=\(Int(r.minX)) (\(Int(sv.documentView?.frame.height ?? 0)) pt pour \(Int(sv.contentView.bounds.height)))"
        }
        var lignes = ["Défilement \(nom) (\(Int(taille.width)) × \(Int(taille.height))) :"]
        // Comme une vraie molette : l'événement part de la position de la souris (au-dessus des curseurs, champs, listes…).
        for sv in zones {
            let r = sv.convert(sv.bounds, to: nil)
            for f in [0.2, 0.5, 0.8] {
                let p = NSPoint(x: r.midX, y: r.minY + r.height * f)
                let avant = zones.map { $0.contentView.bounds.origin.y }
                guard let cg = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: -400, wheel2: 0, wheel3: 0),
                      let e = NSEvent(cgEvent: cg) else { continue }
                Molette.defiler(e, fenetre: w, point: p)
                let bouge = zip(zones, avant).filter { $0.0.contentView.bounds.origin.y != $0.1 }.map { decrire($0.0) }
                lignes.append("- souris sur \(decrire(sv)) à \(Int(f * 100)) % : " + (bouge.isEmpty ? "RIEN NE BOUGE" : "défile → " + bouge.joined(separator: ", ")))
            }
        }
        h.layoutSubtreeIfNeeded()
        photo("apres")
        w.orderOut(nil)
        return lignes
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
        var p = Projet(numeroCatalogue: "SLF-001")
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
        d.credits = "Écrit, joué et produit par Jeremy Sadik.\nCassette STUDIOLAFLEUR SLF-001."
        d.obiTexte = "AN AFTERNOON AT THE LAKE"
        p.design = d
        return p
    }
}
