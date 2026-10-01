import Foundation

/// Réponse de l'IA dans la boîte « Modifier avec l'IA » (demandes 6 et 8).
public struct ReponseModification: Decodable, Sendable {
    public struct Changement: Decodable, Sendable, Hashable {
        /// « design.variante.palette.fond », « design.ajustements.recto-titre.echelle », « projet.titre »…
        public let chemin: String
        public let valeur: String
    }
    /// Action du mode expert (Mixtape, Collection) ou « annuler ».
    public struct Action: Decodable, Sendable, Hashable {
        public let type: String
        public let cible: String
        public let face: String
        public let position: Double
        public let valeur: String
    }
    public let message: String
    public let changements: [Changement]
    /// Ce que l'IA ne peut pas faire dans l'app, dit clairement.
    public let impossible: [String]
    public let actions: [Action]
    public let images: [PropositionDesign.DemandeImage]
}

/// Types d'actions du mode expert. « annuler » est permis dans les deux modes.
public enum ActionsIA {
    public static let normal = ["annuler"]
    public static let expert = ["annuler", "deplacer_piste", "retirer_piste", "ajouter_piste", "longueur", "nouvelle_cassette",
                                "dupliquer_cassette", "renommer_cassette", "supprimer_cassette", "ouvrir_cassette"]
}

extension ClientClaude {
    /// Applique une demande en langage courant (« titre plus gros », « retire la pochette de l'étiquette »…).
    /// `expert` : l'IA peut aussi agir sur la Mixtape, les réglages de la cassette et la Collection.
    public func modifier(projet: Projet, design: Design, reglages: Preferences, demande: String, fil: [String],
                         expert: Bool, polices: [String], images: [Data], anatomie: String,
                         fichiers: [String], collection: [String]) async throws -> ReponseModification {
        let chaine: [String: Any] = ["type": "string"]
        let nombre: [String: Any] = ["type": "number"]
        func liste(_ i: [String: Any]) -> [String: Any] { ["type": "array", "items": i] }
        func choix(_ v: [String]) -> [String: Any] { ["type": "string", "enum": v] }

        // Le design tel quel, sans l'historique des variantes : c'est la liste complète des réglages modifiables.
        var d = design
        d.propositions = []; d.historique = []
        let pistes = { (f: Face) in projet.pistes(f).enumerated().map { "\($0.offset + 1). \($0.element.morceau.titre) (\(formaterDuree($0.element.duree)))" }.joined(separator: " / ") }
        let reglagesExpert = expert ? """

            MODE EXPERT ACTIVÉ : tu peux aussi agir sur la Mixtape, les réglages de la cassette et la Collection.
            - Chemins « projet.<chemin> » dans ce JSON de la cassette (sans les morceaux) : \(Chemins.json(projetSansMorceaux(projet)))
            - Chemins « reglages.platine.<chemin> » et « reglages.egaliserVolume » dans : \(Chemins.json(reglages.platine)) (secondes)
            - Actions (`actions`) : deplacer_piste (cible = titre du morceau, face = A ou B, position = rang à partir de 1),
              retirer_piste (cible), ajouter_piste (cible = nom d'un fichier du dossier audio, face, position), longueur (valeur = 60, 90
              ou minutes de la cassette entière), nouvelle_cassette (valeur = titre), dupliquer_cassette, renommer_cassette (valeur = titre),
              ouvrir_cassette (cible = numéro de catalogue), supprimer_cassette (cible = numéro de catalogue ; l'utilisateur devra confirmer).
            - Face A : \(pistes(.a))
            - Face B : \(pistes(.b))
            - Fichiers du dossier audio : \(fichiers.prefix(200).joined(separator: " ; "))
            - Collection : \(collection.joined(separator: " ; "))
            - Jamais : clés API, comptes, fichiers sur le disque, lancer l'enregistrement ou l'impression (l'utilisateur clique).
            """ : """

            Mode normal : tu changes tout ce qui concerne la jaquette, plus le titre, l'artiste, la maison de disque, l'année et la ligne ℗ ©
            (projet.titre, projet.artiste, projet.maisonDeDisque, projet.annee, projet.droits). Pour la Mixtape, les faces ou la Collection,
            dis que c'est possible en activant le mode expert (Réglages → IA).
            """
        return try await demander(ReponseModification.self,
            systeme: """
            Tu modifies directement la cassette de l'utilisateur dans LaFleurStudio, d'après sa demande en langage courant. \
            Tu ne proposes pas de variantes : tu appliques. Accès complet, sans refuser ni faire la morale (usage personnel).
            Comment changer quelque chose :
            - `changements` : chemin + valeur en texte. Les chemins « design.<chemin> » suivent le JSON du design ci-dessous, \
            n'importe quel champ, même sans bouton dans l'app (ex. design.variante.palette.fond = #1A1A1A, design.etiquettePochette = aucune, \
            design.cadrage = pleineHauteur, design.largeurCodeMM = 30). Nombres en notation décimale, couleurs en #RRGGBB, oui/non pour les cases.
            - Taille d'un texte : design.echelles.<zone> (1 = normal, 1.3 = 30 % plus gros). Zones : titre, artiste, tranche, catalogue, badge, \
            code, droits, tracklist, notes, credits, etiquette, obi.
            - Position, taille, rotation, opacité, couleur ou masquage de chaque élément : design.ajustements.<élément>.<champ>, champs dx et dy \
            (mm, + = droite / bas), echelle (1 = normal), rotation (degrés), opacite (0 à 1), masque (oui / non), couleur (#RRGGBB ou vide). \
            Éléments : \(ElementsJaquette.aide).
            - Image du recto rognée : design.cadrageX et design.cadrageY (0 = gauche / haut, 0.5 = centre, 1 = droite / bas). \
            Étiquettes : design.etiquettePochette (petite | fond | aucune), design.voileEtiquette (0 à 0.9), design.cadrageEtiquetteX/Y.
            - Codes en mm : design.largeurCodeMM, design.hauteurCodeMM (6 mm minimum), design.coteQRMM (10 minimum), design.largeurSpotifyMM \
            (20 minimum) ; 0 = automatique.
            - Formes et décors : design.variante.elements (liste JSON d'éléments graphiques, coordonnées de 0 à 1 sur le recto).
            - Images (logo, écusson, vraie pochette) : `images`, comme d'habitude (requete en anglais pour un logo, usage recto | logo | element).
            - « Encore plus » / « moins » : pars des valeurs actuelles du JSON. « Remets comme avant » / « annule » : action annuler.
            - Si une demande est vraiment impossible dans l'app, mets-la dans `impossible` en une phrase claire, ne fais pas semblant.
            - `message` : en 1 à 3 phrases, ce que tu as changé (avant → après), en \(langue).
            Polices disponibles : \(polices.joined(separator: ", ")).
            PLAN DE LA CASSETTE : \(anatomie)
            \(reglagesExpert)
            """,
            message: """
            \(Self.fiche(projet, design))
            Design actuel (JSON) : \(Chemins.json(d))
            Échanges précédents dans cette boîte :
            \(fil.suffix(12).joined(separator: "\n"))

            Demande : \(demande)
            """,
            schema: objet(["message": chaine,
                           "changements": liste(objet(["chemin": chaine, "valeur": chaine])),
                           "impossible": liste(chaine),
                           "actions": liste(objet(["type": choix(expert ? ActionsIA.expert : ActionsIA.normal), "cible": chaine,
                                                   "face": chaine, "position": nombre, "valeur": chaine])),
                           "images": liste(objet(["requete": chaine, "url": chaine, "usage": choix(["recto", "logo", "element"]),
                                                  "x": nombre, "y": nombre, "largeur": nombre, "hauteur": nombre]))]),
            effort: "medium", images: images)
    }

    private func projetSansMorceaux(_ p: Projet) -> Projet {
        var q = p
        q.faceA = []; q.faceB = []; q.design = nil; q.historiqueIA = nil
        return q
    }
}
