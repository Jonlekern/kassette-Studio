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
            case .http(let code, let msg): String(localized: "Claude a répondu \(code) : \(msg)")
            case .refus(let raison): String(localized: "Claude a refusé la demande (\(raison)).")
            case .reponseVide: String(localized: "Réponse de Claude vide ou illisible.")
            case .tronquee: String(localized: "Réponse de Claude coupée (trop longue).")
            }
        }
    }

    /// Envoie une demande et décode la réponse JSON imposée par `schema`.
    /// `images` : JPEG ou PNG joints au message (pochettes, scans de K7, rendu de la jaquette).
    /// `rechercheWeb` : domaines où Claude peut chercher (vide = pas de recherche).
    public func demander<T: Decodable>(_ type: T.Type, systeme: String, message: String,
                                       schema: [String: Any], effort: String = "medium",
                                       images: [Data] = [], rechercheWeb: [String] = []) async throws -> T {
        var contenu: [[String: Any]] = images.map {
            ["type": "image", "source": ["type": "base64", "media_type": Self.typeImage($0), "data": $0.base64EncodedString()]]
        }
        contenu.append(["type": "text", "text": message])
        var messages: [[String: Any]] = [["role": "user", "content": contenu]]
        var corps: [String: Any] = [
            "model": modele,
            "max_tokens": 16000,
            "fallbacks": "default",
            "thinking": ["type": "adaptive"],
            "output_config": ["effort": effort, "format": ["type": "json_schema", "schema": schema]],
            "system": systeme,
        ]
        if !rechercheWeb.isEmpty {
            corps["tools"] = [["type": "web_search_20250305", "name": "web_search", "max_uses": 5, "allowed_domains": rechercheWeb]]
        }

        // La recherche web peut mettre le tour en pause : on relance avec ce qui a déjà été fait.
        for _ in 0..<5 {
            corps["messages"] = messages
            var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
            req.httpMethod = "POST"
            req.timeoutInterval = 600
            req.setValue("application/json", forHTTPHeaderField: "content-type")
            req.setValue(cleAPI, forHTTPHeaderField: "x-api-key")
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            // Si les garde-fous refusent une demande, l'API la rejoue sur le modèle de repli recommandé.
            req.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
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
            if r.stop_reason == "pause_turn",
               let brut = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let blocs = brut["content"] {
                messages.append(["role": "assistant", "content": blocs])
                continue
            }
            // Seul le texte qui suit le dernier bloc d'outil est la réponse JSON.
            var texte = ""
            for b in r.content { if b.type == "text" { texte += b.text ?? "" } else { texte = "" } }
            guard let json = texte.data(using: .utf8), !texte.isEmpty else { throw Erreur.reponseVide }
            do { return try JSONDecoder().decode(T.self, from: json) } catch { throw Erreur.reponseVide }
        }
        throw Erreur.reponseVide
    }

    static func typeImage(_ d: Data) -> String {
        let o = [UInt8](d.prefix(4))
        if o.starts(with: [0x89, 0x50]) { return "image/png" }
        if o.starts(with: [0x47, 0x49]) { return "image/gif" }
        if o.count == 4, o[0] == 0x52, o[1] == 0x49 { return "image/webp" }
        return "image/jpeg"
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

func objet(_ proprietes: [String: Any]) -> [String: Any] {
    ["type": "object", "properties": proprietes, "required": Array(proprietes.keys).sorted(), "additionalProperties": false]
}
let chaine: [String: Any] = ["type": "string"]
let entiers: [String: Any] = ["type": "array", "items": ["type": "integer"]]

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
