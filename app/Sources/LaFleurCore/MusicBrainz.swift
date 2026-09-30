import Foundation

/// MusicBrainz : base musicale libre et gratuite, sans compte. Tracklist, durées, maison de disque,
/// numéro de catalogue, code-barres ; pochette via le Cover Art Archive.
/// Règles du service : un User-Agent qui identifie l'app, et au plus une requête par seconde.
public actor ClientMusicBrainz {
    public struct Album: Identifiable, Hashable, Sendable {
        public let id: String
        public let titre: String
        public let artiste: String
        public let date: String?
        public let maisonDeDisque: String?
        public let catalogue: String?
        public let formats: [String]
        public let nombreTitres: Int
        public var annee: String? { date.map { String($0.prefix(4)) } }
        /// Pochette 500 px du Cover Art Archive (redirection gérée par URLSession).
        public var pochetteURL: URL? { URL(string: "https://coverartarchive.org/release/\(id)/front-500") }
    }

    public struct Detail: Sendable {
        public let album: Album
        public let morceaux: [Morceau]
        public let codeBarres: String?
        public let aUnePochette: Bool
    }

    public enum Erreur: LocalizedError {
        case http(Int)
        public var errorDescription: String? {
            switch self { case .http(let c): "MusicBrainz a répondu \(c). Réessaie dans un instant." }
        }
    }

    private var derniereRequete = Date.distantPast
    public init() {}

    private func get(_ chemin: String, _ params: [String: String]) async throws -> Data {
        // Au plus une requête par seconde.
        let attente = 1.05 - Date().timeIntervalSince(derniereRequete)
        if attente > 0 { try await Task.sleep(for: .seconds(attente)) }
        derniereRequete = Date()
        var c = URLComponents(string: "https://musicbrainz.org/ws/2" + chemin)!
        c.queryItems = (params.merging(["fmt": "json"]) { a, _ in a }).sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        var req = URLRequest(url: c.url!)
        req.setValue("LaFleurStudio/0.1 ( https://lafleurstudio.ch )", forHTTPHeaderField: "User-Agent")
        let (data, rep) = try await URLSession.shared.data(for: req)
        let code = (rep as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else { throw Erreur.http(code) }
        return data
    }

    /// Transforme « Artiste - Album » ou « album artiste » en requête MusicBrainz.
    public static func requete(_ texte: String) -> String {
        let t = texte.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "")
        let parties = t.components(separatedBy: " - ")
        if parties.count == 2 { return "release:\"\(parties[1])\" AND artist:\"\(parties[0])\"" }
        return t
    }

    /// Cherche des albums. `cassetteSeulement` : uniquement les éditions K7.
    public func chercher(_ texte: String, cassetteSeulement: Bool = false) async throws -> [Album] {
        var q = Self.requete(texte)
        if cassetteSeulement { q = "(\(q)) AND format:Cassette" }
        let d = try await get("/release/", ["query": q, "limit": "15"])
        return try JSONDecoder().decode(ReponseRecherche.self, from: d).releases.map { $0.album }
    }

    public func detail(_ id: String) async throws -> Detail {
        let d = try await get("/release/\(id)", ["inc": "recordings+labels+artist-credits"])
        return try JSONDecoder().decode(ReleaseAPI.self, from: d).detail
    }

    /// Une image du Cover Art Archive (recto, dos, tranche, J-card scanné…).
    public struct ImageArchive: Identifiable, Hashable, Sendable {
        public let id: String
        public let url: URL
        public let vignette: URL
        public let types: [String]
        public let source: URL
    }

    /// Les scans d'une édition (Cover Art Archive), sans limite de débit côté MusicBrainz.
    public func images(_ id: String) async throws -> [ImageArchive] {
        var req = URLRequest(url: URL(string: "https://coverartarchive.org/release/\(id)")!)
        req.setValue("LaFleurStudio/0.1 ( https://lafleurstudio.ch )", forHTTPHeaderField: "User-Agent")
        let (data, rep) = try await URLSession.shared.data(for: req)
        let code = (rep as? HTTPURLResponse)?.statusCode ?? 0
        if code == 404 { return [] }
        guard code == 200 else { throw Erreur.http(code) }
        let source = URL(string: "https://musicbrainz.org/release/\(id)")!
        return try JSONDecoder().decode(ArchiveAPI.self, from: data).images.compactMap { i in
            guard let u = URL(string: i.image.replacingOccurrences(of: "http://", with: "https://")) else { return nil }
            let v = (i.thumbnails?["500"] ?? i.thumbnails?["large"]).flatMap { URL(string: $0.replacingOccurrences(of: "http://", with: "https://")) } ?? u
            return ImageArchive(id: "\(i.id)", url: u, vignette: v, types: i.types ?? [], source: source)
        }
    }

    /// Décodage exposé pour les tests.
    public static func decoderDetail(_ data: Data) throws -> Detail { try JSONDecoder().decode(ReleaseAPI.self, from: data).detail }
}

// MARK: - Formes JSON de MusicBrainz

private struct ReponseRecherche: Decodable { let releases: [ReleaseAPI] }

private struct CreditAPI: Decodable { let name: String; let joinphrase: String? }
private struct LabelAPI: Decodable { let name: String? }
private struct LabelInfoAPI: Decodable {
    let catalogNumber: String?
    let label: LabelAPI?
    enum CodingKeys: String, CodingKey { case catalogNumber = "catalog-number", label }
}
private struct PisteAPI: Decodable {
    let title: String
    let length: Int?
    let position: Int?
    let artistCredit: [CreditAPI]?
    enum CodingKeys: String, CodingKey { case title, length, position, artistCredit = "artist-credit" }
}
private struct MediumAPI: Decodable {
    let format: String?
    let position: Int?
    let tracks: [PisteAPI]?
    let trackCount: Int?
    enum CodingKeys: String, CodingKey { case format, position, tracks, trackCount = "track-count" }
}
private struct CoverAPI: Decodable { let front: Bool? }
private struct ArchiveAPI: Decodable {
    struct I: Decodable {
        let id: IdSouple
        let image: String
        let thumbnails: [String: String]?
        let types: [String]?
    }
    let images: [I]
}
/// Le Cover Art Archive renvoie les identifiants tantôt en nombre, tantôt en texte.
private struct IdSouple: Decodable, CustomStringConvertible {
    let description: String
    init(from d: Decoder) throws {
        let c = try d.singleValueContainer()
        if let n = try? c.decode(Int64.self) { description = String(n) } else { description = try c.decode(String.self) }
    }
}

private func nomCredit(_ c: [CreditAPI]?) -> String {
    (c ?? []).map { $0.name + ($0.joinphrase ?? "") }.joined()
}

private struct ReleaseAPI: Decodable {
    let id: String
    let title: String
    let date: String?
    let barcode: String?
    let artistCredit: [CreditAPI]?
    let labelInfo: [LabelInfoAPI]?
    let media: [MediumAPI]?
    let trackCount: Int?
    let coverArtArchive: CoverAPI?
    enum CodingKeys: String, CodingKey {
        case id, title, date, barcode, media
        case artistCredit = "artist-credit", labelInfo = "label-info", trackCount = "track-count", coverArtArchive = "cover-art-archive"
    }

    var album: ClientMusicBrainz.Album {
        let li = labelInfo?.first
        return ClientMusicBrainz.Album(
            id: id, titre: title, artiste: nomCredit(artistCredit), date: date,
            maisonDeDisque: li?.label?.name, catalogue: li?.catalogNumber,
            formats: (media ?? []).compactMap(\.format),
            nombreTitres: trackCount ?? (media ?? []).reduce(0) { $0 + ($1.trackCount ?? $1.tracks?.count ?? 0) })
    }

    var detail: ClientMusicBrainz.Detail {
        let a = album
        var morceaux: [Morceau] = []
        for m in media ?? [] {
            for t in m.tracks ?? [] {
                let artistes = nomCredit(t.artistCredit)
                morceaux.append(Morceau(titre: t.title, artistes: [artistes.isEmpty ? a.artiste : artistes], album: a.titre,
                                        dateSortie: date, dureeMs: t.length ?? 0, numeroPiste: t.position, numeroDisque: m.position,
                                        pochetteURL: coverArtArchive?.front == true ? a.pochetteURL : nil))
            }
        }
        return ClientMusicBrainz.Detail(album: a, morceaux: morceaux, codeBarres: barcode?.isEmpty == false ? barcode : nil,
                                        aUnePochette: coverArtArchive?.front == true)
    }
}
