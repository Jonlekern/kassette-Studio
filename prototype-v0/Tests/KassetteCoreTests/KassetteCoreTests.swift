import XCTest
@testable import KassetteCore

final class KassetteCoreTests: XCTestCase {
    func m(_ n: Int, _ secondes: Int) -> Morceau {
        Morceau(id: "id\(n)", uri: "spotify:track:id\(n)", titre: "Titre \(n)", artistes: ["Artiste \(n)"], album: "Album", dureeMs: secondes * 1000)
    }
    let r = ReglagesEnregistrement(amorce: 5, blanc: 2)

    func testDureeFace() {
        XCTAssertEqual(dureeFace([], r), 0)
        XCTAssertEqual(dureeFace([m(1, 100)], r), 105)
        XCTAssertEqual(dureeFace([m(1, 100), m(2, 200)], r), 5 + 300 + 2)
    }

    func testRepartirDansLOrdre() {
        // C46 : 1380 s par face. 3 × 450 s + amorce + 2 blancs = 1359 s : 3 morceaux par face.
        let l = (1...7).map { m($0, 450) }
        let (a, b, reste) = repartirDansLOrdre(l, .c46, r)
        XCTAssertEqual(a.map(\.id), ["id1", "id2", "id3"])
        XCTAssertEqual(b.map(\.id), ["id4", "id5", "id6"])
        XCTAssertEqual(reste.map(\.id), ["id7"])
    }

    func testAppliquerOrdreIgnoreIndicesInvalidesEtDebordements() {
        let l = (0..<5).map { m($0, 450) }
        let (a, b, reste) = appliquerOrdre(l, indicesA: [4, 4, 99, 0, 1, 2], indicesB: [3], .c46, r)
        XCTAssertEqual(a.map(\.id), ["id4", "id0", "id1"]) // id2 déborde
        XCTAssertEqual(b.map(\.id), ["id3"])
        XCTAssertEqual(reste.map(\.id), ["id2"])
    }

    func testAnalyserLien() {
        XCTAssertEqual(ClientSpotify.analyserLien("https://open.spotify.com/intl-fr/playlist/37i9dQZF1DX?si=abc")?.1, "37i9dQZF1DX")
        XCTAssertEqual(ClientSpotify.analyserLien("spotify:album:XYZ")?.0, "album")
        XCTAssertEqual(ClientSpotify.analyserLien(" https://open.spotify.com/track/T1 ")?.0, "track")
        XCTAssertNil(ClientSpotify.analyserLien("https://example.com/playlist/1"))
        XCTAssertNil(ClientSpotify.analyserLien("spotify:artist:1"))
    }

    func testElementPlaylistAccepteItemEtTrack() throws {
        let json = """
        {"items":[
          {"item":{"type":"track","id":"a","uri":"spotify:track:a","name":"A","duration_ms":1000,"artists":[{"name":"X"}],
                   "album":{"name":"Al","release_date":"1994-05-01","images":[{"url":"https://i/1","width":640},{"url":"https://i/2","width":1200}]}}},
          {"track":{"type":"track","id":"b","uri":"spotify:track:b","name":"B","duration_ms":2000,"artists":[{"name":"Y"}]}},
          {"item":{"type":"episode","id":"c","uri":"spotify:episode:c","name":"C","duration_ms":3000,"artists":[]}},
          {"item":null}
        ],"next":null}
        """
        let page = try JSONDecoder().decode(Page<ElementPlaylist>.self, from: Data(json.utf8))
        let l = page.items.compactMap { $0.contenu?.morceau() }
        XCTAssertEqual(l.map(\.id), ["a", "b"])
        XCTAssertEqual(l[0].annee, "1994")
        XCTAssertEqual(l[0].pochetteURL?.absoluteString, "https://i/1")
    }

    func testExportKassetteCreator() throws {
        var mix = Mixtape()
        mix.faceA = [m(1, 185)]; mix.faceB = [m(2, 61)]
        mix.jaquette.titre = "Été 94"
        XCTAssertEqual(Export.tracklistTexte(mix), "Face A\nArtiste 1 - Titre 1 3:05\n\nFace B\nArtiste 2 - Titre 2 1:01")
        let obj = try JSONSerialization.jsonObject(with: Export.projetKassetteCreator(mix, pochetteDataURL: nil)) as! [String: Any]
        XCTAssertEqual(obj["gabarit"] as? String, "cassette-jcard")
        let tl = obj["tracklist"] as! [String: Any]
        XCTAssertEqual((tl["faceA"] as! [[String: Any]])[0]["duree"] as? Int, 185)
        XCTAssertEqual(Export.nomFichier(mix), "ete_94")
        XCTAssertTrue(Export.m3u(mix).contains("#EXTINF:185,Artiste 1 - Titre 1\nspotify:track:id1"))
    }
}
