import Foundation

/// Tout ce que Claude (et l'utilisateur) peut changer sur une cassette, par son nom.
public enum ChampsDesign {
    public static let tous: [String] = [
        "titre", "artiste", "maison_de_disque", "annee", "texte_tranche", "notes", "credits", "texte_obi", "texte_code",
        "numero_code", "orientation", "cadrage", "style", "fond", "texte", "accent", "police_titre", "police_texte", "titre_italique",
        "opacite_image", "volets", "dos", "reperes", "jcard", "ocard", "etiquettes", "obi", "code_barres", "type_code",
        "place_code", "couleurs_code", "barres_perso", "fond_perso", "chiffres_code", "taille_code", "qr", "contenu_qr",
        "texte_qr", "place_qr", "code_spotify", "rotation_code", "code_x", "code_y", "logo_maison", "lien_paroles",
        "taille_titre", "taille_artiste", "taille_tranche", "taille_tracklist", "taille_notes", "taille_credits",
        "taille_badge", "taille_etiquette", "taille_obi", "images_retirer",
    ]

    public static let aide = """
    titre, artiste, maison_de_disque, annee, texte_tranche, notes, credits, texte_obi, texte_code, numero_code (texte) ; \
    orientation (vertical | paysage) ; cadrage (carre | pleineHauteur) ; style (pochette | collage | imagePerso | maison | graphique) ; fond, texte, accent, \
    barres_perso, fond_perso (#RRGGBB) ; police_titre, police_texte (une police de la liste) ; titre_italique, reperes, \
    jcard, ocard, etiquettes, obi, code_barres, chiffres_code, qr, code_spotify, logo_maison, lien_paroles (oui | non) ; \
    opacite_image (0 à 1) ; volets (3 à 8) ; dos (rectoSeul | court | normal | long | biseaute) ; type_code (ean13 | upcA | \
    code128) ; place_code, place_qr (rabat | tranche | interieur | libre) ; couleurs_code (blanc | design | perso) ; \
    contenu_qr (spotify | lienPerso | texte) ; texte_qr (texte) ; taille_code (0.6 à 1.4) ; rotation_code (0 | 90 | 180 | 270) ; \
    code_x, code_y (mm depuis le coin haut gauche de la J-card) ; taille_titre, taille_artiste, taille_tranche, \
    taille_tracklist, taille_notes, taille_credits, taille_badge, taille_etiquette, taille_obi (échelle, 1 = normal, ex. 1.3) ; \
    images_retirer (tout)
    """

    private static func oui(_ v: String) -> Bool { ["oui", "true", "1", "yes", "vrai"].contains(v.lowercased()) }
    private static func nombre(_ v: String) -> Double? { Double(v.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)) }

    /// Applique une modification. Renvoie false si le champ ou la valeur n'a pas de sens.
    @discardableResult
    public static func appliquer(_ champ: String, _ v: String, projet p: inout Projet, design d: inout Design) -> Bool {
        let n = nombre(v)
        switch champ {
        case "titre": p.titre = v
        case "artiste": p.artiste = v
        case "maison_de_disque": p.maisonDeDisque = v
        case "annee": p.annee = v.isEmpty ? nil : v
        case "texte_tranche": d.texteTranche = v.isEmpty ? nil : v
        case "notes": d.notes = v
        case "credits": d.credits = v
        case "texte_obi": d.obiTexte = v
        case "texte_code": d.texteCode = v.isEmpty ? nil : v
        case "numero_code": d.numeroCode = v
        case "orientation": guard let o = OrientationRecto(rawValue: v) else { return false }; d.orientation = o
        case "cadrage": guard let c = CadrageRecto(rawValue: v) else { return false }; d.cadrage = c
        case "style": guard let s = StyleRecto(rawValue: v) else { return false }; d.variante.style = s
        case "fond": d.variante.palette.fond = v
        case "texte": d.variante.palette.texte = v
        case "accent": d.variante.palette.accent = v
        case "barres_perso": d.barresPerso = v; d.couleursCode = .perso
        case "fond_perso": d.fondPerso = v; d.couleursCode = .perso
        case "police_titre": d.variante.policeTitre = v
        case "police_texte": d.variante.policeTexte = v
        case "titre_italique": d.variante.titreItalique = oui(v)
        case "opacite_image": guard let n else { return false }; d.variante.opaciteImage = max(0.05, min(1, n))
        case "volets": guard let n else { return false }; d.volets = max(3, min(8, Int(n)))
        case "dos": guard let f = FormeDos(rawValue: v) else { return false }; d.dos = f
        case "reperes": d.reperes = oui(v)
        case "jcard": d.jcard = oui(v)
        case "ocard": d.ocard = oui(v)
        case "etiquettes": d.etiquettes = oui(v)
        case "obi": d.obi = oui(v)
        case "code_barres": d.codeBarres = oui(v)
        case "type_code": guard let g = CodeBarres1D.Genre(rawValue: v) else { return false }; d.genreCode = g
        case "place_code": guard let pl = PlaceCode(rawValue: v) else { return false }; d.placeCode = pl
        case "place_qr": guard let pl = PlaceCode(rawValue: v) else { return false }; d.placeQR = pl
        case "couleurs_code": guard let c = CouleursCode(rawValue: v) else { return false }; d.couleursCode = c
        case "chiffres_code": d.chiffresCode = oui(v)
        case "taille_code": guard let n else { return false }; d.echelleCode = max(0.5, min(1.6, n))
        case "qr": d.qr = oui(v)
        case "contenu_qr": guard let c = ContenuQR(rawValue: v) else { return false }; d.contenuQR = c
        case "texte_qr": d.texteQR = v
        case "code_spotify": d.codeSpotify = oui(v)
        case "rotation_code": guard let n else { return false }; d.rotationCode = n
        case "code_x": guard let n else { return false }; d.codeX = n; if d.placeCode != .libre && d.placeQR != .libre { d.placeCode = .libre }
        case "code_y": guard let n else { return false }; d.codeY = n; if d.placeCode != .libre && d.placeQR != .libre { d.placeCode = .libre }
        case "logo_maison": d.afficherLogoMaison = oui(v)
        case "lien_paroles": d.lienParoles = oui(v)
        case "images_retirer": d.imagesPosees = []
        default:
            guard champ.hasPrefix("taille_"), let n else { return false }
            d.echelles[String(champ.dropFirst("taille_".count))] = max(0.3, min(3, n))
        }
        return true
    }
}

/// Une image posée sur le recto (coordonnées de 0 à 1 dans le recto).
public struct ImagePosee: Codable, Hashable, Sendable, Identifiable {
    public var id = UUID()
    public var url: URL
    public var source: String
    public var x: Double, y: Double, largeur: Double, hauteur: Double
    public init(url: URL, source: String, x: Double, y: Double, largeur: Double, hauteur: Double) {
        self.url = url; self.source = source; self.x = x; self.y = y; self.largeur = largeur; self.hauteur = hauteur
    }
}

/// Wikimedia Commons : images et logos, sans compte, avec leur page source et leur licence.
public enum Commons {
    public struct Resultat: Hashable, Sendable {
        public let titre: String
        public let image: URL
        public let page: URL
        public let licence: String
    }

    public static func chercher(_ requete: String, limite: Int = 8) async throws -> [Resultat] {
        var c = URLComponents(string: "https://commons.wikimedia.org/w/api.php")!
        c.queryItems = [
            URLQueryItem(name: "action", value: "query"), URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "generator", value: "search"), URLQueryItem(name: "gsrnamespace", value: "6"),
            URLQueryItem(name: "gsrsearch", value: requete), URLQueryItem(name: "gsrlimit", value: String(limite)),
            URLQueryItem(name: "prop", value: "imageinfo"), URLQueryItem(name: "iiprop", value: "url|extmetadata|mime"),
            URLQueryItem(name: "iiurlwidth", value: "1200"),
        ]
        var req = URLRequest(url: c.url!)
        req.setValue("LaFleurStudio/0.1 ( https://lafleurstudio.ch )", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: req)
        return decoder(data)
    }

    static func decoder(_ data: Data) -> [Resultat] {
        struct R: Decodable {
            struct Q: Decodable { let pages: [String: P]? }
            struct P: Decodable {
                struct I: Decodable {
                    struct M: Decodable { struct V: Decodable { let value: String? }; let LicenseShortName: V? }
                    let thumburl: String?; let url: String?; let descriptionurl: String?; let mime: String?; let extmetadata: M?
                }
                let title: String; let index: Int?; let imageinfo: [I]?
            }
            let query: Q?
        }
        guard let r = try? JSONDecoder().decode(R.self, from: data), let pages = r.query?.pages else { return [] }
        return pages.values.sorted { ($0.index ?? 0) < ($1.index ?? 0) }.compactMap { p in
            guard let i = p.imageinfo?.first, (i.mime ?? "").hasPrefix("image/"),
                  let img = URL(string: i.thumburl ?? i.url ?? ""), let page = URL(string: i.descriptionurl ?? "") else { return nil }
            return Resultat(titre: p.title.replacingOccurrences(of: "File:", with: ""), image: img, page: page,
                            licence: i.extmetadata?.LicenseShortName?.value ?? "")
        }
    }
}
