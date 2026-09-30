import CoreGraphics
import CoreImage
import Foundation

/// Un code-barres à une dimension : une suite de modules (barre ou espace) de même largeur.
public struct CodeBarres1D: Hashable, Sendable {
    public enum Genre: String, Codable, CaseIterable, Sendable {
        case ean13, upcA, code128
        public var nom: String {
            switch self { case .ean13: "EAN-13"; case .upcA: "UPC-A"; case .code128: "Code 128" }
        }
    }
    public let genre: Genre
    /// true = barre, false = espace. Sans les zones blanches autour (à ajouter au rendu : 10 modules de chaque côté).
    public let modules: [Bool]
    /// Barres qui descendent plus bas que les autres (gardes de l'EAN/UPC).
    public let longues: [Bool]
    /// Le numéro complet, clé de contrôle comprise.
    public let numero: String
    /// Groupes de chiffres imprimés sous les barres, avec leur position en modules (début, fin).
    /// Une position négative veut dire « à gauche des barres », au-delà de `modules.count` « à droite ».
    public let groupes: [(texte: String, debut: Int, fin: Int)]

    public static func == (a: Self, b: Self) -> Bool { a.genre == b.genre && a.modules == b.modules && a.numero == b.numero }
    public func hash(into h: inout Hasher) { h.combine(genre); h.combine(modules); h.combine(numero) }
}

public enum CodesBarres {
    private static let L = ["0001101", "0011001", "0010011", "0111101", "0100011", "0110001", "0101111", "0111011", "0110111", "0001011"]
    private static let R = L.map { String($0.map { $0 == "0" ? "1" : "0" }) }
    private static let G = R.map { String($0.reversed()) }
    private static let parites = ["LLLLLL", "LLGLGG", "LLGGLG", "LLGGGL", "LGLLGG", "LGGLLG", "LGGGLL", "LGLGLG", "LGLGGL", "LGGLGL"]

    private static func chiffres(_ s: String) -> [Int]? {
        let c = s.filter { !$0.isWhitespace }
        guard !c.isEmpty, c.allSatisfy(\.isASCII), c.allSatisfy(\.isNumber) else { return nil }
        return c.compactMap { $0.wholeNumberValue }
    }

    /// Clé de contrôle EAN/UPC (poids 3 sur les chiffres en partant de la droite, un sur deux).
    public static func cle(_ s: String) -> Int? {
        guard let d = chiffres(s) else { return nil }
        let somme = d.reversed().enumerated().reduce(0) { $0 + $1.element * ($1.offset % 2 == 0 ? 3 : 1) }
        return (10 - somme % 10) % 10
    }

    /// 12 chiffres → 13 avec la clé calculée ; 13 chiffres → la clé est recalculée. nil si ce n'est pas un EAN possible.
    public static func completerEAN(_ s: String) -> String? {
        guard let d = chiffres(s), d.count == 12 || d.count == 13 else { return nil }
        let douze = d.prefix(12).map(String.init).joined()
        return douze + String(cle(douze)!)
    }

    /// 11 chiffres → 12 avec la clé ; 12 → clé recalculée.
    public static func completerUPC(_ s: String) -> String? {
        guard let d = chiffres(s), d.count == 11 || d.count == 12 else { return nil }
        let onze = d.prefix(11).map(String.init).joined()
        return onze + String(cle(onze)!)
    }

    /// Numéro EAN par défaut : préfixe 2 (usage interne, aucun vrai produit), numéroté comme la collection.
    /// LFS-001 → 2000126000012.
    public static func eanParDefaut(_ numero: Int) -> String {
        completerEAN("20001260" + String(format: "%04d", max(0, numero) % 10000))!
    }

    /// Chiffres du numéro de catalogue (LFS-007 → 7).
    public static func numeroDeCatalogue(_ catalogue: String) -> Int {
        Int(catalogue.reversed().prefix { $0.isNumber }.reversed().map(String.init).joined()) ?? 0
    }

    private static func bits(_ s: String) -> [Bool] { s.map { $0 == "1" } }

    public static func ean13(_ s: String) -> CodeBarres1D? {
        guard let n = completerEAN(s) else { return nil }
        let d = n.compactMap(\.wholeNumberValue)
        var m = bits("101"), longues = [Bool](repeating: true, count: 3)
        let parite = Array(parites[d[0]])
        for i in 1...6 { let p = bits(parite[i - 1] == "L" ? L[d[i]] : G[d[i]]); m += p; longues += Array(repeating: false, count: 7) }
        m += bits("01010"); longues += Array(repeating: true, count: 5)
        for i in 7...12 { m += bits(R[d[i]]); longues += Array(repeating: false, count: 7) }
        m += bits("101"); longues += Array(repeating: true, count: 3)
        let t = Array(n).map(String.init)
        return CodeBarres1D(genre: .ean13, modules: m, longues: longues, numero: n,
                            groupes: [(t[0], -8, -1), (t[1...6].joined(), 3, 45), (t[7...12].joined(), 50, 92)])
    }

    public static func upcA(_ s: String) -> CodeBarres1D? {
        guard let n = completerUPC(s), let e = ean13("0" + n) else { return nil }
        var longues = e.longues
        for i in 3..<10 { longues[i] = true }      // premier chiffre : barres longues
        for i in 85..<92 { longues[i] = true }     // dernier chiffre (la clé) : barres longues
        let t = Array(n).map(String.init)
        return CodeBarres1D(genre: .upcA, modules: e.modules, longues: longues, numero: n,
                            groupes: [(t[0], -8, -1), (t[1...5].joined(), 10, 45), (t[6...10].joined(), 50, 85), (t[11], 96, 103)])
    }

    /// Largeurs barre/espace des 107 symboles du Code 128 (le dernier est le stop).
    private static let motifs128: [String] = [
        "212222", "222122", "222221", "121223", "121322", "131222", "122213", "122312", "132212", "221213",
        "221312", "231212", "112232", "122132", "122231", "113222", "123122", "123221", "223211", "221132",
        "221231", "213212", "223112", "312131", "311222", "321122", "321221", "312212", "322112", "322211",
        "212123", "212321", "232121", "111323", "131123", "131321", "112313", "132113", "132311", "211313",
        "231113", "231311", "112133", "112331", "132131", "113123", "113321", "133121", "313121", "211331",
        "231131", "213113", "213311", "213131", "311123", "311321", "331121", "312113", "312311", "332111",
        "314111", "221411", "431111", "111224", "111422", "121124", "121421", "141122", "141221", "112214",
        "112412", "122114", "122411", "142112", "142211", "241211", "221114", "413111", "241112", "134111",
        "111242", "121142", "121241", "114212", "124112", "124211", "411212", "421112", "421211", "212141",
        "214121", "412121", "111143", "111341", "131141", "114113", "114311", "411113", "411311", "113141",
        "114131", "311141", "411131", "211412", "211214", "211232", "2331112",
    ]

    /// Code 128, jeu B : lettres, chiffres et ponctuation ASCII (pratique pour « LFS-001 »).
    public static func code128(_ s: String) -> CodeBarres1D? {
        guard !s.isEmpty, s.unicodeScalars.allSatisfy({ (32...126).contains($0.value) }) else { return nil }
        let valeurs = s.unicodeScalars.map { Int($0.value) - 32 }
        let somme = valeurs.enumerated().reduce(104) { $0 + ($1.offset + 1) * $1.element }
        var m: [Bool] = []
        for v in [104] + valeurs + [somme % 103, 106] {
            for (i, w) in motifs128[v].enumerated() { m += Array(repeating: i % 2 == 0, count: Int(String(w))!) }
        }
        return CodeBarres1D(genre: .code128, modules: m, longues: Array(repeating: false, count: m.count), numero: s,
                            groupes: [(s, 0, m.count)])
    }

    public static func generer(_ genre: CodeBarres1D.Genre, _ numero: String) -> CodeBarres1D? {
        switch genre {
        case .ean13: ean13(numero)
        case .upcA: upcA(numero)
        case .code128: code128(numero)
        }
    }
}

/// QR code, via le générateur de macOS (CoreImage), rendu en modules pour être dessiné en vectoriel.
public enum CodeQR {
    /// Matrice des modules (true = noir), sans la marge blanche. Correction « M » : résiste à 15 % d'abîme.
    public static func modules(_ texte: String, correction: String = "M") -> [[Bool]]? {
        guard !texte.isEmpty, let filtre = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filtre.setValue(Data(texte.utf8), forKey: "inputMessage")
        filtre.setValue(correction, forKey: "inputCorrectionLevel")
        guard let img = filtre.outputImage,
              let cg = CIContext(options: [.useSoftwareRenderer: true]).createCGImage(img, from: img.extent) else { return nil }
        let w = cg.width, h = cg.height
        var px = [UInt8](repeating: 255, count: w * h)
        guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.interpolationQuality = .none
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        let noir = { (x: Int, y: Int) in px[y * w + x] < 128 }
        // On retire la marge blanche ajoutée par le générateur.
        var x0 = w, y0 = h, x1 = -1, y1 = -1
        for y in 0..<h { for x in 0..<w where noir(x, y) { x0 = min(x0, x); x1 = max(x1, x); y0 = min(y0, y); y1 = max(y1, y) } }
        guard x1 >= x0, y1 >= y0 else { return nil }
        return (y0...y1).map { y in (x0...x1).map { x in noir(x, y) } }
    }
}

/// Code Spotify (les ondes que l'appli Spotify scanne), fourni par Spotify pour un lien album/playlist/titre.
public enum CodeSpotify {
    /// `fond` en hexa sans #, barres blanches ou noires. PNG 640 px de large.
    public static func url(uri: String, fond: String, barresBlanches: Bool) -> URL? {
        let f = fond.replacingOccurrences(of: "#", with: "").lowercased()
        return URL(string: "https://scannables.scdn.co/uri/plain/png/\(f)/\(barresBlanches ? "white" : "black")/640/\(uri)")
    }
}
