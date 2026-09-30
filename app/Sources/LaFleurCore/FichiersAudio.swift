import AVFoundation
import Foundation

/// Ce que l'app sait d'un fichier audio du dossier.
public struct InfosFichier: Hashable, Sendable {
    public var url: URL
    public var titre: String?
    public var artiste: String?
    public var album: String?
    public var numeroPiste: Int?
    public var numeroDisque: Int?
    public var duree: TimeInterval

    public init(url: URL, titre: String? = nil, artiste: String? = nil, album: String? = nil,
                numeroPiste: Int? = nil, numeroDisque: Int? = nil, duree: TimeInterval) {
        self.url = url; self.titre = titre; self.artiste = artiste; self.album = album
        self.numeroPiste = numeroPiste; self.numeroDisque = numeroDisque; self.duree = duree
    }

    /// Titre à utiliser : celui des tags, sinon tiré du nom du fichier.
    public var titreAffiche: String { titre ?? NomDeFichier.analyser(url.lastPathComponent).titre }
}

public enum DossierAudio {
    public static let extensions: Set<String> = ["mp3", "flac", "wav", "aif", "aiff", "m4a", "aac", "alac", "caf"]

    /// Liste les fichiers audio du dossier et de ses sous-dossiers.
    public static func lister(_ dossier: URL) -> [URL] {
        guard let e = FileManager.default.enumerator(at: dossier, includingPropertiesForKeys: [.isRegularFileKey],
                                                     options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return [] }
        return e.compactMap { $0 as? URL }.filter { extensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    /// Lit les tags et la durée d'un fichier.
    public static func lire(_ url: URL) async -> InfosFichier? {
        let asset = AVURLAsset(url: url)
        guard let d = try? await asset.load(.duration), d.isNumeric, d.seconds > 0 else { return nil }
        var infos = InfosFichier(url: url, duree: d.seconds)
        let tout = ((try? await asset.load(.metadata)) ?? []) + ((try? await asset.load(.commonMetadata)) ?? [])
        for item in tout {
            let cle = (item.commonKey?.rawValue ?? (item.key as? String) ?? item.identifier?.rawValue ?? "").lowercased()
            guard let valeur = try? await item.load(.stringValue), !valeur.isEmpty else { continue }
            switch cle {
            case "title", "tit2", "©nam": infos.titre = infos.titre ?? valeur
            case "artist", "tpe1", "©art": infos.artiste = infos.artiste ?? valeur
            case "albumname", "album", "talb", "©alb": infos.album = infos.album ?? valeur
            case "trck", "tracknumber", "trkn": infos.numeroPiste = infos.numeroPiste ?? Int(valeur.split(separator: "/").first ?? "")
            case "tpos", "discnumber", "disk": infos.numeroDisque = infos.numeroDisque ?? Int(valeur.split(separator: "/").first ?? "")
            default: break
            }
        }
        if infos.numeroPiste == nil { infos.numeroPiste = NomDeFichier.analyser(url.lastPathComponent).numero }
        return infos
    }

    public static func lireTout(_ dossier: URL) async -> [InfosFichier] {
        var out: [InfosFichier] = []
        for url in lister(dossier) { if let i = await lire(url) { out.append(i) } }
        return out
    }

    /// Ordre d'un dossier sans Spotify : disque, piste, puis nom de fichier.
    public static func ordonner(_ fichiers: [InfosFichier]) -> [InfosFichier] {
        fichiers.sorted { a, b in
            let da = a.numeroDisque ?? 1, db = b.numeroDisque ?? 1
            if da != db { return da < db }
            switch (a.numeroPiste, b.numeroPiste) {
            case let (x?, y?) where x != y: return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.url.lastPathComponent.localizedStandardCompare(b.url.lastPathComponent) == .orderedAscending
            }
        }
    }

    /// Pistes sans Spotify, à partir des fichiers d'un dossier.
    public static func pistes(depuis fichiers: [InfosFichier]) -> [Piste] {
        ordonner(fichiers).map { f in
            Piste(morceau: Morceau(titre: f.titreAffiche, artistes: f.artiste.map { [$0] } ?? [], album: f.album ?? "",
                                   dureeMs: Int(f.duree * 1000), numeroPiste: f.numeroPiste, numeroDisque: f.numeroDisque),
                  fichier: f.url, dureeFichier: f.duree)
        }
    }
}

public enum NomDeFichier {
    /// « 03 - Artiste - Titre.flac » → numéro 3, titre « Titre ».
    public static func analyser(_ nom: String) -> (numero: Int?, titre: String) {
        var base = (nom as NSString).deletingPathExtension
        var numero: Int?
        if let r = base.range(of: #"^\s*(\d{1,3})\s*[-_.)\s]\s*"#, options: .regularExpression) {
            numero = Int(base[r].filter(\.isNumber))
            base.removeSubrange(r)
        }
        let morceaux = base.components(separatedBy: " - ")
        return (numero, (morceaux.count > 1 ? morceaux.last! : base).trimmingCharacters(in: .whitespaces))
    }
}

/// Associe les morceaux (Spotify) aux fichiers du dossier.
public enum Association {
    public enum Resultat: Hashable, Sendable {
        /// Un seul fichier correspond clairement.
        case certain(InfosFichier)
        /// Plusieurs candidats plausibles : il faut demander à l'utilisateur.
        case aConfirmer([InfosFichier])
        /// Aucun fichier ne correspond.
        case introuvable
    }

    /// Normalise un titre pour comparer : minuscules, sans accents, sans « (Remastered) », « feat. »…
    public static func normaliser(_ s: String) -> String {
        var t = s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()
        t = t.replacingOccurrences(of: #"\s*[\(\[][^\)\]]*(remaster|version|edit|mono|stereo|live)[^\)\]]*[\)\]]"#,
                                   with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\s+(feat\.?|ft\.?)\s.*$"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespaces)
    }

    /// Note de 0 à 1 : titre (le plus important), artiste, durée.
    public static func score(_ m: Morceau, _ f: InfosFichier) -> Double {
        let tm = normaliser(m.titre), tf = normaliser(f.titreAffiche)
        guard !tm.isEmpty, !tf.isEmpty else { return 0 }
        var s = 0.0
        if tm == tf { s += 0.6 } else if tf.contains(tm) || tm.contains(tf) { s += 0.45 } else { return 0 }
        if let a = f.artiste {
            let an = normaliser(a)
            if m.artistes.contains(where: { let x = normaliser($0); return an.contains(x) || x.contains(an) }) { s += 0.2 }
        }
        let ecart = abs(m.duree - f.duree)
        if ecart <= 2 { s += 0.2 } else if ecart <= 8 { s += 0.1 } else if ecart > 30 { s -= 0.2 }
        return s
    }

    public static func chercher(_ m: Morceau, dans fichiers: [InfosFichier]) -> Resultat {
        let notes = fichiers.map { ($0, score(m, $0)) }.filter { $0.1 >= 0.4 }.sorted { $0.1 > $1.1 }
        guard let premier = notes.first else { return .introuvable }
        let proches = notes.filter { premier.1 - $0.1 < 0.15 }
        if proches.count == 1 && premier.1 >= 0.8 { return .certain(premier.0) }
        return .aConfirmer(notes.prefix(4).map(\.0))
    }
}
