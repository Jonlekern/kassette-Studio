import Foundation
import Security

/// Secrets rangés dans le trousseau macOS (clé Claude, identifiant et jetons Spotify).
enum Trousseau {
    private static let service = "com.lafleurstudio.kassette-recorder"

    static func lire(_ compte: String) -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                kSecAttrAccount as String: compte, kSecReturnData as String: true,
                                kSecMatchLimit as String: kSecMatchLimitOne]
        var res: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &res) == errSecSuccess, let d = res as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func ecrire(_ compte: String, _ valeur: String?) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                   kSecAttrAccount as String: compte]
        SecItemDelete(base as CFDictionary)
        guard let v = valeur, !v.isEmpty else { return }
        var ajout = base
        ajout[kSecValueData as String] = Data(v.utf8)
        SecItemAdd(ajout as CFDictionary, nil)
    }

    static func lireJSON<T: Decodable>(_ compte: String, _ type: T.Type) -> T? {
        lire(compte).flatMap { try? JSONDecoder().decode(T.self, from: Data($0.utf8)) }
    }

    static func ecrireJSON<T: Encodable>(_ compte: String, _ valeur: T?) {
        ecrire(compte, valeur.flatMap { try? JSONEncoder().encode($0) }.map { String(decoding: $0, as: UTF8.self) })
    }
}
