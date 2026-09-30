import Foundation

/// Le déroulé minuté d'une face : ce qui se passe à chaque instant de l'enregistrement.
public struct Deroule: Sendable {
    public enum Genre: Hashable, Sendable {
        case amorce
        case piste(Int)
        case blanc
        /// Auto-reverse : silence jusqu'au bout de la bande, puis le temps que la platine se retourne.
        case finDeBande
        case inversion
    }

    public struct Segment: Hashable, Sendable {
        public let genre: Genre
        public let debut: TimeInterval
        public let duree: TimeInterval
        public var fin: TimeInterval { debut + duree }
    }

    public let segments: [Segment]
    public var fin: TimeInterval { segments.last?.fin ?? 0 }

    /// Construit le déroulé d'une face. Avec `enchainerFaceB` (auto-reverse), le silence de fin de bande et
    /// l'inversion sont ajoutés à la fin, pour que la face B parte toute seule ensuite.
    public init(_ pistes: [Piste], _ r: ReglagesPlatine, cassette: Cassette, enchainerFaceB: Bool = false) {
        var s: [Segment] = []
        var t: TimeInterval = 0
        func ajouter(_ g: Genre, _ d: TimeInterval) { guard d > 0 else { return }; s.append(Segment(genre: g, debut: t, duree: d)); t += d }
        if !pistes.isEmpty { ajouter(.amorce, r.amorce) }
        for (i, p) in pistes.enumerated() {
            if i > 0 { ajouter(.blanc, r.blanc) }
            ajouter(.piste(i), p.duree)
        }
        if enchainerFaceB {
            let bande = r.dureeReelleFace ?? Double(cassette.longueur.minutesParFace * 60)
            ajouter(.finDeBande, bande - t)
            ajouter(.inversion, r.delaiInversion)
        }
        segments = s
    }

    /// Le segment en cours à l'instant `t` (nil avant le début ou après la fin).
    public func segment(a t: TimeInterval) -> Segment? {
        segments.first { t >= $0.debut && t < $0.fin }
    }

    /// Début de la piste d'indice `i`.
    public func debut(piste i: Int) -> TimeInterval? {
        segments.first { $0.genre == .piste(i) }?.debut
    }
}
