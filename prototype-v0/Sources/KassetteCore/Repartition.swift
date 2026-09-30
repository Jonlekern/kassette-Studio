import Foundation

/// Temps de bande occupé par une face : amorce + morceaux + blancs entre eux.
public func dureeFace(_ morceaux: [Morceau], _ r: ReglagesEnregistrement) -> TimeInterval {
    guard !morceaux.isEmpty else { return 0 }
    return r.amorce + morceaux.reduce(0) { $0 + $1.duree } + r.blanc * Double(morceaux.count - 1)
}

public func tientSurLaFace(_ morceaux: [Morceau], _ cassette: TypeCassette, _ r: ReglagesEnregistrement) -> Bool {
    dureeFace(morceaux, r) <= cassette.secondesParFace
}

/// Répartition simple dans l'ordre : on remplit A, puis B ; ce qui ne rentre pas reste en réserve.
public func repartirDansLOrdre(_ morceaux: [Morceau], _ cassette: TypeCassette, _ r: ReglagesEnregistrement)
    -> (faceA: [Morceau], faceB: [Morceau], reserve: [Morceau]) {
    var a: [Morceau] = [], b: [Morceau] = [], reste: [Morceau] = []
    for m in morceaux {
        if tientSurLaFace(a + [m], cassette, r) { a.append(m) }
        else if tientSurLaFace(b + [m], cassette, r) { b.append(m) }
        else { reste.append(m) }
    }
    return (a, b, reste)
}

/// Applique l'ordre proposé par Claude (indices dans `morceaux`). Les indices invalides ou en double sont
/// ignorés ; les morceaux oubliés et ceux qui débordent de leur face partent en réserve.
public func appliquerOrdre(_ morceaux: [Morceau], indicesA: [Int], indicesB: [Int],
                           _ cassette: TypeCassette, _ r: ReglagesEnregistrement)
    -> (faceA: [Morceau], faceB: [Morceau], reserve: [Morceau]) {
    var vus = Set<Int>()
    func prendre(_ indices: [Int]) -> [Morceau] {
        var face: [Morceau] = []
        for i in indices where morceaux.indices.contains(i) && !vus.contains(i) {
            vus.insert(i)
            if tientSurLaFace(face + [morceaux[i]], cassette, r) { face.append(morceaux[i]) } else { vus.remove(i) }
        }
        return face
    }
    let a = prendre(indicesA), b = prendre(indicesB)
    let reste = morceaux.indices.filter { !vus.contains($0) }.map { morceaux[$0] }
    return (a, b, reste)
}
