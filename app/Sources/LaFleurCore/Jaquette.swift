import Foundation

// MARK: - Le design d'une cassette (jaquette, étiquettes, O-card, obi)

public enum FormeDos: String, Codable, CaseIterable, Sendable {
    case rectoSeul, court, normal, long, biseaute
    public var nom: String {
        switch self {
        case .rectoSeul: "Recto seul"
        case .court: "Court"
        case .normal: "Normal"
        case .long: "Long"
        case .biseaute: "Biseauté"
        }
    }
    /// Largeur du rabat (dos) en mm.
    public var rabat: Double {
        switch self {
        case .rectoSeul: 0
        case .court: 15
        case .normal, .biseaute: 27
        case .long: 38
        }
    }
}

/// Style de l'image du recto.
public enum StyleRecto: String, Codable, CaseIterable, Sendable {
    case pochette, collage, imagePerso, maison, graphique
    public var nom: String {
        switch self {
        case .pochette: "Pochette de l'album"
        case .collage: "Collage des covers"
        case .imagePerso: "Ta propre image"
        case .maison: "Style « K7 maison »"
        case .graphique: "Design graphique de Claude"
        }
    }
}

/// Sens de l'artwork sur le recto : vertical (image en haut, titre dessous) ou paysage (tout tourné d'un quart de tour).
public enum OrientationRecto: String, Codable, CaseIterable, Sendable {
    case vertical, paysage
    public var nom: String { switch self { case .vertical: "Vertical"; case .paysage: "Paysage" } }
}

/// Cadrage de l'image du recto : carrée avec le titre dessous, ou pleine hauteur avec un bandeau titre en bas.
public enum CadrageRecto: String, Codable, CaseIterable, Sendable {
    case carre, pleineHauteur
    public var nom: String { switch self { case .carre: "Image carrée"; case .pleineHauteur: "Pleine hauteur" } }
}

public enum PlaceCode: String, Codable, CaseIterable, Sendable {
    case rabat, tranche, interieur, libre
    public var nom: String {
        switch self {
        case .rabat: "Rabat, en bas"
        case .tranche: "Tranche"
        case .interieur: "Volet intérieur"
        case .libre: "Libre (à glisser)"
        }
    }
}

public enum CouleursCode: String, Codable, CaseIterable, Sendable {
    case blanc, design, perso
    public var nom: String { switch self { case .blanc: "Blanc"; case .design: "Design"; case .perso: "Perso" } }
}

public enum ContenuQR: String, Codable, CaseIterable, Sendable {
    case spotify, lienPerso, texte
    public var nom: String { switch self { case .spotify: "Lien Spotify"; case .lienPerso: "Lien perso"; case .texte: "Texte" } }
}

/// Palette : couleurs en hexa (#14283A).
public struct Palette: Codable, Hashable, Sendable {
    public var fond: String
    public var texte: String
    public var accent: String
    public init(fond: String, texte: String, accent: String) { self.fond = fond; self.texte = texte; self.accent = accent }
    public static let nuit = Palette(fond: "#14283A", texte: "#E8EEF2", accent: "#2F5F75")
}

/// Une forme du design graphique dessiné par Claude (coordonnées de 0 à 1 dans le recto).
public struct ElementGraphique: Codable, Hashable, Sendable {
    public enum Forme: String, Codable, Sendable { case rectangle, cercle, ligne, texte, triangle }
    public var forme: Forme
    public var x: Double, y: Double, largeur: Double, hauteur: Double
    public var couleur: String
    public var opacite: Double
    public var rotation: Double
    public var texte: String?
    public init(forme: Forme, x: Double, y: Double, largeur: Double, hauteur: Double, couleur: String,
                opacite: Double = 1, rotation: Double = 0, texte: String? = nil) {
        self.forme = forme; self.x = x; self.y = y; self.largeur = largeur; self.hauteur = hauteur
        self.couleur = couleur; self.opacite = opacite; self.rotation = rotation; self.texte = texte
    }
}

/// Une proposition de design (palette, polices, style du recto).
public struct Variante: Codable, Hashable, Identifiable, Sendable {
    public var id = UUID()
    public var nom: String
    public var palette: Palette
    public var policeTitre: String
    public var policeTexte: String
    public var titreItalique: Bool
    public var style: StyleRecto
    public var elements: [ElementGraphique]
    /// Opacité de l'image du recto (1 = pleine).
    public var opaciteImage: Double
    public var commentaire: String
    public var creeLe = Date()

    public init(nom: String = "A", palette: Palette = .nuit, policeTitre: String = "Cormorant Garamond",
                policeTexte: String = "Space Mono", titreItalique: Bool = true, style: StyleRecto = .pochette,
                elements: [ElementGraphique] = [], opaciteImage: Double = 1, commentaire: String = "") {
        self.nom = nom; self.palette = palette; self.policeTitre = policeTitre; self.policeTexte = policeTexte
        self.titreItalique = titreItalique; self.style = style; self.elements = elements
        self.opaciteImage = opaciteImage; self.commentaire = commentaire
    }
}

/// Pochette sur l'étiquette de la K7.
public enum ModeEtiquette: String, Codable, CaseIterable, Sendable {
    case petite, fond, aucune
    public var nom: String {
        switch self {
        case .petite: "Petite pochette"
        case .fond: "Pochette en fond"
        case .aucune: "Sans pochette"
        }
    }
}

/// Réglage libre d'un élément de la jaquette (déplacé, agrandi, tourné, masqué…), par rapport à sa place normale.
public struct Ajustement: Codable, Hashable, Sendable {
    /// Décalage en mm (positif = vers la droite / vers le bas).
    public var dx = 0.0
    public var dy = 0.0
    /// Taille (1 = normale).
    public var echelle = 1.0
    /// Rotation en degrés.
    public var rotation = 0.0
    public var opacite = 1.0
    public var masque = false
    /// Couleur forcée (#RRGGBB), vide = celle du design.
    public var couleur = ""
    public init() {}
    public var estNeutre: Bool { self == Ajustement() }

    enum CodingKeys: String, CodingKey { case dx, dy, echelle, rotation, opacite, masque, couleur }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func v<T: Decodable>(_ k: CodingKeys, _ defaut: T) -> T { ((try? c.decodeIfPresent(T.self, forKey: k)) ?? nil) ?? defaut }
        dx = v(.dx, 0); dy = v(.dy, 0); echelle = v(.echelle, 1); rotation = v(.rotation, 0)
        opacite = v(.opacite, 1); masque = v(.masque, false); couleur = v(.couleur, "")
    }
}

public struct Design: Codable, Hashable, Sendable {
    // Formats cochés
    public var jcard = true
    public var ocard = false
    public var etiquettes = true
    public var obi = false

    // Mise en page
    public var volets = 3
    public var dos: FormeDos = .normal
    public var reperes = true

    // Look
    public var variante = Variante()
    /// Les 3 variantes proposées en dernier et les versions précédentes (pour revenir en arrière).
    public var propositions: [Variante] = []
    public var historique: [Variante] = []
    public var imagePerso: URL?
    public var orientation: OrientationRecto = .vertical
    public var cadrage: CadrageRecto = .carre
    /// Images posées sur le recto (logos, écussons, éléments trouvés par Claude).
    public var imagesPosees: [ImagePosee] = []
    /// Échelle du texte par zone (« tranche », « titre », « tracklist »…), 1 = taille normale.
    public var echelles: [String: Double] = [:]
    /// Cadrage de l'image du recto quand elle est rognée (0 = calée à gauche / en haut, 0,5 = centrée, 1 = à droite / en bas).
    public var cadrageX = 0.5
    public var cadrageY = 0.5
    /// Étiquettes de K7 : petite pochette, pochette en fond ou sans pochette.
    public var etiquettePochette: ModeEtiquette = .petite
    /// Pochette en fond : voile de la couleur de fond par-dessus l'image, pour lire les textes (0 à 0,9).
    public var voileEtiquette = 0.45
    public var cadrageEtiquetteX = 0.5
    public var cadrageEtiquetteY = 0.5
    /// Réglages libres par élément (« recto-titre », « etiquette-face »…, voir `ElementsJaquette`).
    public var ajustements: [String: Ajustement] = [:]

    // Textes
    /// nil = automatique : « ARTISTE · TITRE ».
    public var texteTranche: String?
    public var notes = ""
    public var credits = ""
    public var obiTexte = ""
    public var afficherLogoMaison = true
    /// Une ligne « Paroles : genius.com » dans les crédits (jamais les paroles elles-mêmes).
    public var lienParoles = false

    // Codes
    public var codeBarres = true
    public var genreCode: CodeBarres1D.Genre = .ean13
    public var numeroCode = ""
    /// nil = automatique : « MAISON · CATALOGUE ».
    public var texteCode: String?
    public var placeCode: PlaceCode = .rabat
    public var couleursCode: CouleursCode = .design
    public var barresPerso = "#000000"
    public var fondPerso = "#FFFFFF"
    public var chiffresCode = true
    public var echelleCode = 1.0
    /// Taille réelle des codes en mm (0 = automatique).
    public var largeurCodeMM = 0.0
    public var hauteurCodeMM = 0.0
    public var coteQRMM = 0.0
    public var largeurSpotifyMM = 0.0
    public var qr = false
    public var contenuQR: ContenuQR = .spotify
    public var texteQR = ""
    public var placeQR: PlaceCode = .rabat
    public var codeSpotify = false
    /// Place libre des codes sur la J-card (mm depuis le coin haut gauche, extérieur) et rotation.
    public var codeX = 70.0
    public var codeY = 62.0
    public var rotationCode = 0.0

    /// Logo de la maison de disque importé par l'utilisateur (usage perso uniquement).
    public var logoMaison: URL?

    // Vérification
    public var alertesForcees: Set<String> = []

    enum CodingKeys: String, CodingKey {
        case jcard, ocard, etiquettes, obi, volets, dos, reperes, variante, propositions, historique, imagePerso, orientation, cadrage, imagesPosees, echelles, cadrageX, cadrageY, etiquettePochette, voileEtiquette, cadrageEtiquetteX, cadrageEtiquetteY, ajustements, texteTranche, notes, credits, obiTexte, afficherLogoMaison, lienParoles, codeBarres, genreCode, numeroCode, texteCode, placeCode, couleursCode, barresPerso, fondPerso, chiffresCode, echelleCode, largeurCodeMM, hauteurCodeMM, coteQRMM, largeurSpotifyMM, qr, contenuQR, texteQR, placeQR, codeSpotify, codeX, codeY, rotationCode, logoMaison, alertesForcees
    }

    /// Décodage tolérant : un champ absent ou illisible prend sa valeur par défaut (les anciennes cassettes restent lisibles).
    /// Généré par outils/regenerer-design.py.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Design()
        func v<T: Decodable>(_ k: CodingKeys, _ defaut: T) -> T { ((try? c.decodeIfPresent(T.self, forKey: k)) ?? nil) ?? defaut }
        jcard = v(.jcard, d.jcard)
        ocard = v(.ocard, d.ocard)
        etiquettes = v(.etiquettes, d.etiquettes)
        obi = v(.obi, d.obi)
        volets = v(.volets, d.volets)
        dos = v(.dos, d.dos)
        reperes = v(.reperes, d.reperes)
        variante = v(.variante, d.variante)
        propositions = v(.propositions, d.propositions)
        historique = v(.historique, d.historique)
        imagePerso = v(.imagePerso, d.imagePerso)
        orientation = v(.orientation, d.orientation)
        cadrage = v(.cadrage, d.cadrage)
        imagesPosees = v(.imagesPosees, d.imagesPosees)
        echelles = v(.echelles, d.echelles)
        cadrageX = v(.cadrageX, d.cadrageX)
        cadrageY = v(.cadrageY, d.cadrageY)
        etiquettePochette = v(.etiquettePochette, d.etiquettePochette)
        voileEtiquette = v(.voileEtiquette, d.voileEtiquette)
        cadrageEtiquetteX = v(.cadrageEtiquetteX, d.cadrageEtiquetteX)
        cadrageEtiquetteY = v(.cadrageEtiquetteY, d.cadrageEtiquetteY)
        ajustements = v(.ajustements, d.ajustements)
        texteTranche = v(.texteTranche, d.texteTranche)
        notes = v(.notes, d.notes)
        credits = v(.credits, d.credits)
        obiTexte = v(.obiTexte, d.obiTexte)
        afficherLogoMaison = v(.afficherLogoMaison, d.afficherLogoMaison)
        lienParoles = v(.lienParoles, d.lienParoles)
        codeBarres = v(.codeBarres, d.codeBarres)
        genreCode = v(.genreCode, d.genreCode)
        numeroCode = v(.numeroCode, d.numeroCode)
        texteCode = v(.texteCode, d.texteCode)
        placeCode = v(.placeCode, d.placeCode)
        couleursCode = v(.couleursCode, d.couleursCode)
        barresPerso = v(.barresPerso, d.barresPerso)
        fondPerso = v(.fondPerso, d.fondPerso)
        chiffresCode = v(.chiffresCode, d.chiffresCode)
        echelleCode = v(.echelleCode, d.echelleCode)
        largeurCodeMM = v(.largeurCodeMM, d.largeurCodeMM)
        hauteurCodeMM = v(.hauteurCodeMM, d.hauteurCodeMM)
        coteQRMM = v(.coteQRMM, d.coteQRMM)
        largeurSpotifyMM = v(.largeurSpotifyMM, d.largeurSpotifyMM)
        qr = v(.qr, d.qr)
        contenuQR = v(.contenuQR, d.contenuQR)
        texteQR = v(.texteQR, d.texteQR)
        placeQR = v(.placeQR, d.placeQR)
        codeSpotify = v(.codeSpotify, d.codeSpotify)
        codeX = v(.codeX, d.codeX)
        codeY = v(.codeY, d.codeY)
        rotationCode = v(.rotationCode, d.rotationCode)
        logoMaison = v(.logoMaison, d.logoMaison)
        alertesForcees = v(.alertesForcees, d.alertesForcees)
    }

    public init() {}

    public func echelle(_ zone: String) -> Double { echelles[zone] ?? 1 }
    public func ajustement(_ id: String) -> Ajustement { ajustements[id] ?? Ajustement() }

    /// Garde l'ancienne variante dans l'historique et passe à la nouvelle.
    public mutating func choisir(_ v: Variante) {
        if variante != v { historique.append(variante); if historique.count > 30 { historique.removeFirst() } }
        variante = v
    }
}

extension Projet {
    /// Texte de tranche par défaut.
    public var trancheAuto: String {
        [artiste.uppercased(), titre.uppercased()].filter { !$0.isEmpty }.joined(separator: " · ")
    }
    public var texteCodeAuto: String { "\(maisonDeDisque) · \(numeroCatalogue)" }
    public var numeroCodeAuto: String { CodesBarres.eanParDefaut(CodesBarres.numeroDeCatalogue(numeroCatalogue)) }
    /// Ligne ℗/© du rabat.
    public var ligneDroits: String {
        if let droits, !droits.isEmpty { return droits }
        let a = annee ?? String(Calendar.current.component(.year, from: creeLe))
        return "℗ © \(a) \(maisonDeDisque)"
    }
    /// Lien Spotify de l'album (pour le QR et le code Spotify).
    public var lienSpotify: URL? { spotifyAlbumID.map { URL(string: "https://open.spotify.com/album/\($0)")! } }
    public var uriSpotify: String? { spotifyAlbumID.map { "spotify:album:\($0)" } }
}

// MARK: - Gabarits (dimensions réelles, en mm)

public struct Panneau: Hashable, Sendable {
    public enum Genre: Hashable, Sendable { case rabat, tranche, recto, interieur(Int), colle, dos, fenetre }
    public let genre: Genre
    public let x: Double
    public let largeur: Double
    public var nom: String {
        switch genre {
        case .rabat: "Rabat"
        case .tranche: "Tranche"
        case .recto: "Recto"
        case .interieur(let i): "Intérieur \(i)"
        case .colle: "Patte de colle"
        case .dos: "Dos"
        case .fenetre: "Fenêtre"
        }
    }
}

public struct Gabarit: Hashable, Sendable {
    public let nom: String
    public let largeur: Double
    public let hauteur: Double
    public let panneaux: [Panneau]
    /// Plis verticaux (x en mm).
    public var plis: [Double] { panneaux.dropFirst().map(\.x) }
    public func panneau(_ g: Panneau.Genre) -> Panneau? { panneaux.first { $0.genre == g } }
}

public enum Gabarits {
    public static let fondPerdu = 3.0
    public static let hauteurJ = 101.6
    public static let recto = 64.0
    public static let tranche = 13.0
    public static let interieur = 63.0

    /// J-card à plat, vue de l'extérieur : rabat | tranche | recto | volets intérieurs.
    public static func jcard(volets: Int, dos: FormeDos) -> Gabarit {
        var p: [Panneau] = []
        var x = 0.0
        if dos.rabat > 0 { p.append(Panneau(genre: .rabat, x: x, largeur: dos.rabat)); x += dos.rabat }
        p.append(Panneau(genre: .tranche, x: x, largeur: tranche)); x += tranche
        p.append(Panneau(genre: .recto, x: x, largeur: recto)); x += recto
        let base = dos.rabat > 0 ? 3 : 2
        for i in 0..<max(0, min(8, volets) - base) {
            p.append(Panneau(genre: .interieur(i + 1), x: x, largeur: interieur)); x += interieur
        }
        return Gabarit(nom: "J-card \(volets) volets", largeur: x, hauteur: hauteurJ, panneaux: p)
    }

    /// O-card de cassingle : patte de colle | dos | tranche | recto | tranche (168,4 × 102,5 mm).
    public static let ocard: Gabarit = {
        let l = [(Panneau.Genre.colle, 15.7), (.dos, 63.8), (.tranche, 12.3), (.recto, 64.3), (.interieur(1), 12.3)]
        var x = 0.0
        let p = l.map { g, w -> Panneau in defer { x += w }; return Panneau(genre: g, x: x, largeur: w) }
        return Gabarit(nom: "O-card", largeur: 168.4, hauteur: 102.5, panneaux: p)
    }()

    /// Étiquette de cassette (une face) avec sa fenêtre.
    public static let etiquette = Gabarit(nom: "Étiquette de K7", largeur: 89, hauteur: 42,
                                          panneaux: [Panneau(genre: .recto, x: 0, largeur: 89)])
    /// Fenêtre de l'étiquette (x, y, largeur, hauteur en mm).
    public static let fenetreEtiquette = (x: 17.0, y: 17.0, largeur: 55.0, hauteur: 13.0)

    /// Obi : bande qui entoure le boîtier par le côté (dos | tranche | recto).
    public static let obi: Gabarit = Gabarit(nom: "Obi", largeur: 62, hauteur: 108, panneaux: [
        Panneau(genre: .dos, x: 0, largeur: 22), Panneau(genre: .tranche, x: 22, largeur: 18), Panneau(genre: .recto, x: 40, largeur: 22),
    ])
}

// MARK: - Papier et placement pour l'impression

public struct Papier: Hashable, Sendable {
    public let nom: String
    public let largeur: Double
    public let hauteur: Double
    public static let a4 = Papier(nom: "A4", largeur: 210, hauteur: 297)
    public static let a4Paysage = Papier(nom: "A4 paysage", largeur: 297, hauteur: 210)
    public static let a3Paysage = Papier(nom: "A3 paysage", largeur: 420, hauteur: 297)
    public static let letter = Papier(nom: "US Letter", largeur: 215.9, hauteur: 279.4)

    /// Le plus petit papier où l'objet tient avec son fond perdu et ses repères (marge 12 mm).
    public static func pour(largeur: Double, hauteur: Double) -> Papier {
        let m = 2 * (Gabarits.fondPerdu + 9)
        for p in [a4, a4Paysage, a3Paysage] where largeur + m <= p.largeur && hauteur + m <= p.hauteur { return p }
        return a3Paysage
    }
}

// MARK: - Vérification avant impression

public struct ZoneTexte: Sendable {
    public let nom: String
    public let texte: String
    /// Largeurs et hauteurs en mm : place disponible et place prise par le texte.
    public let largeurZone: Double
    public let largeurTexte: Double
    public let hauteurZone: Double
    public let hauteurTexte: Double
    public let taillePt: Double
    public let couleurTexte: String
    public let couleurFond: String
    public init(nom: String, texte: String, largeurZone: Double, largeurTexte: Double, hauteurZone: Double, hauteurTexte: Double,
                taillePt: Double, couleurTexte: String, couleurFond: String) {
        self.nom = nom; self.texte = texte; self.largeurZone = largeurZone; self.largeurTexte = largeurTexte
        self.hauteurZone = hauteurZone; self.hauteurTexte = hauteurTexte; self.taillePt = taillePt
        self.couleurTexte = couleurTexte; self.couleurFond = couleurFond
    }
}

public struct Alerte: Identifiable, Hashable, Sendable {
    public enum Gravite: String, Sendable { case bloquante, conseil }
    public let id: String
    public let zone: String
    public let gravite: Gravite
    public let message: String
    public init(id: String, zone: String, gravite: Gravite, message: String) {
        self.id = id; self.zone = zone; self.gravite = gravite; self.message = message
    }
}

public enum Verification {
    /// Taille minimale lisible à l'impression.
    public static let tailleMin = 5.0
    /// Largeur minimale d'un module de code-barres (mm) pour rester scannable.
    public static let moduleMin = 0.2

    /// Nom lisible (et traduit) d'une zone de la jaquette.
    public static func nomZone(_ id: String) -> String {
        switch id {
        case "tranche": String(localized: "tranche")
        case "titre": String(localized: "titre")
        case "artiste": String(localized: "artiste")
        case "badge": String(localized: "badge de bande")
        case "code": String(localized: "texte du code-barres")
        case "droits": String(localized: "ligne ℗/©")
        case "tracklist": String(localized: "tracklist")
        case "notes": String(localized: "notes")
        case "credits": String(localized: "crédits")
        case "etiquette": String(localized: "étiquette")
        case "obi": String(localized: "obi")
        default: id
        }
    }

    public static func verifier(_ zones: [ZoneTexte]) -> [Alerte] {
        var a: [Alerte] = []
        for z in zones where !z.texte.isEmpty {
            if z.largeurTexte > z.largeurZone + 0.05 {
                a.append(Alerte(id: "deborde-\(z.nom)", zone: z.nom, gravite: .bloquante,
                                message: String(localized: "« \(z.texte) » dépasse de la zone \(nomZone(z.nom)) de \(String(format: "%.1f", z.largeurTexte - z.largeurZone)) mm.")))
            }
            if z.hauteurTexte > z.hauteurZone + 0.05 {
                a.append(Alerte(id: "hauteur-\(z.nom)", zone: z.nom, gravite: .bloquante,
                                message: String(localized: "Le texte de la zone \(nomZone(z.nom)) est trop haut : il sort de \(String(format: "%.1f", z.hauteurTexte - z.hauteurZone)) mm.")))
            }
            if z.taillePt < tailleMin {
                a.append(Alerte(id: "petit-\(z.nom)", zone: z.nom, gravite: .conseil,
                                message: String(localized: "Texte de la zone \(nomZone(z.nom)) en \(String(format: "%.1f", z.taillePt)) pt : illisible une fois imprimé (5 pt minimum).")))
            }
            let c = contraste(z.couleurTexte, z.couleurFond)
            if c < 3 {
                a.append(Alerte(id: "contraste-\(z.nom)", zone: z.nom, gravite: .conseil,
                                message: String(localized: "Contraste faible dans la zone \(nomZone(z.nom)) (\(String(format: "%.1f", c)):1) : le texte se lira mal.")))
            }
        }
        return a
    }

    /// Code-barres : barres plus foncées que le fond, contraste suffisant, modules assez larges.
    public static func verifierCode(nom: String, barres: String, fond: String, largeurModule: Double) -> [Alerte] {
        var a: [Alerte] = []
        if luminance(barres) >= luminance(fond) {
            a.append(Alerte(id: "code-inverse-\(nom)", zone: nom, gravite: .bloquante,
                            message: String(localized: "\(nom) : barres plus claires que le fond, la plupart des lecteurs ne le liront pas.")))
        } else if contraste(barres, fond) < 4 {
            a.append(Alerte(id: "code-contraste-\(nom)", zone: nom, gravite: .bloquante,
                            message: String(localized: "\(nom) : contraste trop faible entre les barres et le fond (\(String(format: "%.1f", contraste(barres, fond))):1).")))
        }
        if largeurModule < moduleMin {
            a.append(Alerte(id: "code-petit-\(nom)", zone: nom, gravite: .conseil,
                            message: String(localized: "\(nom) très petit (module de \(String(format: "%.2f", largeurModule)) mm) : il risque de ne pas se scanner.")))
        }
        return a
    }

    public static func rgb(_ hex: String) -> (Double, Double, Double) {
        var h = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
        guard h.count == 6, let v = UInt32(h, radix: 16) else { return (0, 0, 0) }
        return (Double((v >> 16) & 255) / 255, Double((v >> 8) & 255) / 255, Double(v & 255) / 255)
    }

    /// Luminance relative (WCAG).
    public static func luminance(_ hex: String) -> Double {
        let (r, g, b) = rgb(hex)
        let l = { (c: Double) in c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * l(r) + 0.7152 * l(g) + 0.0722 * l(b)
    }

    /// Rapport de contraste WCAG (1 à 21).
    public static func contraste(_ a: String, _ b: String) -> Double {
        let x = luminance(a), y = luminance(b)
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
}
