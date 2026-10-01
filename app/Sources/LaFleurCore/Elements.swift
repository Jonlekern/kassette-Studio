import Foundation

/// Tous les éléments de la jaquette qu'on peut sélectionner, déplacer, agrandir, tourner ou masquer
/// (dans l'aperçu, dans le panneau « Élément », ou par l'IA). L'identifiant sert de clé dans `Design.ajustements`.
public enum ElementsJaquette {
    public struct Element: Sendable, Hashable, Identifiable {
        public let id: String
        public let nom: String
        public let format: String
        /// Zone d'échelle du texte (`Design.echelles`) et taille normale en points, pour les textes.
        public let zoneTexte: String?
        public let taillePt: Double?
        /// Taille normale en mm (largeur × hauteur), pour les logos et images.
        public let tailleMM: [Double]?
    }

    private static func t(_ id: String, _ nom: String, _ format: String, _ zone: String, _ pt: Double) -> Element {
        Element(id: id, nom: nom, format: format, zoneTexte: zone, taillePt: pt, tailleMM: nil)
    }
    private static func o(_ id: String, _ nom: String, _ format: String, _ l: Double = 0, _ h: Double = 0) -> Element {
        Element(id: id, nom: nom, format: format, zoneTexte: nil, taillePt: nil, tailleMM: l > 0 ? [l, h] : nil)
    }

    public static let tous: [Element] = [
        o("recto-image", "Image du recto", "Recto", 64, 64),
        t("recto-titre", "Titre", "Recto", "titre", 15),
        t("recto-artiste", "Artiste", "Recto", "artiste", 6.5),
        o("recto-logo", "Logo de la maison de disque (recto)", "Recto", 24, 6),
        t("tranche-texte", "Texte de tranche", "Tranche", "tranche", 8),
        o("tranche-logo", "Logo de la maison de disque (tranche)", "Tranche", 12, 8),
        t("tranche-catalogue", "Numéro de catalogue (tranche)", "Tranche", "catalogue", 4.6),
        t("rabat-badge", "Mentions techniques (bande, Dolby)", "Rabat", "badge", 5),
        o("rabat-codes", "Codes (code-barres, QR, Spotify)", "Rabat"),
        t("rabat-droits", "Ligne ℗ ©", "Rabat", "droits", 5),
        t("volets-tracklist", "Tracklist", "Volets", "tracklist", 5.6),
        t("volets-notes", "Notes", "Volets", "notes", 6),
        t("volets-credits", "Crédits", "Volets", "credits", 5),
        t("etiquette-titre", "Titre (étiquette)", "Étiquettes", "etiquette", 10),
        o("etiquette-face", "Lettre de face (étiquette)", "Étiquettes"),
        o("etiquette-pochette", "Pochette (étiquette)", "Étiquettes", 11, 11),
        o("etiquette-longueur", "C60 / NR (étiquette)", "Étiquettes"),
        o("etiquette-bas", "Ligne du bas (étiquette)", "Étiquettes"),
        t("obi-texte", "Texte de l'obi", "Obi", "obi", 9),
    ]

    public static func element(_ id: String) -> Element? { tous.first { $0.id == id } }

    /// Liste pour l'IA : identifiant, nom, format.
    public static var aide: String {
        tous.map { "\($0.id) (\($0.format) : \($0.nom))" }.joined(separator: ", ")
    }
}
