import Foundation

/// Exports lisibles par Kassette Creator (lafleurstudio/kassette.html).
public enum Export {
    /// Texte de tracklist : « Face A » / « Face B » puis une ligne « Artiste - Titre m:ss » par morceau.
    public static func tracklistTexte(_ mix: Mixtape) -> String {
        func lignes(_ face: [Morceau]) -> [String] { face.map { "\($0.artiste) - \($0.titre) \(formaterDuree($0.duree))" } }
        return (["Face A"] + lignes(mix.faceA) + ["", "Face B"] + lignes(mix.faceB)).joined(separator: "\n")
    }

    /// Playlist .m3u étendue (Kassette Creator l'importe ; les URI ouvrent les morceaux dans Spotify).
    public static func m3u(_ mix: Mixtape) -> String {
        var l = ["#EXTM3U"]
        for m in mix.faceA + mix.faceB {
            l.append("#EXTINF:\(Int(m.duree.rounded())),\(m.artiste) - \(m.titre)")
            l.append(m.uri)
        }
        return l.joined(separator: "\n") + "\n"
    }

    /// Projet .json minimal : Kassette Creator complète tout le reste avec ses valeurs par défaut.
    /// `pochetteDataURL` : l'image de pochette déjà encodée (data:image/jpeg;base64,…) ou nil.
    public static func projetKassetteCreator(_ mix: Mixtape, pochetteDataURL: String?) throws -> Data {
        let j = mix.jaquette
        func texte(_ champ: String, _ contenu: String) -> [String: Any] {
            ["id": champ, "champ": champ, "zone": champ, "face": "recto", "contenu": contenu, "visible": true]
        }
        func morceaux(_ face: [Morceau]) -> [[String: Any]] {
            face.map { ["artiste": $0.artiste, "titre": $0.titre, "duree": Int($0.duree.rounded())] }
        }
        var projet: [String: Any] = [
            "version": 2,
            "gabarit": "cassette-jcard",
            "textes": [
                texte("titre", j.titre), texte("artiste", j.artiste), texte("tranche", j.tranche),
                texte("rabat", j.rabat), texte("production", j.production),
            ],
            "tracklist": [
                "brut": tracklistTexte(mix),
                "cassette": mix.cassette.rawValue,
                "faceA": morceaux(mix.faceA),
                "faceB": morceaux(mix.faceB),
            ],
        ]
        if let img = pochetteDataURL { projet["cover"] = ["image": img] }
        return try JSONSerialization.data(withJSONObject: projet, options: [.prettyPrinted, .sortedKeys])
    }

    public static func nomFichier(_ mix: Mixtape) -> String {
        let base = mix.jaquette.titre.folding(options: [.diacriticInsensitive], locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: "_")
        return base.isEmpty ? "mixtape" : base.lowercased()
    }
}
