import CryptoKit
import Foundation

/// Client de l'API Web Spotify pour un compte perso (appli en « Development Mode », connexion PKCE).
/// Règles 2026 prises en compte : `/playlists/{id}/items` (champ `item`), recherche limitée à 10 résultats.
public actor ClientSpotify {
    public struct Jetons: Codable, Sendable {
        public var acces: String
        public var rafraichissement: String
        public var expiration: Date
    }

    public enum Erreur: LocalizedError {
        case nonConnecte, http(Int, String), lienInconnu
        public var errorDescription: String? {
            switch self {
            case .nonConnecte: "Pas connecté à Spotify (Réglages → Spotify)."
            case .http(let code, let msg): "Spotify a répondu \(code) : \(msg)"
            case .lienInconnu: "Lien non reconnu : colle un lien Spotify de playlist, d'album ou de morceau."
            }
        }
    }

    public static let redirection = "http://127.0.0.1:8898/callback"
    public static let portRedirection: UInt16 = 8898
    static let portees = "playlist-read-private playlist-read-collaborative"

    public let clientID: String
    public private(set) var jetons: Jetons?
    /// Appelé à chaque renouvellement de jetons, pour les ranger dans le trousseau.
    private let surJetons: @Sendable (Jetons) -> Void

    public init(clientID: String, jetons: Jetons?, surJetons: @escaping @Sendable (Jetons) -> Void) {
        self.clientID = clientID; self.jetons = jetons; self.surJetons = surJetons
    }

    // MARK: Connexion (Authorization Code + PKCE, sans secret client)

    public struct DemandeConnexion: Sendable { public let url: URL; public let verificateur: String; public let etat: String }

    public nonisolated func preparerConnexion() -> DemandeConnexion {
        let verificateur = Self.aleatoire(64), etat = Self.aleatoire(16)
        let defi = Data(SHA256.hash(data: Data(verificateur.utf8))).base64URL
        var c = URLComponents(string: "https://accounts.spotify.com/authorize")!
        c.queryItems = [
            .init(name: "client_id", value: clientID), .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: Self.redirection), .init(name: "scope", value: Self.portees),
            .init(name: "code_challenge_method", value: "S256"), .init(name: "code_challenge", value: defi),
            .init(name: "state", value: etat),
        ]
        return DemandeConnexion(url: c.url!, verificateur: verificateur, etat: etat)
    }

    public func terminerConnexion(code: String, verificateur: String) async throws {
        try await demanderJetons([
            "grant_type": "authorization_code", "code": code, "redirect_uri": Self.redirection,
            "client_id": clientID, "code_verifier": verificateur,
        ])
    }

    private func rafraichir() async throws {
        guard let j = jetons else { throw Erreur.nonConnecte }
        try await demanderJetons(["grant_type": "refresh_token", "refresh_token": j.rafraichissement, "client_id": clientID])
    }

    private func demanderJetons(_ champs: [String: String]) async throws {
        var req = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var c = URLComponents(); c.queryItems = champs.map { URLQueryItem(name: $0.key, value: $0.value) }
        req.httpBody = c.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B").data(using: .utf8)
        let (data, rep) = try await URLSession.shared.data(for: req)
        let code = (rep as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else { throw Erreur.http(code, String(decoding: data, as: UTF8.self)) }
        struct R: Decodable { let access_token: String; let refresh_token: String?; let expires_in: Double }
        let r = try JSONDecoder().decode(R.self, from: data)
        // Spotify ne renvoie pas toujours de nouveau jeton de rafraîchissement : on garde l'ancien.
        let nouveaux = Jetons(acces: r.access_token, rafraichissement: r.refresh_token ?? jetons?.rafraichissement ?? "",
                              expiration: Date().addingTimeInterval(r.expires_in - 60))
        jetons = nouveaux
        surJetons(nouveaux)
    }

    // MARK: Appels API

    private func get<T: Decodable>(_ type: T.Type, _ url: URL, deuxiemeEssai: Bool = false) async throws -> T {
        guard var j = jetons else { throw Erreur.nonConnecte }
        if j.expiration < Date() { try await rafraichir(); j = jetons! }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(j.acces)", forHTTPHeaderField: "Authorization")
        let (data, rep) = try await URLSession.shared.data(for: req)
        let http = rep as? HTTPURLResponse, code = http?.statusCode ?? 0
        if code == 401 && !deuxiemeEssai { try await rafraichir(); return try await get(type, url, deuxiemeEssai: true) }
        if code == 429 && !deuxiemeEssai {
            let attente = Double(http?.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 2
            try await Task.sleep(for: .seconds(min(attente, 30)))
            return try await get(type, url, deuxiemeEssai: true)
        }
        guard code == 200 else { throw Erreur.http(code, String(decoding: data, as: UTF8.self)) }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func api(_ chemin: String, _ params: [String: String] = [:]) -> URL {
        var c = URLComponents(string: "https://api.spotify.com/v1" + chemin)!
        if !params.isEmpty { c.queryItems = params.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) } }
        return c.url!
    }

    /// Suit la pagination (`next`) jusqu'au bout.
    private func toutesLesPages<E: Decodable>(_ type: E.Type, depuis url: URL) async throws -> [E] {
        var elements: [E] = [], suivante: URL? = url
        while let u = suivante {
            let page = try await get(Page<E>.self, u)
            elements += page.items
            suivante = page.next.flatMap(URL.init(string:))
        }
        return elements
    }

    public struct Playlist: Decodable, Identifiable, Hashable, Sendable { public let id: String; public let name: String }

    public func mesPlaylists() async throws -> [Playlist] {
        try await toutesLesPages(Playlist?.self, depuis: api("/me/playlists", ["limit": "50"])).compactMap { $0 }
    }

    public func morceauxDePlaylist(_ id: String) async throws -> [Morceau] {
        try await toutesLesPages(ElementPlaylist.self, depuis: api("/playlists/\(id)/items", ["limit": "50"]))
            .compactMap { $0.contenu?.morceau() }
    }

    /// Un album trouvé par la recherche.
    public struct AlbumResume: Identifiable, Hashable, Sendable {
        public let id: String
        public let titre: String
        public let artiste: String
        public let annee: String?
        public let nombreTitres: Int
        public let pochetteURL: URL?
    }

    public func chercherAlbums(_ requete: String, limite: Int = 10) async throws -> [AlbumResume] {
        struct R: Decodable { let albums: Page<AlbumSimple?> }
        let r = try await get(R.self, api("/search", ["q": requete, "type": "album", "limit": String(min(limite, 10))]))
        return r.albums.items.compactMap { $0 }.map {
            AlbumResume(id: $0.id, titre: $0.name, artiste: $0.artists.map(\.name).joined(separator: ", "),
                        annee: $0.release_date.map { String($0.prefix(4)) }, nombreTitres: $0.total_tracks ?? 0,
                        pochetteURL: meilleureImage($0.images))
        }
    }

    public func morceauxDAlbum(_ id: String) async throws -> [Morceau] {
        let album = try await get(AlbumComplet.self, api("/albums/\(id)"))
        var pistes = album.tracks.items
        if let n = album.tracks.next.flatMap(URL.init(string:)) {
            pistes += try await toutesLesPages(PisteSimple.self, depuis: n)
        }
        let infos = AlbumAPI(name: album.name, release_date: album.release_date, images: album.images)
        return pistes.compactMap { TrackAPI(type: "track", id: $0.id, uri: $0.uri, name: $0.name, duration_ms: $0.duration_ms,
                                            artists: $0.artists, album: infos, track_number: $0.track_number,
                                            disc_number: $0.disc_number).morceau() }
    }

    public func morceau(_ id: String) async throws -> Morceau? {
        try await get(TrackAPI.self, api("/tracks/\(id)")).morceau()
    }

    public func chercher(_ requete: String, limite: Int = 10) async throws -> [Morceau] {
        struct R: Decodable { let tracks: Page<TrackAPI?> }
        let r = try await get(R.self, api("/search", ["q": requete, "type": "track", "limit": String(min(limite, 10))]))
        return r.tracks.items.compactMap { $0?.morceau() }
    }

    /// Trouve la meilleure correspondance Spotify pour une idée de Claude.
    public func trouver(artiste: String, titre: String) async throws -> Morceau? {
        let precis = try await chercher("track:\(titre) artist:\(artiste)", limite: 3)
        if let m = precis.first { return m }
        return try await chercher("\(artiste) \(titre)", limite: 3).first
    }

    /// Importe un lien open.spotify.com (ou une URI spotify:) de playlist, d'album ou de morceau.
    public func importer(lien: String) async throws -> [Morceau] {
        guard let (genre, id) = Self.analyserLien(lien) else { throw Erreur.lienInconnu }
        switch genre {
        case "playlist": return try await morceauxDePlaylist(id)
        case "album": return try await morceauxDAlbum(id)
        default: return try await morceau(id).map { [$0] } ?? []
        }
    }

    public static func analyserLien(_ lien: String) -> (String, String)? {
        let l = lien.trimmingCharacters(in: .whitespacesAndNewlines)
        let morceaux: [String]
        if l.hasPrefix("spotify:") { morceaux = l.split(separator: ":").map(String.init).dropFirst().map { $0 } }
        else if let u = URL(string: l), u.host?.hasSuffix("spotify.com") == true {
            morceaux = u.pathComponents.filter { $0 != "/" && !$0.hasPrefix("intl-") }
        } else { return nil }
        guard morceaux.count >= 2, ["playlist", "album", "track"].contains(morceaux[0]) else { return nil }
        return (morceaux[0], morceaux[1])
    }

    static func aleatoire(_ n: Int) -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        var gen = SystemRandomNumberGenerator()
        return String((0..<n).map { _ in alphabet.randomElement(using: &gen)! })
    }
}

// MARK: - Formes JSON de Spotify

struct Page<E: Decodable>: Decodable { let items: [E]; let next: String? }

struct ImageAPI: Decodable { let url: String; let width: Int? }
struct ArtisteAPI: Decodable { let name: String }
struct AlbumAPI: Decodable { let name: String; let release_date: String?; let images: [ImageAPI]? }

struct TrackAPI: Decodable {
    let type: String?
    let id: String?
    let uri: String
    let name: String
    let duration_ms: Int
    let artists: [ArtisteAPI]
    let album: AlbumAPI?
    var track_number: Int? = nil
    var disc_number: Int? = nil

    /// nil pour les épisodes de podcast et les fichiers locaux (Spotify ne sait pas les jouer par URI).
    func morceau() -> Morceau? {
        guard type ?? "track" == "track", let id, uri.hasPrefix("spotify:track:") else { return nil }
        return Morceau(spotifyID: id, uri: uri, titre: name, artistes: artists.map(\.name), album: album?.name ?? "",
                       dateSortie: album?.release_date, dureeMs: duration_ms, numeroPiste: track_number,
                       numeroDisque: disc_number, pochetteURL: meilleureImage(album?.images))
    }
}

/// Élément de playlist : le contenu est sous `item` depuis 2026 (`track` avant) ; on accepte les deux.
struct ElementPlaylist: Decodable {
    let contenu: TrackAPI?
    enum Cles: String, CodingKey { case item, track }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: Cles.self)
        contenu = (try? c.decodeIfPresent(TrackAPI.self, forKey: .item)) ?? (try? c.decodeIfPresent(TrackAPI.self, forKey: .track))
    }
}

struct PisteSimple: Decodable {
    let id: String?; let uri: String; let name: String; let duration_ms: Int; let artists: [ArtisteAPI]
    let track_number: Int?; let disc_number: Int?
}
struct AlbumSimple: Decodable {
    let id: String; let name: String; let artists: [ArtisteAPI]; let release_date: String?
    let total_tracks: Int?; let images: [ImageAPI]?
}

/// La plus grande image jusqu'à 640 px : assez nette pour imprimer une pochette de 6,5 cm.
func meilleureImage(_ images: [ImageAPI]?) -> URL? {
    let i = (images ?? []).filter { ($0.width ?? 0) <= 640 }.max { ($0.width ?? 0) < ($1.width ?? 0) }
    return i.flatMap { URL(string: $0.url) }
}
struct AlbumComplet: Decodable {
    let name: String; let release_date: String?; let images: [ImageAPI]?
    let tracks: Page<PisteSimple>
}

extension Data {
    var base64URL: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
