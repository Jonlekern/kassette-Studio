import Vision
import XCTest
@testable import LaFleurCore

final class LaFleurCoreTests: XCTestCase {
    func piste(_ titre: String, _ s: Int, artiste: String = "Jeremy Sadik") -> Piste {
        Piste(morceau: Morceau(titre: titre, artistes: [artiste], dureeMs: s * 1000))
    }
    var reglages: ReglagesPlatine { var r = ReglagesPlatine(); r.amorce = 5; r.blanc = 2; r.margeFin = 30; return r }

    /// An Afternoon at the Lake, Jeremy Sadik : 12 titres.
    lazy var album: [Piste] = [("Sun Cream at the Lake", 342), ("The Muse", 313), ("Pre-Packaged Sandwich", 243),
        ("After Rain", 225), ("Glad to Know You", 156), ("Glass", 216), ("Mushroom Forest", 335),
        ("Parked in the Front of the Mall", 223), ("Seeking Adventure", 335), ("The Guy from Paris", 184),
        ("Clouds in Budapest", 228), ("Unknown Number", 220)].map { piste($0.0, $0.1) }

    func testDureeFace() {
        XCTAssertEqual(Faces.duree([], reglages), 0)
        XCTAssertEqual(Faces.duree([piste("a", 100), piste("b", 200)], reglages), 5 + 300 + 2)
    }

    func testCoupeAlbumC60() throws {
        let (a, b) = try XCTUnwrap(Faces.couperAlbum(album, Cassette(), reglages))
        XCTAssertEqual(a.count, 6)
        XCTAssertEqual(b.first?.morceau.titre, "Mushroom Forest")
        XCTAssertEqual(formaterDuree(Faces.duree(a, reglages)), "25:10")
        XCTAssertEqual(formaterDuree(Faces.duree(b, reglages)), "25:40")
    }

    func testCoupeImpossibleSurC46() {
        var c = Cassette(); c.longueur = .custom(minutesParFace: 23)
        XCTAssertNil(Faces.couperAlbum(album, c, reglages))
    }

    func testAppliquerOrdre() {
        var c = Cassette(); c.longueur = .custom(minutesParFace: 10) // 570 s utiles
        let l = (0..<4).map { piste("t\($0)", 200) }
        let r = Faces.appliquerOrdre(l, indicesA: [3, 3, 99, 0, 1], indicesB: [2], c, reglages)
        XCTAssertEqual(r.faceA.map(\.morceau.titre), ["t3", "t0"]) // t1 déborde
        XCTAssertEqual(r.faceB.map(\.morceau.titre), ["t2"])
        XCTAssertEqual(r.horsBande.map(\.morceau.titre), ["t1"])
    }

    func testDerouleSimple() {
        let d = Deroule([piste("a", 100), piste("b", 50)], reglages, cassette: Cassette())
        XCTAssertEqual(d.fin, 157)
        XCTAssertEqual(d.debut(piste: 1), 107)
        XCTAssertEqual(d.segment(a: 104)?.genre, .piste(0))
        XCTAssertEqual(d.segment(a: 106)?.genre, .blanc)
        XCTAssertNil(d.segment(a: 157))
    }

    func testDerouleAutoReverse() {
        var r = reglages; r.dureeReelleFace = 1830; r.delaiInversion = 2.4
        let d = Deroule([piste("a", 100)], r, cassette: Cassette(), enchainerFaceB: true)
        XCTAssertEqual(d.segments.map(\.genre), [.amorce, .piste(0), .finDeBande, .inversion])
        XCTAssertEqual(d.fin, 1832.4, accuracy: 0.001)
    }

    func testNomDeFichier() {
        XCTAssertEqual(NomDeFichier.analyser("03 - Jeremy Sadik - Glass.flac").numero, 3)
        XCTAssertEqual(NomDeFichier.analyser("03 - Jeremy Sadik - Glass.flac").titre, "Glass")
        XCTAssertEqual(NomDeFichier.analyser("Glass.mp3").titre, "Glass")
        XCTAssertNil(NomDeFichier.analyser("Glass.mp3").numero)
    }

    func testAssociation() {
        let m = Morceau(titre: "Glass", artistes: ["Jeremy Sadik"], dureeMs: 216_000)
        let bon = InfosFichier(url: URL(fileURLWithPath: "/k7/Glass.flac"), titre: "Glass", artiste: "Jeremy Sadik", duree: 216)
        let demo = InfosFichier(url: URL(fileURLWithPath: "/demos/Glass (demo).wav"), titre: "Glass (demo)", duree: 232)
        let autre = InfosFichier(url: URL(fileURLWithPath: "/k7/Sam.flac"), titre: "Sam", artiste: "Jeremy Sadik", duree: 196)
        XCTAssertEqual(Association.chercher(m, dans: [bon, autre]), .certain(bon))
        XCTAssertEqual(Association.chercher(m, dans: [autre]), .introuvable)
        if case .aConfirmer(let l) = Association.chercher(m, dans: [demo]) { XCTAssertEqual(l, [demo]) } else { XCTFail() }
        XCTAssertEqual(Association.normaliser("Glass (2025 Remastered)"), "glass")
        XCTAssertEqual(Association.normaliser("Été feat. Quelqu'un"), "ete")
    }

    func testOrdreDossier() {
        let f = { (nom: String, piste: Int?) in InfosFichier(url: URL(fileURLWithPath: "/k7/\(nom)"), numeroPiste: piste, duree: 60) }
        let tri = DossierAudio.ordonner([f("b.mp3", nil), f("x.mp3", 2), f("a.mp3", nil), f("y.mp3", 1)])
        XCTAssertEqual(tri.map { $0.url.lastPathComponent }, ["y.mp3", "x.mp3", "a.mp3", "b.mp3"])
    }

    func testStockageEtNumeros() throws {
        let dossier = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let s = Stockage(racine: dossier)
        var prefs = s.preferences()
        XCTAssertEqual(Stockage.numero(&prefs), "LFS-001")
        XCTAssertEqual(Stockage.numero(&prefs), "LFS-002")
        var p = Projet(numeroCatalogue: "LFS-001"); p.faceA = [piste("Glass", 216)]; p.cassette.longueur = .custom(minutesParFace: 23)
        try s.enregistrer(p)
        try s.enregistrer(prefs)
        XCTAssertEqual(s.projets().first?.faceA.first?.morceau.titre, "Glass")
        XCTAssertEqual(s.projets().first?.cassette.longueur, .custom(minutesParFace: 23))
        XCTAssertEqual(s.preferences().prochainNumero, 3)
    }

    func testLienSpotify() {
        XCTAssertEqual(ClientSpotify.analyserLien("https://open.spotify.com/album/6RUvESEU9esRjOKBMAdXHp?si=x")?.1, "6RUvESEU9esRjOKBMAdXHp")
        XCTAssertNil(ClientSpotify.analyserLien("https://example.com/album/1"))
    }
}

final class MusicBrainzTests: XCTestCase {
    func testDecodageDetail() throws {
        let json = """
        {"id":"98e6","title":"…Like Clockwork","date":"2013-05-31","barcode":"744861104029",
         "artist-credit":[{"name":"Queens of the Stone Age","joinphrase":""}],
         "label-info":[{"catalog-number":"OLE-1040-2","label":{"name":"Matador"}}],
         "cover-art-archive":{"front":true},
         "media":[{"format":"CD","position":1,"track-count":2,"tracks":[
           {"title":"Keep Your Eyes Peeled","length":304160,"position":1,"artist-credit":[{"name":"Queens of the Stone Age","joinphrase":""}]},
           {"title":"I Sat by the Ocean","length":235000,"position":2}]}]}
        """
        let d = try ClientMusicBrainz.decoderDetail(Data(json.utf8))
        XCTAssertEqual(d.morceaux.count, 2)
        XCTAssertEqual(d.morceaux[0].titre, "Keep Your Eyes Peeled")
        XCTAssertEqual(d.morceaux[1].artiste, "Queens of the Stone Age")
        XCTAssertEqual(d.album.maisonDeDisque, "Matador")
        XCTAssertEqual(d.album.catalogue, "OLE-1040-2")
        XCTAssertEqual(d.codeBarres, "744861104029")
        XCTAssertTrue(d.aUnePochette)
        XCTAssertEqual(ClientMusicBrainz.requete("Queens of the Stone Age - ...Like Clockwork"),
                       "release:\"...Like Clockwork\" AND artist:\"Queens of the Stone Age\"")
    }
}

import AVFoundation

/// Rendu hors ligne d'une face : vérifie au sample près l'amorce, les blancs et la coupure en fin de face.
final class MinutageAudioTests: XCTestCase {
    let taux = 44_100.0

    /// Fichier WAV d'un son continu qui ne repasse jamais par zéro de la durée voulue.
    func fichierTest(_ nom: String, duree: TimeInterval, dossier: URL) throws -> URL {
        let url = dossier.appendingPathComponent(nom)
        let format = AVAudioFormat(standardFormatWithSampleRate: taux, channels: 2)!
        let f = try AVAudioFile(forWriting: url, settings: format.settings)
        let n = AVAudioFrameCount(duree * taux)
        let b = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: n)!
        b.frameLength = n
        for c in 0..<2 { for i in 0..<Int(n) { b.floatChannelData![c][i] = 0.2 * Float(sin(Double(i) * 0.05)) + 0.3 } }
        try f.write(from: b)
        return url
    }

    func testFaceAuSamplePres() throws {
        let dossier = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        // La piste 2 dure plus longtemps que prévu : elle doit être coupée net à 0,5 s.
        let urls = [try fichierTest("a.wav", duree: 1.0, dossier: dossier), try fichierTest("b.wav", duree: 0.8, dossier: dossier)]
        let pistes = [Piste(morceau: Morceau(titre: "a", artistes: [], dureeMs: 1000), fichier: urls[0], dureeFichier: 1.0),
                      Piste(morceau: Morceau(titre: "b", artistes: [], dureeMs: 500), fichier: urls[1], dureeFichier: 0.5)]
        var r = ReglagesPlatine(); r.amorce = 0.5; r.blanc = 0.25
        let deroule = Deroule(pistes, r, cassette: Cassette())
        XCTAssertEqual(deroule.fin, 2.25, accuracy: 1e-9)

        let moteur = AVAudioEngine()
        let format = AVAudioFormat(standardFormatWithSampleRate: taux, channels: 2)!
        try moteur.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
        let fichiers = try urls.map { try AVAudioFile(forReading: $0) }
        let lecteurs = fichiers.map { f -> AVAudioPlayerNode in
            let n = AVAudioPlayerNode(); moteur.attach(n); moteur.connect(n, to: moteur.mainMixerNode, format: f.processingFormat); return n
        }
        try moteur.start()
        Programmation.programmer(lecteurs: lecteurs, fichiers: fichiers, deroule: deroule, depuis: 0) {
            AVAudioTime(sampleTime: AVAudioFramePosition($0 * self.taux), atRate: self.taux)
        }

        let total = Int(3.0 * taux)
        var signal = [Float](); signal.reserveCapacity(total)
        let tampon = AVAudioPCMBuffer(pcmFormat: moteur.manualRenderingFormat, frameCapacity: 4096)!
        while signal.count < total {
            let n = min(4096, total - signal.count)
            let st = try moteur.renderOffline(AVAudioFrameCount(n), to: tampon)
            XCTAssertEqual(st, .success)
            signal += (0..<Int(tampon.frameLength)).map { abs(tampon.floatChannelData![0][$0]) }
        }
        moteur.stop()

        // Instants (en s) où le son commence et s'arrête.
        var transitions: [Double] = []
        var actif = false
        for (i, v) in signal.enumerated() where (v > 0.01) != actif { actif.toggle(); transitions.append(Double(i) / taux) }
        let attendu = [0.5, 1.5, 1.75, 2.25]
        XCTAssertEqual(transitions.count, attendu.count, "transitions : \(transitions)")
        for (t, a) in zip(transitions, attendu) { XCTAssertEqual(t, a, accuracy: 0.001, "transitions : \(transitions)") }
    }
}

// MARK: - Étape 2 : codes et jaquette

final class CodesTests: XCTestCase {
    func testCleEAN() {
        XCTAssertEqual(CodesBarres.completerEAN("200012600001"), "2000126000012")
        XCTAssertEqual(CodesBarres.completerEAN("4006381333931"), "4006381333931")
        XCTAssertEqual(CodesBarres.completerUPC("03600029145"), "036000291452")
        XCTAssertNil(CodesBarres.completerEAN("12AB"))
        XCTAssertEqual(CodesBarres.eanParDefaut(CodesBarres.numeroDeCatalogue("LFS-001")), "2000126000012")
        XCTAssertEqual(CodesBarres.ean13("200012600001")?.modules.count, 95)
        XCTAssertEqual(CodesBarres.upcA("03600029145")?.modules.count, 95)
    }

    /// Image noir et blanc d'un code 1D (3 px par module, zones blanches comprises).
    private func image(_ c: CodeBarres1D) -> CGImage {
        let px = 3, marge = 12, w = (c.modules.count + 2 * marge) * px, h = 120
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        ctx.setFillColor(gray: 1, alpha: 1); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.setFillColor(gray: 0, alpha: 1)
        for (i, b) in c.modules.enumerated() where b { ctx.fill(CGRect(x: (marge + i) * px, y: 20, width: px, height: 80)) }
        return ctx.makeImage()!
    }

    private func image(_ m: [[Bool]]) -> CGImage {
        let px = 8, marge = 4, n = m.count, w = (n + 2 * marge) * px
        let ctx = CGContext(data: nil, width: w, height: w, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        ctx.setFillColor(gray: 1, alpha: 1); ctx.fill(CGRect(x: 0, y: 0, width: w, height: w))
        ctx.setFillColor(gray: 0, alpha: 1)
        for (y, ligne) in m.enumerated() { for (x, b) in ligne.enumerated() where b {
            ctx.fill(CGRect(x: (marge + x) * px, y: w - (marge + y + 1) * px, width: px, height: px))
        } }
        return ctx.makeImage()!
    }

    private func lire(_ img: CGImage) throws -> [String] {
        let r = VNDetectBarcodesRequest()
        try VNImageRequestHandler(cgImage: img).perform([r])
        return (r.results ?? []).compactMap(\.payloadStringValue)
    }

    func testLesCodesSeScannent() throws {
        XCTAssertEqual(try lire(image(CodesBarres.ean13("200012600001")!)).first, "2000126000012")
        XCTAssertEqual(try lire(image(CodesBarres.code128("LFS-001")!)).first, "LFS-001")
        let upc = try lire(image(CodesBarres.upcA("03600029145")!)).first
        XCTAssertTrue(upc == "036000291452" || upc == "0036000291452", "UPC lu : \(upc ?? "rien")")
        let lien = "https://open.spotify.com/album/6RUvESEU9esRjOKBMAdXHp"
        let m = try XCTUnwrap(CodeQR.modules(lien))
        XCTAssertEqual((m.count - 21) % 4, 0)
        XCTAssertEqual(try lire(image(m)).first, lien)
    }
}

final class JaquetteTests: XCTestCase {
    func testGabarits() {
        let j = Gabarits.jcard(volets: 3, dos: .normal)
        XCTAssertEqual(j.largeur, 27 + 13 + 64, accuracy: 1e-9)
        XCTAssertEqual(j.plis, [27, 40])
        XCTAssertEqual(Gabarits.jcard(volets: 5, dos: .normal).panneaux.count, 5)
        XCTAssertEqual(Gabarits.jcard(volets: 3, dos: .rectoSeul).panneaux.count, 3)
        XCTAssertEqual(Gabarits.ocard.largeur, Gabarits.ocard.panneaux.reduce(0) { $0 + $1.largeur }, accuracy: 0.01)
        XCTAssertEqual(Papier.pour(largeur: 104, hauteur: 101.6), .a4)
        XCTAssertEqual(Papier.pour(largeur: 230, hauteur: 101.6), .a4Paysage)
        XCTAssertEqual(Papier.pour(largeur: 356, hauteur: 101.6), .a3Paysage)
    }

    func testVerification() {
        XCTAssertEqual(Verification.contraste("#000000", "#FFFFFF"), 21, accuracy: 0.01)
        let z = ZoneTexte(nom: "tranche", texte: "JEREMY SADIK · AN AFTERNOON AT THE LAKE", largeurZone: 101.6, largeurTexte: 108,
                          hauteurZone: 13, hauteurTexte: 4, taillePt: 9, couleurTexte: "#E8EEF2", couleurFond: "#14283A")
        XCTAssertEqual(Verification.verifier([z]).map(\.id), ["deborde-tranche"])
        XCTAssertEqual(Verification.verifierCode(nom: "EAN", barres: "#FFFFFF", fond: "#14283A", largeurModule: 0.3).first?.gravite, .bloquante)
        XCTAssertTrue(Verification.verifierCode(nom: "EAN", barres: "#14283A", fond: "#FFFFFF", largeurModule: 0.3).isEmpty)
    }

    func testDesignTolerant() throws {
        // Un design enregistré par une ancienne version (champs manquants) se relit avec les valeurs par défaut.
        let d = try JSONDecoder().decode(Design.self, from: Data(#"{"volets": 5, "inconnu": 1}"#.utf8))
        XCTAssertEqual(d.volets, 5)
        XCTAssertEqual(d.dos, .normal)
        var p = Projet(numeroCatalogue: "LFS-001")
        p.design = d
        let relu = try JSONDecoder().decode(Projet.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(relu.design, d)
    }
}

final class CalibrageTests: XCTestCase {
    func testEchelle() {
        XCTAssertEqual(CalibrationImprimante.echelle(attendu: 10, mesure: 9.8)!, 1.0204, accuracy: 0.0001)
        XCTAssertEqual(CalibrationImprimante.echelle(attendu: 4, mesure: 4)!, 1)
        XCTAssertNil(CalibrationImprimante.echelle(attendu: 10, mesure: 4), "4 au lieu de 10 : sûrement des pouces, pas des cm")
    }

    func testPreferencesTolerantes() throws {
        // Préférences d'une version précédente (anciens champs, champs manquants) : rien n'est perdu.
        let json = #"{"conditionsAcceptees": true, "prochainNumero": 7, "decalageX": 1.5, "langue": "de"}"#
        let p = try JSONDecoder().decode(Preferences.self, from: Data(json.utf8))
        XCTAssertTrue(p.conditionsAcceptees)
        XCTAssertEqual(p.prochainNumero, 7)
        XCTAssertEqual(p.langue, "de")
        XCTAssertTrue(p.calibrations.isEmpty)
        XCTAssertEqual(p.platine, ReglagesPlatine())
    }
}

final class DiscogsTests: XCTestCase {
    func testDetail() throws {
        let json = #"""
        {"images": [{"uri": "https://i.discogs.com/a.jpg", "type": "primary"}],
         "extraartists": [{"name": "Jeremy Sadik (2)", "role": "Producer"}, {"name": "Ana", "role": "Producer"},
                          {"name": "Bob", "role": "Mixed By"}],
         "notes": "Recorded at the lake."}
        """#
        let d = try ClientDiscogs.decoderDetail(Data(json.utf8))
        XCTAssertEqual(d.photos.count, 1)
        XCTAssertEqual(d.credits, "Producer : Jeremy Sadik, Ana\nMixed By : Bob")
        XCTAssertEqual(d.notes, "Recorded at the lake.")
    }
}

final class RetouchesTests: XCTestCase {
    func testChampsDesign() {
        var p = Projet(numeroCatalogue: "LFS-001")
        var d = Design()
        XCTAssertTrue(ChampsDesign.appliquer("orientation", "paysage", projet: &p, design: &d))
        XCTAssertTrue(ChampsDesign.appliquer("taille_titre", "1,3", projet: &p, design: &d))
        XCTAssertTrue(ChampsDesign.appliquer("place_qr", "interieur", projet: &p, design: &d))
        XCTAssertTrue(ChampsDesign.appliquer("titre", "Nouveau titre", projet: &p, design: &d))
        XCTAssertFalse(ChampsDesign.appliquer("dos", "n'importe quoi", projet: &p, design: &d))
        XCTAssertTrue(ChampsDesign.appliquer("cadrage", "pleineHauteur", projet: &p, design: &d))
        XCTAssertFalse(ChampsDesign.appliquer("cadrage", "rond", projet: &p, design: &d))
        XCTAssertEqual(d.orientation, .paysage)
        XCTAssertEqual(d.cadrage, .pleineHauteur)
        // Une ancienne cassette sans cadrage se relit en « carré ».
        let ancien = try! JSONDecoder().decode(Design.self, from: Data("{\"orientation\":\"paysage\"}".utf8))
        XCTAssertEqual(ancien.cadrage, .carre)
        XCTAssertTrue(ClientClaude.conventionsK7.contains("JAMAIS SORTI EN CASSETTE"))
        // Une cassette enregistrée avant la couleur de coque se relit, en coque fumée.
        let k7 = try! JSONDecoder().decode(Cassette.self, from: Data("{\"bande\":\"typeIV\",\"marque\":\"TDK MA\"}".utf8))
        XCTAssertEqual(k7.bande, .typeIV)
        XCTAssertEqual(k7.marque, "TDK MA")
        XCTAssertEqual(k7.coque, .fumee)

        // GPT ou Gemini : JSON parfois entouré de ```json … ``` ; anciens réglages relus avec Claude par défaut.
        struct R: Decodable { let ok: Bool }
        let gpt = ClientClaude(cleAPI: "x", fournisseur: .openai)
        XCTAssertEqual(gpt.modele, FournisseurIA.openai.modeleParDefaut)
        XCTAssertEqual(ClientClaude(cleAPI: "x", fournisseur: .gemini, modele: "gemini-perso").modele, "gemini-perso")
        XCTAssertTrue(try! gpt.decoder(R.self, "```json\n{\"ok\": true}\n```").ok)
        let prefs = try! JSONDecoder().decode(Preferences.self, from: Data("{\"langue\":\"en\"}".utf8))
        XCTAssertEqual(prefs.fournisseurIA, .claude)
        XCTAssertEqual(prefs.langue, "en")
        XCTAssertEqual(d.echelle("titre"), 1.3, accuracy: 1e-9)
        XCTAssertEqual(d.placeQR, .interieur)
        XCTAssertEqual(p.titre, "Nouveau titre")
        // Chaque champ annoncé à Claude est bien reconnu.
        for c in ChampsDesign.tous where c != "images_retirer" {
            var p2 = p, d2 = d
            let v = c.hasPrefix("taille_") || ["opacite_image", "volets", "rotation_code", "code_x", "code_y"].contains(c) ? "1" : "oui"
            _ = ChampsDesign.appliquer(c, v, projet: &p2, design: &d2)
        }
    }

    func testCommons() {
        let json = #"""
        {"query": {"pages": {"12": {"title": "File:Sony logo.svg", "index": 1, "imageinfo": [{"thumburl": "https://upload.wikimedia.org/a.png",
          "url": "https://upload.wikimedia.org/a.svg", "descriptionurl": "https://commons.wikimedia.org/wiki/File:Sony_logo.svg",
          "mime": "image/svg+xml", "extmetadata": {"LicenseShortName": {"value": "Public domain"}}}]}}}}
        """#
        let r = Commons.decoder(Data(json.utf8))
        XCTAssertEqual(r.first?.titre, "Sony logo.svg")
        XCTAssertEqual(r.first?.image.absoluteString, "https://upload.wikimedia.org/a.png")
        XCTAssertEqual(r.first?.licence, "Public domain")
    }
}
