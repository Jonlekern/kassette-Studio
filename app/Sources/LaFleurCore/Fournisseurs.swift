import Foundation

/// Le moteur d'IA qui fait le travail de directeur artistique : Claude (par défaut), GPT ou Gemini.
/// Les trois reçoivent exactement les mêmes demandes : même prompt système (plan de la cassette, conventions,
/// accès complet aux champs et aux images), mêmes images jointes, même schéma JSON imposé, même recherche web.
/// Seul l'appel HTTP change. Documentation suivie (octobre 2026) :
/// - OpenAI : API Responses, `text.format` json_schema strict, outil `web_search` avec `filters.allowed_domains`,
///   cache explicite du prompt système (`prompt_cache_breakpoint`, modèles GPT-5.6 et suivants).
/// - Gemini : API generateContent (stable), `generationConfig.responseJsonSchema`, outil `google_search`
///   (combinable avec le schéma sur Gemini 3), `thinkingConfig.thinkingLevel`, filtres de sécurité au minimum.
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

    /// Modèle conseillé : le plus capable de chaque maison qui gère images, schéma JSON et recherche web.
    public var modeleParDefaut: String {
        switch self {
        case .claude: "claude-opus-5-5"
        case .openai: "gpt-6-astra"
        case .gemini: "gemini-3.8-flash"
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

// MARK: - Réponses des API (décodage)

private struct ReponseOpenAI: Decodable {
    struct Element: Decodable {
        struct Contenu: Decodable { let type: String; let text: String?; let refusal: String? }
        let type: String
        let content: [Contenu]?
    }
    struct Incomplet: Decodable { let reason: String? }
    struct Usage: Decodable {
        struct Details: Decodable { let cached_tokens: Int? }
        let input_tokens: Int?, output_tokens: Int?, input_tokens_details: Details?
    }
    let status: String?
    let output: [Element]
    let incomplete_details: Incomplet?
    let usage: Usage?
}

private struct ReponseGemini: Decodable {
    struct Candidat: Decodable {
        struct Contenu: Decodable {
            struct Partie: Decodable { let text: String?; let thought: Bool? }
            let parts: [Partie]?
        }
        let content: Contenu?
        let finishReason: String?
    }
    struct Retour: Decodable { let blockReason: String? }
    struct Usage: Decodable { let promptTokenCount: Int?, candidatesTokenCount: Int?, thoughtsTokenCount: Int?, cachedContentTokenCount: Int? }
    let candidates: [Candidat]?
    let promptFeedback: Retour?
    let usageMetadata: Usage?
}

extension ClientClaude {
    /// OpenAI, API Responses. Le prompt système va dans un message « developer » marqué comme point de cache :
    /// les demandes suivantes ne repaient pas le plan de la cassette (modèles GPT-5.6 et suivants).
    func demanderOpenAI<T: Decodable>(_ type: T.Type, systeme: String, message: String, schema: [String: Any],
                                      effort: String, images: [Data], rechercheWeb: [String]) async throws -> T {
        var contenu: [[String: Any]] = images.map {
            ["type": "input_image", "image_url": "data:\(Self.typeImage($0));base64,\($0.base64EncodedString())", "detail": "high"]
        }
        contenu.append(["type": "input_text", "text": message])
        var regles: [String: Any] = ["type": "input_text", "text": systeme]
        var corps: [String: Any] = [
            "model": modele,
            "max_output_tokens": 32000,
            "reasoning": ["effort": effort == "high" ? "high" : "medium"],
            "text": ["format": ["type": "json_schema", "name": "reponse", "schema": schema, "strict": true]],
            "store": false,
        ]
        if Self.cacheExplicite(modele) {
            regles["prompt_cache_breakpoint"] = ["mode": "explicit"]
            corps["prompt_cache_options"] = ["mode": "explicit"]
        }
        corps["input"] = [["role": "developer", "content": [regles]], ["role": "user", "content": contenu]]
        if !rechercheWeb.isEmpty {
            corps["tools"] = [["type": "web_search", "filters": ["allowed_domains": rechercheWeb]]]
        }
        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 600
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue("Bearer \(cleAPI)", forHTTPHeaderField: "authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: corps)

        let r = try JSONDecoder().decode(ReponseOpenAI.self, from: try await envoyer(req))
        if let u = r.usage {
            let cache = u.input_tokens_details?.cached_tokens ?? 0
            compteur?.ajouter(entree: (u.input_tokens ?? 0) - cache, sortie: u.output_tokens ?? 0, cacheLu: cache)
        }
        if r.status == "incomplete" {
            if r.incomplete_details?.reason == "content_filter" { throw Erreur.refus("content_filter") }
            throw Erreur.tronquee
        }
        let contenus = r.output.filter { $0.type == "message" }.flatMap { $0.content ?? [] }
        if let refus = contenus.first(where: { $0.type == "refusal" }) { throw Erreur.refus(refus.refusal ?? "refusal") }
        return try decoder(T.self, contenus.filter { $0.type == "output_text" }.compactMap(\.text).joined())
    }

    /// Le cache explicite (`prompt_cache_options`) n'existe qu'à partir de GPT-5.6 ; avant, le cache est automatique.
    static func cacheExplicite(_ modele: String) -> Bool {
        guard modele.hasPrefix("gpt-") else { return false }
        let chiffres = modele.dropFirst(4).prefix { $0.isNumber || $0 == "." }
        let parties = chiffres.split(separator: ".").compactMap { Int($0) }
        guard let majeur = parties.first else { return false }
        return majeur > 5 || (majeur == 5 && (parties.dropFirst().first ?? 0) >= 6)
    }

    /// Gemini, API generateContent. Pas de filtre de domaines pour la recherche Google côté API :
    /// les sites conseillés sont donnés dans la consigne.
    func demanderGemini<T: Decodable>(_ type: T.Type, systeme: String, message: String, schema: [String: Any],
                                      effort: String, images: [Data], rechercheWeb: [String]) async throws -> T {
        var parties: [[String: Any]] = images.map {
            ["inlineData": ["mimeType": Self.typeImage($0), "data": $0.base64EncodedString()]]
        }
        parties.append(["text": message])
        let consigne = rechercheWeb.isEmpty ? systeme
            : systeme + "\nRecherche web : utilise en priorité ces sites et cite-les : " + rechercheWeb.joined(separator: ", ") + "."
        var config: [String: Any] = [
            "responseMimeType": "application/json",
            "responseJsonSchema": schema,
            "maxOutputTokens": 32000,
        ]
        if modele.hasPrefix("gemini-3") { config["thinkingConfig"] = ["thinkingLevel": effort == "high" ? "HIGH" : "MEDIUM"] }
        var corps: [String: Any] = [
            "systemInstruction": ["parts": [["text": consigne]]],
            "contents": [["role": "user", "parts": parties]],
            "generationConfig": config,
            // Accès complet : on n'ajoute aucun filtre au-delà des règles de base de Google.
            "safetySettings": ["HARM_CATEGORY_HATE_SPEECH", "HARM_CATEGORY_SEXUALLY_EXPLICIT",
                               "HARM_CATEGORY_DANGEROUS_CONTENT", "HARM_CATEGORY_HARASSMENT"].map { ["category": $0, "threshold": "BLOCK_NONE"] },
        ]
        // Recherche Google + schéma JSON : seulement sur Gemini 3. Sinon l'API répond 400 et l'appelant réessaie sans web.
        if !rechercheWeb.isEmpty { corps["tools"] = [["googleSearch": [String: Any]()]] }
        let nomModele = modele.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? modele
        var req = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(nomModele):generateContent")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 600
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(cleAPI, forHTTPHeaderField: "x-goog-api-key")
        req.httpBody = try JSONSerialization.data(withJSONObject: corps)

        let r = try JSONDecoder().decode(ReponseGemini.self, from: try await envoyer(req))
        if let u = r.usageMetadata {
            let cache = u.cachedContentTokenCount ?? 0
            compteur?.ajouter(entree: (u.promptTokenCount ?? 0) - cache, sortie: (u.candidatesTokenCount ?? 0) + (u.thoughtsTokenCount ?? 0),
                              cacheLu: cache)
        }
        if let raison = r.promptFeedback?.blockReason { throw Erreur.refus(raison) }
        guard let c = r.candidates?.first else { throw Erreur.reponseVide }
        switch c.finishReason {
        case "MAX_TOKENS": throw Erreur.tronquee
        case "SAFETY", "PROHIBITED_CONTENT", "BLOCKLIST", "RECITATION", "SPII", "LANGUAGE": throw Erreur.refus(c.finishReason ?? "")
        default: break
        }
        // Les pensées du modèle (thought = true) ne font pas partie de la réponse.
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
