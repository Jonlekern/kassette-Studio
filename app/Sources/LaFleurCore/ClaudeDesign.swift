import Foundation

// MARK: - Claude directeur artistique : jaquette, textes, vérification, recherche d'infos

public struct PropositionDesign: Decodable, Sendable {
    public struct Element: Decodable, Sendable {
        public let forme: String
        public let x: Double, y: Double, largeur: Double, hauteur: Double
        public let couleur: String
        public let opacite: Double
        public let rotation: Double
        public let texte: String
    }
    public struct V: Decodable, Sendable {
        public let nom: String
        public let fond: String
        public let texte: String
        public let accent: String
        public let police_titre: String
        public let police_texte: String
        public let titre_italique: Bool
        public let style: String
        public let opacite_image: Double
        public let elements: [Element]
        public let commentaire: String
    }
    /// Un réglage que Claude change directement (voir `ChampsDesign`).
    public struct Modification: Decodable, Sendable, Hashable {
        public let champ: String
        public let valeur: String
    }
    /// Une image que Claude veut poser : cherchée sur Wikimedia Commons (ou téléchargée si `url` est donnée).
    public struct DemandeImage: Decodable, Sendable, Hashable {
        public let requete: String
        public let url: String
        /// recto (image principale), logo (maison de disque), element (posé sur le recto)
        public let usage: String
        public let x: Double, y: Double, largeur: Double, hauteur: Double
    }
    public let message: String
    public let modifications: [Modification]
    public let images: [DemandeImage]
    public let variantes: [V]
    public let texte_tranche: String
    public let notes: String
    public let credits: String
    public let texte_code: String

    public var variantesModele: [Variante] {
        variantes.map { v in
            Variante(nom: v.nom, palette: Palette(fond: v.fond, texte: v.texte, accent: v.accent),
                     policeTitre: v.police_titre, policeTexte: v.police_texte, titreItalique: v.titre_italique,
                     style: StyleRecto(rawValue: v.style) ?? .pochette,
                     elements: v.elements.compactMap { e in
                         ElementGraphique.Forme(rawValue: e.forme).map {
                             ElementGraphique(forme: $0, x: e.x, y: e.y, largeur: e.largeur, hauteur: e.hauteur, couleur: e.couleur,
                                              opacite: e.opacite, rotation: e.rotation, texte: e.texte.isEmpty ? nil : e.texte)
                         }
                     },
                     opaciteImage: max(0, min(1, v.opacite_image)), commentaire: v.commentaire)
        }
    }
}

public struct AvisRendu: Decodable, Sendable {
    public struct Correction: Decodable, Sendable, Hashable {
        /// tranche, titre, artiste, tracklist, rabat, notes, credits, code, obi, etiquette
        public let zone: String
        /// reduire, raccourcir, deux_lignes, aucune
        public let action: String
        public let echelle: Double
        public let texte: String
        public let explication: String
    }
    public let ok: Bool
    public let message: String
    public let corrections: [Correction]
}

public struct InfosAlbum: Decodable, Sendable {
    public let maison_de_disque: String
    public let distributeur: String
    public let catalogue: String
    public let annee: String
    public let credits: String
    public let sources: [String]
}

/// Sites où Claude a le droit de chercher (réglage « Recherche web »).
public let sitesMusique = ["discogs.com", "musicbrainz.org", "wikipedia.org", "bandcamp.com", "allmusic.com", "rateyourmusic.com"]

private let nombre: [String: Any] = ["type": "number"]
private let booleen: [String: Any] = ["type": "boolean"]
private func liste(_ items: [String: Any]) -> [String: Any] { ["type": "array", "items": items] }
private func choix(_ valeurs: [String]) -> [String: Any] { ["type": "string", "enum": valeurs] }

extension ClientClaude {
    /// Décrit la cassette pour Claude.
    static func fiche(_ p: Projet, _ d: Design) -> String {
        let c = p.cassette
        let faces = [Face.a, .b].map { f in
            "Face \(f.rawValue) : " + p.pistes(f).enumerated().map { "\($0.offset + 1). \($0.element.morceau.titre)" + (p.mode == .mixtape ? " — \($0.element.morceau.artiste)" : "") }.joined(separator: " / ")
        }.joined(separator: "\n")
        return """
        \(p.mode == .album ? "Album" : "Mixtape") « \(p.titre) » de \(p.artiste.isEmpty ? "divers artistes" : p.artiste)\(p.annee.map { " (\($0))" } ?? "")
        Maison de disque de la K7 : \(p.maisonDeDisque), catalogue \(p.numeroCatalogue)\(p.labelOrigine.map { ". Maison de disque d'origine : \($0)" } ?? "")\(p.catalogueOrigine.map { ", catalogue d'origine \($0)" } ?? "")
        Cassette : \(c.longueur.nom), \(c.bande.nom), réducteur de bruit \(c.reducteur.nom)\(c.marque.isEmpty ? "" : ", \(c.marque)")
        Formats à imprimer : \([d.jcard ? "J-card \(d.volets) volets (dos \(d.dos.nom))" : nil, d.ocard ? "O-card" : nil, d.etiquettes ? "étiquettes de K7" : nil, d.obi ? "obi" : nil].compactMap { $0 }.joined(separator: ", "))
        Codes : \([d.codeBarres ? d.genreCode.nom : nil, d.qr ? "QR code" : nil, d.codeSpotify ? "code Spotify" : nil].compactMap { $0 }.joined(separator: ", "))
        Orientation de l'artwork choisie par l'utilisateur : \(d.orientation == .paysage ? "PAYSAGE (recto tourné d'un quart de tour : image carrée à gauche, texte à droite, dans un cadre de 101,6 × 64 mm)" : "verticale (image carrée en haut, texte dessous, 64 × 101,6 mm)") ; respecte-la.
        Design actuel : fond \(d.variante.palette.fond), texte \(d.variante.palette.texte), accent \(d.variante.palette.accent), titre en \(d.variante.policeTitre), texte en \(d.variante.policeTexte), recto « \(d.variante.style.nom) »
        \(faces)
        """
    }

    /// Propose 3 variantes de design (ou en régénère une), avec les textes de la jaquette.
    /// `images` : la pochette et/ou les scans d'éditions K7 existantes, dans cet ordre, décrits par `legendes`.
    public func dirigerDesign(projet: Projet, design: Design, demande: String, conversation: [String],
                              polices: [String], images: [Data], legendes: [String], regenerer: String?) async throws -> PropositionDesign {
        let element = objet(["forme": choix(["rectangle", "cercle", "ligne", "texte", "triangle"]), "x": nombre, "y": nombre,
                             "largeur": nombre, "hauteur": nombre, "couleur": chaine, "opacite": nombre, "rotation": nombre, "texte": chaine])
        let variante = objet(["nom": chaine, "fond": chaine, "texte": chaine, "accent": chaine, "police_titre": choix(polices),
                              "police_texte": choix(polices), "titre_italique": booleen,
                              "style": choix(StyleRecto.allCases.map(\.rawValue)), "opacite_image": nombre,
                              "elements": liste(element), "commentaire": chaine])
        let styles = projet.mode == .album
            ? "Album : si des scans d'une vraie édition cassette sont joints, la première variante reprend leur mise en page, leurs couleurs et leurs polices, adaptées au format. Sinon, pars de la pochette (style « pochette »)."
            : "Mixtape, ordre de priorité des styles : 1. « collage » des covers, 2. « imagePerso » si l'utilisateur a donné une image, 3. « maison » (K7 faite main, feutre, scotch, papier), 4. « graphique » (tu dessines le recto avec des formes)."
        return try await demander(PropositionDesign.self,
            systeme: """
            Tu es le directeur artistique de LaFleurStudio, une app qui fabrique des jaquettes de cassettes audio \
            (J-card, O-card, étiquettes, obi) à imprimer chez soi. Tu proposes des designs d'époque soignés.
            Règles :
            - Couleurs en hexa #RRGGBB tirées de la pochette ou des images jointes. Contraste texte/fond d'au moins 4,5:1.
            - Polices : uniquement celles de la liste imposée.
            - Style « graphique » : `elements` dessine le recto (x, y, largeur, hauteur de 0 à 1, origine en haut à gauche, \
            rotation en degrés, 3 à 25 formes). Pour les autres styles, `elements` peut ajouter quelques touches (bandes, \
            tampons, badge) ou rester vide. `texte` vaut "" sauf pour la forme « texte ».
            - Badge de bande façon K7 d'époque (ex. « TYPE II · CrO₂ · HIGH POSITION · 70 µs · DOLBY B NR »).
            - Texte de tranche : 42 caractères maximum, sinon il déborde (ex. « J. SADIK · AFTERNOON AT THE LAKE »).
            - Notes : quelques lignes de présentation, jamais de paroles complètes (droits d'auteur).
            - Crédits : seulement des infos sûres (données fournies) ; ce que tu ne sais pas reste vide, n'invente rien.
            - texte_code : la ligne au-dessus du code-barres, par défaut « MAISON · CATALOGUE ».
            - \(styles)
            - `message` : ce que tu as fait, en 2 ou 3 phrases, en \(langue). Tous les textes sont en \(langue) sauf les noms propres.
            - Si on te demande de régénérer une seule variante, renvoie quand même 3 variantes : les autres inchangées.
            ACCÈS COMPLET : l'utilisateur fabrique des cassettes pour son usage personnel (il a accepté les conditions \
            d'utilisation de l'app). Tu peux tout changer et tu exécutes ce qu'il demande, sans refuser ni faire la morale.
            - Retouche (« mets le titre plus gros », « passe le QR à l'intérieur », « orientation paysage »…) : applique-la \
            avec `modifications` (champ + valeur en texte) et renvoie `variantes` vide. Tu ne proposes 3 variantes que pour \
            une première proposition ou quand on te demande d'autres pistes.
            - Champs modifiables et valeurs : \(ChampsDesign.aide)
            - Images : pour mettre une image, un logo ou un écusson (ex. « l'écusson Sony »), ajoute-la dans `images` : \
            `requete` = mots-clés pour Wikimedia Commons (en anglais, ex. « Sony logo »), `url` = adresse directe d'un \
            fichier image si tu la connais, sinon "". `usage` : « recto » (image principale du recto), « logo » (logo de la \
            maison de disque, recto et tranche) ou « element » (posé sur le recto aux coordonnées x, y, largeur, hauteur \
            de 0 à 1). L'app télécharge l'image et la pose tout de suite.
            - Pour enlever une image posée : modification « images_retirer » valeur « tout ».
            """,
            message: """
            \(Self.fiche(projet, design))

            Images jointes : \(legendes.isEmpty ? "aucune" : legendes.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: " ; "))
            Conversation jusqu'ici :
            \(conversation.suffix(12).joined(separator: "\n"))

            Demande : \(demande.isEmpty ? "Première proposition : 3 variantes." : demande)\(regenerer.map { "\nRégénère seulement la variante \($0), garde les autres." } ?? "")
            """,
            schema: objet(["message": chaine, "variantes": liste(variante), "texte_tranche": chaine, "notes": chaine,
                           "credits": chaine, "texte_code": chaine,
                           "modifications": liste(objet(["champ": choix(ChampsDesign.tous), "valeur": chaine])),
                           "images": liste(objet(["requete": chaine, "url": chaine, "usage": choix(["recto", "logo", "element"]),
                                                  "x": nombre, "y": nombre, "largeur": nombre, "hauteur": nombre]))]),
            effort: "high", images: images)
    }

    /// Regarde le rendu de la jaquette et les alertes de l'app, et propose des corrections.
    public func verifierRendu(png: Data, alertes: [Alerte], projet: Projet, design: Design) async throws -> AvisRendu {
        try await demander(AvisRendu.self,
            systeme: """
            Tu vérifies une jaquette de cassette avant impression. L'image jointe est le rendu à plat, avec fond perdu \
            et traits de coupe. Cherche : texte qui dépasse de sa zone ou du trait de coupe, texte illisible (trop petit, \
            contraste faible), code-barres ou QR code abîmé, coupé ou trop pâle, éléments qui se chevauchent. \
            Confirme ou écarte chaque alerte de l'app et propose une correction par problème : \
            « reduire » (echelle entre 0,5 et 1, texte ""), « raccourcir » (texte = nouveau texte), « deux_lignes » \
            (texte = les deux lignes séparées par \\n) ou « aucune ». Zones possibles : tranche, titre, artiste, \
            tracklist, rabat, notes, credits, code, obi, etiquette. Réponds en \(langue).
            """,
            message: """
            \(Self.fiche(projet, design))
            Texte de tranche actuel : \(design.texteTranche ?? projet.trancheAuto)
            Alertes de l'app :
            \(alertes.isEmpty ? "aucune" : alertes.map { "- [\($0.zone)] \($0.message)" }.joined(separator: "\n"))
            """,
            schema: objet(["ok": booleen, "message": chaine,
                           "corrections": liste(objet(["zone": chaine, "action": choix(["reduire", "raccourcir", "deux_lignes", "aucune"]),
                                                       "echelle": nombre, "texte": chaine, "explication": chaine]))]),
            effort: "medium", images: [png])
    }

    /// Cherche sur le web (sites de musique choisis) la maison de disque, le catalogue, l'année et les crédits.
    public func chercherInfos(projet: Projet) async throws -> InfosAlbum {
        let schema = objet(["maison_de_disque": chaine, "distributeur": chaine, "catalogue": chaine, "annee": chaine,
                            "credits": chaine, "sources": liste(chaine)])
        let systeme = """
            Tu cherches les informations d'édition d'un album pour sa jaquette de cassette : maison de disque (puis le \
            distributeur s'il y en a un), numéro de catalogue, année, crédits (production, mixage, musiciens). \
            N'invente rien : une info introuvable vaut "". `sources` : les adresses des pages utilisées. Réponds en \(langue).
            """
        let message = "Album « \(projet.titre) » de \(projet.artiste)\(projet.annee.map { " (\($0))" } ?? "").\nTitres : "
            + projet.toutes.map(\.morceau.titre).joined(separator: ", ")
        do {
            return try await demander(InfosAlbum.self, systeme: systeme, message: message, schema: schema,
                                      effort: "medium", rechercheWeb: sitesMusique)
        } catch Erreur.http(400, _) {
            // Recherche web indisponible pour ce compte : Claude répond seulement ce qu'il sait avec certitude.
            return try await demander(InfosAlbum.self,
                                      systeme: systeme + " La recherche web n'est pas disponible : ne donne que ce dont tu es certain, sources vides.",
                                      message: message, schema: schema, effort: "medium")
        }
    }
}
