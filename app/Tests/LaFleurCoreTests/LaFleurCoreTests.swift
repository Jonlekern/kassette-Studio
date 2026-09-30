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
