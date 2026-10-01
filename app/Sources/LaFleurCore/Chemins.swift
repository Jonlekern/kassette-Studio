import Foundation

/// Lecture et modification de n'importe quel réglage par son chemin (« variante.palette.fond »,
/// « ajustements.recto-titre.dx », « etiquettePochette »…), directement sur la forme JSON du modèle.
///
/// La liste des réglages n'est donc écrite nulle part à la main : tout champ ajouté à `Design`, `Projet` ou
/// `Preferences` devient aussitôt modifiable par l'IA (demande 6, « liste générée depuis le modèle »).
public enum Chemins {
    public enum Erreur: LocalizedError {
        case cheminInconnu(String), valeurInvalide(String, String)
        public var errorDescription: String? {
            switch self {
            case .cheminInconnu(let c): String(localized: "Réglage inconnu : \(c)")
            case .valeurInvalide(let c, let v): String(localized: "Valeur refusée pour \(c) : \(v)")
            }
        }
    }

    /// Valeur actuelle du réglage, en texte (nil si le chemin n'existe pas).
    public static func lire<T: Encodable>(_ chemin: String, dans objet: T) -> String? {
        guard let racine = try? jsonObjet(objet), let v = valeur(racine, morceaux(chemin)) else { return nil }
        return texte(v)
    }

    /// Change le réglage. `valeur` est du texte (« 1.3 », « oui », « #FF0000 », « fond »), ou du JSON pour un objet.
    /// Le type est celui de la valeur actuelle ; un chemin qui n'existe pas encore est créé seulement dans un
    /// dictionnaire (ex. « echelles.titre », « ajustements.recto-titre »).
    public static func ecrire<T: Codable>(_ chemin: String, _ valeur: String, dans objet: inout T) throws {
        let m = morceaux(chemin)
        guard !m.isEmpty else { throw Erreur.cheminInconnu(chemin) }
        var racine = try jsonObjet(objet)
        racine = try remplacer(racine, m[...], valeur, chemin: chemin)
        let data = try JSONSerialization.data(withJSONObject: racine)
        guard let nouveau = try? JSONDecoder().decode(T.self, from: data) else { throw Erreur.valeurInvalide(chemin, valeur) }
        // Le décodage tolérant remplace une valeur illisible par la valeur par défaut, sans erreur :
        // on relit pour vérifier que le changement a bien été pris (sinon c'est un refus, pas un succès silencieux).
        // (Un objet entier est complété par ses valeurs par défaut : on ne vérifie que les valeurs simples.)
        let v = Self.valeur(racine, m)
        if !(v is [String: Any]) && !(v is [Any]) {
            let voulu = v.map(texte) ?? "null"
            let obtenu = lire(chemin, dans: nouveau) ?? "null"
            guard voulu == obtenu || (Double(voulu) != nil && Double(voulu) == Double(obtenu)) else { throw Erreur.valeurInvalide(chemin, valeur) }
        }
        objet = nouveau
    }

    /// Le modèle sous forme JSON (pour le montrer à l'IA).
    public static func json<T: Encodable>(_ objet: T) -> String {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return (try? e.encode(objet)).map { String(decoding: $0, as: UTF8.self) } ?? "{}"
    }

    // MARK: Détails

    static func morceaux(_ chemin: String) -> [String] {
        chemin.split(separator: ".").map(String.init).filter { !$0.isEmpty }
    }

    static func jsonObjet<T: Encodable>(_ objet: T) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(objet), options: [.fragmentsAllowed])
    }

    static func valeur(_ racine: Any, _ m: [String]) -> Any? {
        var v: Any? = racine
        for k in m {
            if let d = v as? [String: Any] { v = d[k] } else if let a = v as? [Any], let i = Int(k), a.indices.contains(i) { v = a[i] } else { return nil }
        }
        return v
    }

    static func texte(_ v: Any) -> String {
        if let n = v as? NSNumber {
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return n.boolValue ? "true" : "false" }
            return n.stringValue
        }
        if let s = v as? String { return s }
        if v is NSNull { return "null" }
        return (try? JSONSerialization.data(withJSONObject: v, options: [.sortedKeys, .fragmentsAllowed]))
            .map { String(decoding: $0, as: UTF8.self) } ?? "?"
    }

    private static func remplacer(_ noeud: Any, _ m: ArraySlice<String>, _ valeur: String, chemin: String) throws -> Any {
        guard let k = m.first else { return noeud }
        let reste = m.dropFirst()
        if var d = noeud as? [String: Any] {
            if reste.isEmpty {
                d[k] = try convertir(valeur, comme: d[k], chemin: chemin)
            } else {
                // Un sous-objet absent n'est créé que dans un dictionnaire libre (echelles, ajustements…).
                d[k] = try remplacer(d[k] ?? [String: Any](), reste, valeur, chemin: chemin)
            }
            return d
        }
        if var a = noeud as? [Any], let i = Int(k), a.indices.contains(i) {
            a[i] = reste.isEmpty ? try convertir(valeur, comme: a[i], chemin: chemin) : try remplacer(a[i], reste, valeur, chemin: chemin)
            return a
        }
        throw Erreur.cheminInconnu(chemin)
    }

    /// Convertit le texte de l'IA au type de la valeur actuelle.
    private static func convertir(_ v: String, comme actuel: Any?, chemin: String) throws -> Any {
        let t = v.trimmingCharacters(in: .whitespacesAndNewlines)
        let bas = t.lowercased()
        let vrai = ["true", "oui", "yes", "vrai", "1"], faux = ["false", "non", "no", "faux", "0"]
        let nombre = Double(t.replacingOccurrences(of: ",", with: "."))
        switch actuel {
        case let n as NSNumber where CFGetTypeID(n) == CFBooleanGetTypeID():
            if vrai.contains(bas) { return true }
            if faux.contains(bas) { return false }
            throw Erreur.valeurInvalide(chemin, v)
        case is NSNumber:
            guard let nombre else { throw Erreur.valeurInvalide(chemin, v) }
            return nombre
        case is String:
            return t
        case is [Any], is [String: Any]:
            guard let d = t.data(using: .utf8), let o = try? JSONSerialization.jsonObject(with: d) else { throw Erreur.valeurInvalide(chemin, v) }
            return o
        default:
            // Valeur absente ou nulle : on devine (nul, booléen, nombre, JSON, sinon texte).
            if bas == "null" || bas == "nil" || t.isEmpty { return NSNull() }
            if ["true", "oui", "yes", "vrai"].contains(bas) { return true }
            if ["false", "non", "no", "faux"].contains(bas) { return false }
            if let nombre { return nombre }
            if t.hasPrefix("{") || t.hasPrefix("["), let d = t.data(using: .utf8), let o = try? JSONSerialization.jsonObject(with: d) { return o }
            return t
        }
    }
}
