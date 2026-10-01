import Foundation

/// Le moteur d'IA qui fait le travail de directeur artistique : Claude (par défaut), GPT ou Gemini.
/// Les trois reçoivent les mêmes demandes (texte, images, schéma JSON imposé) ; seul l'appel HTTP change.
public enum FournisseurIA: String, Codable, CaseIterable, Sendable {
    case claude, openai, gemini

    public var nom: String {
        switch self {
        case .claude: "Claude"
        case .openai: "GPT"
        case .gemini: "Gemini"
        }
    }

    public var societe: String {
        switch self {
        case .claude: "Anthropic"
        case .openai: "OpenAI"
        case .gemini: "Google"
        }
    }

    public var modeleParDefaut: String {
        switch self {
        case .claude: "claude-opus-5-5"
        case .openai: "gpt-5"
        case .gemini: "gemini-2.5-pro"
        }
    }

    /// Début d'une clé, pour l'invite du champ.
    public var inviteCle: String {
        switch self {
        case .claude: "sk-ant-…"
        case .openai: "sk-…"
        case .gemini: "AIza…"
        }
    }

    /// Page où créer une clé API.
    public var pageCles: URL {
        switch self {
        case .claude: URL(string: "https://platform.claude.com/settings/keys")!
        case .openai: URL(string: "https://platform.openai.com/api-keys")!
        case .gemini: URL(string: "https://aistudio.google.com/apikey")!
        }
    }

    /// Nom de l'entrée dans le trousseau du Mac.
    public var entreeTrousseau: String { self == .claude ? "claude" : rawValue }
}

extension ClientClaude {
    /// Envoie la demande à OpenAI (API Responses) avec sortie JSON stricte.
    func demanderOpenAI<T: Decodable>(_ type: T.Type, systeme: String, message: String, schema: [String: Any],
                                      effort: String, images: [Data], rechercheWeb: [String]) async throws -> T {
        var contenu: [[String: Any]] = images.map {
            ["type": "input_image", "image_url": "data:\(Self.typeImage($0));base64,\($0.base64EncodedString())"]
        }
        contenu.append(["type": "input_text", "text": message])
        var corps: [String: Any] = [
            "model": modele,
            "instructions": systeme,
            "input": [["role": "user", "content": contenu]],
            "max_output_tokens": 16000,
            "reasoning": ["effort": effort == "high" ? "high" : "medium"],
            "text": ["format": ["type": "json_schema", "name": "reponse", "schema": schema, "strict": true]],
        ]
        if !rechercheWeb.isEmpty {
            corps["tools"] = [["type": "web_search", "filters": ["allowed_domains": rechercheWeb]]]
        }
        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 600
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue("Bearer \(cleAPI)", forHTTPHeaderField: "authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: corps)
        let data = try await envoyer(req)

        struct Reponse: Decodable {
            struct Element: Decodable {
                struct Contenu: Decodable { let type: String; let text: String?; let refusal: String? }
                let type: String
                let content: [Contenu]?
            }
            struct Incomplet: Decodable { let reason: String? }
            let status: String?
            let output: [Element]
            let incomplete_details: Incomplet?
        }
        let r = try JSONDecoder().decode(Reponse.self, from: data)
        if r.status == "incomplete" {
            if r.incomplete_details?.reason == "content_filter" { throw Erreur.refus("content_filter") }
            throw Erreur.tronquee
        }
        let contenus = r.output.filter { $0.type == "message" }.flatMap { $0.content ?? [] }
        if let refus = contenus.first(where: { $0.type == "refusal" }) { throw Erreur.refus(refus.refusal ?? "refusal") }
        return try decoder(T.self, contenus.filter { $0.type == "output_text" }.compactMap(\.text).joined())
    }

    /// Envoie la demande à Gemini (generateContent) avec sortie JSON imposée par le schéma.
    func demanderGemini<T: Decodable>(_ type: T.Type, systeme: String, message: String, schema: [String: Any],
                                      images: [Data], rechercheWeb: [String]) async throws -> T {
        var parties: [[String: Any]] = images.map {
            ["inline_data": ["mime_type": Self.typeImage($0), "data": $0.base64EncodedString()]]
        }
        parties.append(["text": message])
        var corps: [String: Any] = [
            "systemInstruction": ["parts": [["text": systeme]]],
            "contents": [["role": "user", "parts": parties]],
            "generationConfig": ["responseMimeType": "application/json", "responseJsonSchema": schema, "maxOutputTokens": 16000],
        ]
        // Recherche Google : si le modèle la refuse avec un schéma imposé, l'appelant réessaie sans (erreur 400).
        if !rechercheWeb.isEmpty { corps["tools"] = [["google_search": [String: Any]()]] }
        let nomModele = modele.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? modele
        var req = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(nomModele):generateContent")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 600
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(cleAPI, forHTTPHeaderField: "x-goog-api-key")
        req.httpBody = try JSONSerialization.data(withJSONObject: corps)
        let data = try await envoyer(req)

        struct Reponse: Decodable {
            struct Candidat: Decodable {
                struct Contenu: Decodable { struct Partie: Decodable { let text: String?; let thought: Bool? }; let parts: [Partie]? }
                let content: Contenu?
                let finishReason: String?
            }
            struct Blocage: Decodable { let blockReason: String? }
            let candidates: [Candidat]?
            let promptFeedback: Blocage?
        }
        let r = try JSONDecoder().decode(Reponse.self, from: data)
        if let raison = r.promptFeedback?.blockReason { throw Erreur.refus(raison) }
        guard let c = r.candidates?.first else { throw Erreur.reponseVide }
        switch c.finishReason {
        case "MAX_TOKENS": throw Erreur.tronquee
        case "SAFETY", "PROHIBITED_CONTENT", "BLOCKLIST", "RECITATION": throw Erreur.refus(c.finishReason ?? "")
        default: break
        }
        let texte = (c.content?.parts ?? []).filter { $0.thought != true }.compactMap(\.text).joined()
        return try decoder(T.self, texte)
    }

    /// Vérifie une clé OpenAI ou Gemini sans rien consommer (liste des modèles).
    func testerCleAutre() async throws {
        var req: URLRequest
        switch fournisseur {
        case .openai:
            req = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
            req.setValue("Bearer \(cleAPI)", forHTTPHeaderField: "authorization")
        default:
            req = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models?pageSize=1")!)
            req.setValue(cleAPI, forHTTPHeaderField: "x-goog-api-key")
        }
        _ = try await envoyer(req)
    }

    /// Appel HTTP commun : renvoie le corps si 200, sinon une erreur avec le message du service.
    private func envoyer(_ req: URLRequest) async throws -> Data {
        let (data, rep) = try await URLSession.shared.data(for: req)
        let code = (rep as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else {
            let msg = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])
                .flatMap { ($0["error"] as? [String: Any])?["message"] as? String } ?? String(decoding: data, as: UTF8.self)
            throw Erreur.http(code, "\(fournisseur.nom) — \(msg)")
        }
        return data
    }

    /// Le JSON peut arriver entouré de ```json … ``` : on garde ce qui va de la première { à la dernière }.
    func decoder<T: Decodable>(_ type: T.Type, _ texte: String) throws -> T {
        var t = texte.trimmingCharacters(in: .whitespacesAndNewlines)
        if let debut = t.firstIndex(of: "{"), let fin = t.lastIndex(of: "}"), debut < fin { t = String(t[debut...fin]) }
        guard !t.isEmpty, let json = t.data(using: .utf8) else { throw Erreur.reponseVide }
        do { return try JSONDecoder().decode(T.self, from: json) } catch { throw Erreur.reponseVide }
    }
}
