import Foundation

/// Client minimal de l'API Messages d'Anthropic (HTTP brut : pas de SDK Swift officiel).
/// Toutes les réponses sont demandées en JSON strict via `output_config.format`.
public struct ClientClaude: Sendable {
    public var cleAPI: String
    public var modele = "claude-opus-5-5"
    /// Langue des réponses (celle de l'app).
    public var langue = "français"
    public init(cleAPI: String, langue: String = "français") { self.cleAPI = cleAPI; self.langue = langue }

    /// Vérifie la clé sans rien consommer (liste des modèles).
    public func testerCle() async throws {
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/models?limit=1")!)
        req.setValue(cleAPI, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        let (data, rep) = try await URLSession.shared.data(for: req)
        let code = (rep as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else { throw Erreur.http(code, String(decoding: data, as: UTF8.self)) }
    }

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

// MARK: - Services rendus par Claude pour la mixtape

public struct PropositionMixtape: Decodable, Sendable {
    public struct Idee: Decodable, Sendable, Hashable { public let artiste: String; public let titre: String }
    public let titre: String
    public let morceaux: [Idee]
}

public struct OrdreFaces: Decodable, Sendable {
    public let face_a: [Int]
    public let face_b: [Int]
    public let commentaire: String
}

private func objet(_ proprietes: [String: Any]) -> [String: Any] {
    ["type": "object", "properties": proprietes, "required": Array(proprietes.keys).sorted(), "additionalProperties": false]
}
private let chaine: [String: Any] = ["type": "string"]
private let entiers: [String: Any] = ["type": "array", "items": ["type": "integer"]]

private func ligne(_ i: Int, _ p: Piste) -> String {
    "\(i). \(p.morceau.artiste) - \(p.morceau.titre) (\(formaterDuree(p.duree)))"
}

extension ClientClaude {
    /// Propose une sélection pour une mixtape. Les idées sont ensuite cherchées sur Spotify et cochées par l'utilisateur.
    public func composer(ambiance: String, cassette: Cassette, reglages: ReglagesPlatine, deja: [Piste]) async throws -> PropositionMixtape {
        let minutes = cassette.longueur.minutesParFace
        let dejaTexte = deja.isEmpty ? "" : "\n\nDéjà sur la cassette (ne les repropose pas) :\n"
            + deja.enumerated().map { ligne($0.offset, $0.element) }.joined(separator: "\n")
        return try await demander(PropositionMixtape.self,
            systeme: """
            Tu composes des mixtapes sur cassette audio. Tu proposes uniquement des morceaux qui existent vraiment \
            sur Spotify, avec l'artiste et le titre exacts. Pense à l'enchaînement. Réponds en \(langue).
            """,
            message: """
            Ambiance : \(ambiance)
            Cassette \(cassette.longueur.nom) : 2 faces de \(minutes) min. Propose de quoi remplir les deux faces, \
            plus 3 ou 4 titres en réserve, et un titre de mixtape court.\(dejaTexte)
            """,
            schema: objet(["titre": chaine, "morceaux": ["type": "array", "items": objet(["artiste": chaine, "titre": chaine])]]),
            effort: "high")
    }

    /// Ordonne et répartit les pistes sur les deux faces sans dépasser la bande.
    public func equilibrer(_ pistes: [Piste], cassette: Cassette, reglages r: ReglagesPlatine, garderOrdre: Bool) async throws -> OrdreFaces {
        let place = Int(Faces.capacite(cassette, r) - r.amorce)
        return try await demander(OrdreFaces.self,
            systeme: """
            Tu prépares l'enregistrement d'une cassette audio. Réponds avec les indices des morceaux, dans l'ordre \
            d'écoute, pour chaque face. Contrainte stricte par face : somme des durées + \(Int(r.blanc)) s entre \
            chaque morceau ≤ \(place) s. Vérifie tes additions. Vise des faces de durées proches. \
            \(garderOrdre ? "Garde l'ordre donné : choisis seulement où couper entre la face A et la face B." : "Cherche un enchaînement fluide.") \
            Le commentaire, en deux phrases, est en \(langue).
            """,
            message: "Cassette \(cassette.longueur.nom), \(place) s utiles par face.\n"
                + pistes.enumerated().map { ligne($0.offset, $0.element) }.joined(separator: "\n"),
            schema: objet(["face_a": entiers, "face_b": entiers, "commentaire": chaine]),
            effort: "high")
    }
}
