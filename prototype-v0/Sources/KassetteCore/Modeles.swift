import Foundation

/// Un morceau tel que Spotify le décrit (durée exacte comprise).
public struct Morceau: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var uri: String
    public var titre: String
    public var artistes: [String]
    public var album: String
    public var dateSortie: String?
    public var dureeMs: Int
    public var pochetteURL: URL?

    public init(id: String, uri: String, titre: String, artistes: [String], album: String,
                dateSortie: String? = nil, dureeMs: Int, pochetteURL: URL? = nil) {
        self.id = id; self.uri = uri; self.titre = titre; self.artistes = artistes; self.album = album
        self.dateSortie = dateSortie; self.dureeMs = dureeMs; self.pochetteURL = pochetteURL
    }

    public var artiste: String { artistes.joined(separator: ", ") }
    public var duree: TimeInterval { Double(dureeMs) / 1000 }
    public var annee: String? { dateSortie.map { String($0.prefix(4)) } }
}

/// Longueurs de bande usuelles (durée d'une face).
public enum TypeCassette: String, CaseIterable, Codable, Identifiable, Sendable {
    case c46 = "C46", c60 = "C60", c90 = "C90", c120 = "C120"
    public var id: String { rawValue }
    public var secondesParFace: TimeInterval {
        switch self { case .c46: 23 * 60; case .c60: 30 * 60; case .c90: 45 * 60; case .c120: 60 * 60 }
    }
}

public enum Face: String, Codable, CaseIterable, Sendable { case a = "A", b = "B" }

/// Timing de l'enregistrement.
public struct ReglagesEnregistrement: Codable, Equatable, Sendable {
    /// Blanc laissé en début de face (amorce de la bande, sans magnétique).
    public var amorce: TimeInterval = 5
    /// Blanc entre deux morceaux.
    public var blanc: TimeInterval = 2
    public init(amorce: TimeInterval = 5, blanc: TimeInterval = 2) { self.amorce = amorce; self.blanc = blanc }
}

/// Textes de la jaquette, calqués sur les zones de Kassette Creator.
public struct Jaquette: Codable, Equatable, Sendable {
    public var titre = "MA MIXTAPE"
    public var artiste = ""
    public var tranche = ""
    public var rabat = ""
    public var production = ""
    /// Album dont la pochette illustre le recto (URL d'image Spotify).
    public var pochetteURL: URL?
    public init() {}
}

public struct Mixtape: Codable, Equatable, Sendable {
    public var cassette: TypeCassette = .c60
    public var reglages = ReglagesEnregistrement()
    public var faceA: [Morceau] = []
    public var faceB: [Morceau] = []
    /// Morceaux importés mais pas encore placés sur une face.
    public var reserve: [Morceau] = []
    public var jaquette = Jaquette()
    public init() {}

    public func morceaux(_ face: Face) -> [Morceau] { face == .a ? faceA : faceB }
    public var tous: [Morceau] { faceA + faceB + reserve }
}

public func formaterDuree(_ secondes: TimeInterval) -> String {
    let s = max(0, Int(secondes.rounded())), h = s / 3600, m = (s % 3600) / 60, r = s % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, r) : String(format: "%d:%02d", m, r)
}
