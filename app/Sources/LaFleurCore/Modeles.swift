import Foundation

/// Un morceau tel que Spotify (ou les tags d'un fichier) le décrit.
public struct Morceau: Codable, Hashable, Sendable {
    public var spotifyID: String?
    public var uri: String?
    public var titre: String
    public var artistes: [String]
    public var album: String
    public var dateSortie: String?
    public var dureeMs: Int
    public var numeroPiste: Int?
    public var numeroDisque: Int?
    public var pochetteURL: URL?

    public init(spotifyID: String? = nil, uri: String? = nil, titre: String, artistes: [String], album: String = "",
                dateSortie: String? = nil, dureeMs: Int, numeroPiste: Int? = nil, numeroDisque: Int? = nil,
                pochetteURL: URL? = nil) {
        self.spotifyID = spotifyID; self.uri = uri; self.titre = titre; self.artistes = artistes; self.album = album
        self.dateSortie = dateSortie; self.dureeMs = dureeMs; self.numeroPiste = numeroPiste
        self.numeroDisque = numeroDisque; self.pochetteURL = pochetteURL
    }

    public var artiste: String { artistes.joined(separator: ", ") }
    public var duree: TimeInterval { Double(dureeMs) / 1000 }
    public var annee: String? { dateSortie.map { String($0.prefix(4)) } }
}

/// Une ligne de la cassette : le morceau et, une fois associé, son fichier audio sur le Mac.
public struct Piste: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var morceau: Morceau
    /// Chemin du fichier audio associé (nil tant qu'aucun fichier n'est trouvé ou confirmé).
    public var fichier: URL?
    /// Durée réelle du fichier, qui fait foi pour l'enregistrement quand elle est connue.
    public var dureeFichier: TimeInterval?

    public init(id: UUID = UUID(), morceau: Morceau, fichier: URL? = nil, dureeFichier: TimeInterval? = nil) {
        self.id = id; self.morceau = morceau; self.fichier = fichier; self.dureeFichier = dureeFichier
    }

    /// Durée utilisée pour les calculs de bande : celle du fichier si on l'a, sinon celle de Spotify.
    public var duree: TimeInterval { dureeFichier ?? morceau.duree }
}

public enum Face: String, Codable, CaseIterable, Sendable { case a = "A", b = "B" }

public enum ModeCassette: String, Codable, CaseIterable, Sendable { case album, mixtape }

public enum LongueurCassette: Codable, Hashable, Sendable {
    case c60, c90
    case custom(minutesParFace: Int)

    public var minutesParFace: Int {
        switch self {
        case .c60: 30
        case .c90: 45
        case .custom(let m): m
        }
    }
    public var nom: String {
        switch self {
        case .c60: "C60"
        case .c90: "C90"
        case .custom(let m): "C\(m * 2)"
        }
    }
}

public enum TypeBande: String, Codable, CaseIterable, Sendable {
    case typeI, typeII, typeIV
    public var nom: String {
        switch self {
        case .typeI: "Type I · Normal"
        case .typeII: "Type II · Chrome"
        case .typeIV: "Type IV · Métal"
        }
    }
    /// Texte court pour les badges et l'étiquette de la K7.
    public var badge: String {
        switch self {
        case .typeI: "TYPE I · NORMAL"
        case .typeII: "TYPE II · CrO₂"
        case .typeIV: "TYPE IV · METAL"
        }
    }
}

public enum ReducteurBruit: String, Codable, CaseIterable, Sendable {
    case aucun, dolbyB, dolbyC
    public var nom: String {
        switch self {
        case .aucun: "Aucun"
        case .dolbyB: "Dolby B"
        case .dolbyC: "Dolby C"
        }
    }
}

/// La cassette physique utilisée.
public struct Cassette: Codable, Hashable, Sendable {
    public var longueur: LongueurCassette = .c60
    public var bande: TypeBande = .typeII
    public var reducteur: ReducteurBruit = .dolbyB
    public var marque: String = ""
    public init() {}
}

public enum TypePlatine: String, Codable, CaseIterable, Sendable { case simple, autoReverse }

/// Réglages de la platine et du déroulé de l'enregistrement.
public struct ReglagesPlatine: Codable, Hashable, Sendable {
    public var type: TypePlatine = .simple
    /// Blanc au début de chaque face (amorce de la bande).
    public var amorce: TimeInterval = 5
    /// Blanc entre deux morceaux.
    public var blanc: TimeInterval = 2
    /// Marge de sécurité gardée libre en fin de face.
    public var margeFin: TimeInterval = 30
    /// Compte à rebours avant le départ, pour relâcher la pause de la platine.
    public var compteARebours: Int = 5
    /// Auto-reverse : durée réelle d'une face (une C60 fait souvent un peu plus de 30 min).
    public var dureeReelleFace: TimeInterval?
    /// Auto-reverse : temps que met la platine à se retourner.
    public var delaiInversion: TimeInterval = 2.5
    public init() {}
}

/// Une cassette en préparation ou terminée : tout ce que l'app sauvegarde.
public struct Projet: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID = UUID()
    public var numeroCatalogue: String
    public var titre: String = ""
    public var artiste: String = ""
    public var maisonDeDisque: String = "LAFLEURSTUDIO"
    public var mode: ModeCassette = .album
    public var cassette = Cassette()
    public var faceA: [Piste] = []
    public var faceB: [Piste] = []
    public var pochetteURL: URL?
    public var spotifyAlbumID: String?
    /// Infos d'origine de l'album (MusicBrainz, Discogs…) : année, maison de disque, catalogue, code-barres.
    public var annee: String?
    public var labelOrigine: String?
    public var catalogueOrigine: String?
    public var codeBarresOrigine: String?
    public var musicBrainzID: String?
    /// Ligne ℗/© officielle (Spotify), si connue.
    public var droits: String?
    /// Jaquette, étiquettes, O-card, obi (nil tant que l'écran Jaquette n'a pas été ouvert).
    public var design: Design?
    public var enregistree: Set<Face> = []
    public var creeLe = Date()
    public var modifieLe = Date()

    public init(numeroCatalogue: String) { self.numeroCatalogue = numeroCatalogue }

    public func pistes(_ face: Face) -> [Piste] { face == .a ? faceA : faceB }
    public var toutes: [Piste] { faceA + faceB }
}

public func formaterDuree(_ secondes: TimeInterval) -> String {
    let s = max(0, Int(secondes.rounded())), h = s / 3600, m = (s % 3600) / 60, r = s % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, r) : String(format: "%d:%02d", m, r)
}
