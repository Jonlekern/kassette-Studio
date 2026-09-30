import Foundation

/// Client minimal de l'API Messages d'Anthropic (HTTP brut : pas de SDK Swift officiel).
/// Toutes les réponses sont demandées en JSON strict via `output_config.format`.
public struct ClientClaude: Sendable {
    public var cleAPI: String
    public var modele = "claude-opus-5-5"
    public init(cleAPI: String) { self.cleAPI = cleAPI }

    public enum Erreur: LocalizedError {
        case http(Int, String), refus(String), reponseVide, tronquee
        public var errorDescription: String? {
            switch self {
            case .http(let code, let msg): "Claude a répondu \(code) : \(msg)"
            case .refus(let raison): "Claude a refusé la demande (\(raison))."
            case .reponseVide: "Réponse de Claude vide ou illisible."
            case .tronquee: "Réponse de Claude coupée (trop longue)."
            }
        }
    }

    /// Envoie une demande et décode la réponse JSON imposée par `schema`.
    public func demander<T: Decodable>(_ type: T.Type, systeme: String, message: String,
                                       schema: [String: Any], effort: String = "medium") async throws -> T {
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 600
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(cleAPI, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        // Si les garde-fous refusent une demande, l'API la rejoue sur le modèle de repli recommandé.
        req.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        let corps: [String: Any] = [
            "model": modele,
            "max_tokens": 16000,
            "fallbacks": "default",
            "thinking": ["type": "adaptive"],
            "output_config": ["effort": effort, "format": ["type": "json_schema", "schema": schema]],
            "system": systeme,
            "messages": [["role": "user", "content": message]],
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: corps)

        let (data, rep) = try await URLSession.shared.data(for: req)
        let code = (rep as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else {
            let msg = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])
                .flatMap { ($0["error"] as? [String: Any])?["message"] as? String } ?? String(decoding: data, as: UTF8.self)
            throw Erreur.http(code, msg)
        }
        let r = try JSONDecoder().decode(ReponseMessages.self, from: data)
        if r.stop_reason == "refusal" { throw Erreur.refus(r.stop_details?.category ?? "sans catégorie") }
        if r.stop_reason == "max_tokens" { throw Erreur.tronquee }
        let texte = r.content.filter { $0.type == "text" }.compactMap(\.text).joined()
        guard let json = texte.data(using: .utf8), !texte.isEmpty else { throw Erreur.reponseVide }
        do { return try JSONDecoder().decode(T.self, from: json) } catch { throw Erreur.reponseVide }
    }

    private struct ReponseMessages: Decodable {
        struct Bloc: Decodable { let type: String; let text: String? }
        struct Details: Decodable { let category: String? }
        let content: [Bloc]
        let stop_reason: String?
        let stop_details: Details?
    }
}

// MARK: - Les trois services rendus par Claude

public struct PropositionMixtape: Decodable, Sendable {
    public struct Idee: Decodable, Sendable { public let artiste: String; public let titre: String }
    public let titre: String
    public let morceaux: [Idee]
}

public struct OrdreFaces: Decodable, Sendable {
    public let face_a: [Int]
    public let face_b: [Int]
    public let commentaire: String
}

public struct TextesJaquette: Decodable, Sendable {
    public let titre: String
    public let artiste: String
    public let tranche: String
    public let rabat: String
    public let production: String
}

private func objet(_ proprietes: [String: Any]) -> [String: Any] {
    ["type": "object", "properties": proprietes, "required": Array(proprietes.keys).sorted(), "additionalProperties": false]
}
private let chaine: [String: Any] = ["type": "string"]
private let entiers: [String: Any] = ["type": "array", "items": ["type": "integer"]]

private func ligne(_ i: Int, _ m: Morceau) -> String {
    "\(i). \(m.artiste) - \(m.titre) (\(formaterDuree(m.duree))) — album « \(m.album) »\(m.annee.map { ", \($0)" } ?? "")"
}

extension ClientClaude {
    /// Compose une tracklist à partir d'une ambiance. Les morceaux seront ensuite cherchés sur Spotify.
    public func composer(ambiance: String, cassette: TypeCassette, dejaChoisis: [Morceau]) async throws -> PropositionMixtape {
        let minutes = Int(cassette.secondesParFace / 60)
        let deja = dejaChoisis.isEmpty ? "" :
            "\n\nMorceaux déjà sur la cassette (ne les repropose pas, prolonge leur esprit) :\n"
            + dejaChoisis.enumerated().map { ligne($0.offset, $0.element) }.joined(separator: "\n")
        return try await demander(
            PropositionMixtape.self,
            systeme: """
            Tu es un digger passionné qui compose des mixtapes sur cassette audio. Tu proposes uniquement des morceaux \
            qui existent vraiment et qu'on trouve sur Spotify, avec le nom d'artiste et le titre exacts tels qu'ils y \
            apparaissent (pas de « remastered », pas de numéro de piste). Pense à l'enchaînement : ouverture, montée, \
            respiration, final de face A qui donne envie de retourner la cassette, puis face B.
            """,
            message: """
            Ambiance demandée : \(ambiance)
            Cassette : \(cassette.rawValue), soit 2 faces de \(minutes) minutes. Propose assez de morceaux pour remplir \
            les deux faces, plus 3 ou 4 de rab (les durées exactes seront vérifiées ensuite sur Spotify). Donne aussi un \
            titre de mixtape court.\(deja)
            """,
            schema: objet([
                "titre": chaine,
                "morceaux": ["type": "array", "items": objet(["artiste": chaine, "titre": chaine])],
            ]),
            effort: "high")
    }

    /// Ordonne et répartit les morceaux sur deux faces sans dépasser la durée de bande.
    public func equilibrer(_ morceaux: [Morceau], cassette: TypeCassette, reglages r: ReglagesEnregistrement) async throws -> OrdreFaces {
        let place = Int(cassette.secondesParFace - r.amorce)
        return try await demander(
            OrdreFaces.self,
            systeme: """
            Tu prépares l'enregistrement d'une cassette audio. Tu réponds avec les indices des morceaux, dans l'ordre \
            d'écoute, pour chaque face. Contrainte stricte : pour une face, somme des durées + \(Int(r.blanc)) s de blanc \
            entre chaque morceau ≤ \(place) s. Vérifie tes additions. Si tout ne rentre pas, laisse de côté les morceaux \
            qui servent le moins la mixtape. Cherche un enchaînement fluide (tempo, tonalité, énergie) et des faces de \
            durées proches, pour qu'il reste le moins de bande vide possible.
            """,
            message: """
            Cassette \(cassette.rawValue) : \(place) s utiles par face.
            Morceaux (indice. artiste - titre (durée m:ss)) :
            \(morceaux.enumerated().map { ligne($0.offset, $0.element) }.joined(separator: "\n"))

            Dans « commentaire », explique en deux phrases l'enchaînement choisi, en français.
            """,
            schema: objet(["face_a": entiers, "face_b": entiers, "commentaire": chaine]),
            effort: "high")
    }

    /// Rédige les textes de jaquette pour Kassette Creator.
    public func jaquette(_ mix: Mixtape, idee: String) async throws -> TextesJaquette {
        func face(_ nom: String, _ l: [Morceau]) -> String {
            "Face \(nom) :\n" + l.enumerated().map { ligne($0.offset + 1, $0.element) }.joined(separator: "\n")
        }
        return try await demander(
            TextesJaquette.self,
            systeme: """
            Tu écris les textes d'une jaquette (J-card) de cassette mixtape faite maison, en français, avec un ton \
            complice, un peu rétro. Textes courts : ils sont imprimés en petit.
            """,
            message: """
            \(face("A", mix.faceA))

            \(face("B", mix.faceB))

            Titre actuel : \(mix.jaquette.titre)
            Envie de l'auteur : \(idee.isEmpty ? "libre" : idee)

            Remplis :
            - titre : titre de la mixtape, 3 mots maximum
            - artiste : sous-titre ou signature (ex. « compilée par Johnny »)
            - tranche : texte de la tranche, 40 caractères maximum
            - rabat : 2 ou 3 phrases de liner notes sur l'esprit de la cassette
            - production : une ligne façon crédits (année, lieu, type de bande)
            """,
            schema: objet(["titre": chaine, "artiste": chaine, "tranche": chaine, "rabat": chaine, "production": chaine]))
    }
}
