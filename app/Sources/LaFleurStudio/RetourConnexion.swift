import Foundation
import Network

/// Petit serveur HTTP sur 127.0.0.1 qui attrape la redirection de Spotify après la connexion
/// (http://127.0.0.1:8898/callback?code=…&state=…), puis s'arrête.
final class RetourConnexion: @unchecked Sendable {
    private var ecouteur: NWListener?
    private var suite: CheckedContinuation<[String: String], Error>?
    private let file = DispatchQueue(label: "kassette.retour-connexion")

    enum Erreur: LocalizedError {
        case port, annule
        var errorDescription: String? {
            switch self {
            case .port: "Impossible d'écouter sur le port 8898 (déjà utilisé ?)."
            case .annule: "Connexion Spotify annulée."
            }
        }
    }

    /// Attend la redirection et renvoie ses paramètres (`code`, `state` ou `error`).
    func attendre(port: UInt16) async throws -> [String: String] {
        try await withCheckedThrowingContinuation { cont in
            file.async {
                do {
                    let params = NWParameters.tcp
                    params.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!)
                    let e = try NWListener(using: params)
                    self.suite = cont
                    e.newConnectionHandler = { [weak self] c in self?.servir(c) }
                    e.stateUpdateHandler = { [weak self] etat in
                        if case .failed = etat { self?.finir(.failure(Erreur.port)) }
                    }
                    e.start(queue: self.file)
                    self.ecouteur = e
                } catch { cont.resume(throwing: Erreur.port) }
            }
        }
    }

    func annuler() { file.async { self.finir(.failure(Erreur.annule)) } }

    private func servir(_ c: NWConnection) {
        c.start(queue: file)
        c.receive(minimumIncompleteLength: 1, maximumLength: 16384) { [weak self] data, _, _, _ in
            guard let self else { return }
            let requete = data.map { String(decoding: $0, as: UTF8.self) } ?? ""
            // Première ligne : « GET /callback?code=…&state=… HTTP/1.1 »
            let chemin = requete.split(separator: " ").dropFirst().first.map(String.init) ?? ""
            guard chemin.hasPrefix("/callback") else {
                c.send(content: Data("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8),
                       completion: .contentProcessed { _ in c.cancel() })
                return
            }
            var params: [String: String] = [:]
            for item in URLComponents(string: chemin)?.queryItems ?? [] { params[item.name] = item.value ?? "" }
            let page = """
            <!doctype html><meta charset="utf-8"><title>LaFleurStudio</title>
            <body style="font:16px -apple-system;background:#c0c0c0;padding:40px">
            <h2>\(params["error"] == nil ? "C'est bon, Spotify est connecté ✿" : "Connexion refusée")</h2>
            <p>Tu peux fermer cet onglet et retourner dans LaFleurStudio.</p>
            """
            let corps = Data(page.utf8)
            let rep = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(corps.count)\r\nConnection: close\r\n\r\n"
            c.send(content: Data(rep.utf8) + corps, completion: .contentProcessed { _ in c.cancel() })
            self.finir(.success(params))
        }
    }

    private func finir(_ r: Result<[String: String], Error>) {
        ecouteur?.cancel(); ecouteur = nil
        suite?.resume(with: r); suite = nil
    }
}
