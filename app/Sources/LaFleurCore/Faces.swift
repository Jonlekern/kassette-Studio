import Foundation

/// Calculs de temps de bande et répartition des morceaux sur les faces A et B.
public enum Faces {
    /// Temps de bande occupé : amorce + morceaux + blancs entre eux.
    public static func duree(_ pistes: [Piste], _ r: ReglagesPlatine) -> TimeInterval {
        guard !pistes.isEmpty else { return 0 }
        return r.amorce + pistes.reduce(0) { $0 + $1.duree } + r.blanc * Double(pistes.count - 1)
    }

    /// Place utilisable sur une face, marge de fin déduite.
    public static func capacite(_ c: Cassette, _ r: ReglagesPlatine) -> TimeInterval {
        Double(c.longueur.minutesParFace * 60) - r.margeFin
    }

    public static func tient(_ pistes: [Piste], _ c: Cassette, _ r: ReglagesPlatine) -> Bool {
        duree(pistes, r) <= capacite(c, r)
    }

    /// Mode album : l'ordre est gardé, on cherche la coupure A/B la plus équilibrée qui tient sur la bande.
    /// Renvoie nil si aucune coupure ne fait tenir tout l'album.
    public static func couperAlbum(_ pistes: [Piste], _ c: Cassette, _ r: ReglagesPlatine) -> (faceA: [Piste], faceB: [Piste])? {
        guard !pistes.isEmpty else { return ([], []) }
        var meilleur: (Int, TimeInterval)?
        for k in 0...pistes.count {
            let a = Array(pistes[..<k]), b = Array(pistes[k...])
            guard tient(a, c, r), tient(b, c, r) else { continue }
            let ecart = abs(duree(a, r) - duree(b, r))
            if meilleur == nil || ecart < meilleur!.1 { meilleur = (k, ecart) }
        }
        guard let (k, _) = meilleur else { return nil }
        return (Array(pistes[..<k]), Array(pistes[k...]))
    }

    /// Applique l'ordre proposé par Claude (indices dans `pistes`). Indices invalides ou en double ignorés ;
    /// les morceaux oubliés ou qui font déborder leur face sont renvoyés à part.
    public static func appliquerOrdre(_ pistes: [Piste], indicesA: [Int], indicesB: [Int], _ c: Cassette, _ r: ReglagesPlatine)
        -> (faceA: [Piste], faceB: [Piste], horsBande: [Piste]) {
        var vus = Set<Int>()
        func prendre(_ indices: [Int]) -> [Piste] {
            var face: [Piste] = []
            for i in indices where pistes.indices.contains(i) && !vus.contains(i) {
                if tient(face + [pistes[i]], c, r) { face.append(pistes[i]); vus.insert(i) }
            }
            return face
        }
        let a = prendre(indicesA), b = prendre(indicesB)
        return (a, b, pistes.indices.filter { !vus.contains($0) }.map { pistes[$0] })
    }
}
