import Foundation

/// Discogs : éditions (dont les cassettes), maisons de disque, catalogues et photos des vraies K7.
/// Il faut un jeton personnel gratuit (discogs.com → Settings → Developers → Generate new token).
public actor ClientDiscogs {
    public struct Edition: Identifiable, Hashable, Sendable {
        public let id: Int
        public let titre: String
        public let annee: String?
        public let maisonsDeDisque: [String]
        public let catalogue: String?
        public let formats: [String]
        public let pays: String?
        public let vignette: URL?
        public let image: URL?
        public let page: URL
    }

    public struct Photo: Hashable, Sendable { public let url: URL; public let genre: String }

    /// Photos, crédits (rôle : nom) et notes de pochette d'une édition.
    public struct Detail: Sendable {
        public let photos: [Photo]
        public let credits: String
        public let notes: String
    }

    public enum Erreur: LocalizedError {
        case pasDeJeton, http(Int)
        public var errorDescription: String? {
            switch self {
            case .pasDeJeton: String(localized: "Ajoute ton jeton Discogs dans Réglages → Sources.")
            case .http(401): String(localized: "Jeton Discogs refusé : vérifie-le dans Réglages → Sources.")
            case .http(let c): String(localized: "Discogs a répondu \(c). Réessaie dans un instant.")
            }
        }
    }

    private let jeton: String
    public init(jeton: String) { self.jeton = jeton }

    private func get(_ chemin: String, _ params: [String: String] = [:]) async throws -> Data {
        guard !jeton.isEmpty else { throw Erreur.pasDeJeton }
        var c = URLComponents(string: "https://api.discogs.com" + chemin)!
        if !params.isEmpty { c.queryItems = params.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) } }
        var req = URLRequest(url: c.url!)
        req.setValue("STUDIOLAFLEUR/0.1 +https://lafleurstudio.ch", forHTTPHeaderField: "User-Agent")
        req.setValue("Discogs token=\(jeton)", forHTTPHeaderField: "Authorization")
        let (data, rep) = try await URLSession.shared.data(for: req)
        let code = (rep as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else { throw Erreur.http(code) }
        return data
    }

    /// Éditions d'un album ; `cassetteSeulement` pour ne garder que les K7.
    public func chercher(artiste: String, album: String, cassetteSeulement: Bool = true) async throws -> [Edition] {
        var p = ["type": "release", "artist": artiste, "release_title": album, "per_page": "20"]
        if cassetteSeulement { p["format"] = "Cassette" }
        let r = try JSONDecoder().decode(RechercheAPI.self, from: try await get("/database/search", p))
        return r.results.map { $0.edition }
    }

    /// Toutes les photos d'une édition (recto, dos, J-card, cassette…), ses crédits et ses notes.
    public func detail(_ id: Int) async throws -> Detail {
        try Self.decoderDetail(try await get("/releases/\(id)"))
    }

    static func decoderDetail(_ d: Data) throws -> Detail {
        let r = try JSONDecoder().decode(EditionAPI.self, from: d)
        let photos = (r.images ?? []).compactMap { i in URL(string: i.uri).map { Photo(url: $0, genre: i.type ?? "") } }
        // Regroupe les crédits par rôle : « Producer : A, B ».
        var parRole: [(String, [String])] = []
        for a in r.extraartists ?? [] {
            let nom = a.name.replacingOccurrences(of: #" \(\d+\)$"#, with: "", options: .regularExpression)
            let role = a.role ?? ""
            if let i = parRole.firstIndex(where: { $0.0 == role }) { parRole[i].1.append(nom) } else { parRole.append((role, [nom])) }
        }
        let credits = parRole.map { $0.0.isEmpty ? $0.1.joined(separator: ", ") : "\($0.0) : \($0.1.joined(separator: ", "))" }.joined(separator: "\n")
        return Detail(photos: photos, credits: credits, notes: r.notes ?? "")
    }

    static func decoderRecherche(_ d: Data) throws -> [Edition] { try JSONDecoder().decode(RechercheAPI.self, from: d).results.map { $0.edition } }
}

private struct RechercheAPI: Decodable {
    struct R: Decodable {
        let id: Int
        let title: String
        let year: String?
        let label: [String]?
        let catno: String?
        let format: [String]?
        let country: String?
        let thumb: String?
        let cover_image: String?
        let uri: String?
        var edition: ClientDiscogs.Edition {
            ClientDiscogs.Edition(id: id, titre: title, annee: year, maisonsDeDisque: label ?? [], catalogue: catno,
                                  formats: format ?? [], pays: country, vignette: thumb.flatMap(URL.init(string:)),
                                  image: cover_image.flatMap(URL.init(string:)),
                                  page: URL(string: "https://www.discogs.com" + (uri ?? "/release/\(id)"))!)
        }
    }
    let results: [R]
}

private struct EditionAPI: Decodable {
    struct I: Decodable { let uri: String; let type: String? }
    struct A: Decodable { let name: String; let role: String? }
    let images: [I]?
    let extraartists: [A]?
    let notes: String?
}
