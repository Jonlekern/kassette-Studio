import AppKit
import CoreText
import LaFleurCore
import SwiftUI

extension Color {
    /// Couleur depuis « #RRGGBB ».
    init(hex: String) {
        let (r, g, b) = Verification.rgb(hex)
        self.init(.sRGB, red: r, green: g, blue: b)
    }
}

extension NSColor {
    var hex: String {
        let c = usingColorSpace(.sRGB) ?? self
        return String(format: "#%02X%02X%02X", Int(round(c.redComponent * 255)), Int(round(c.greenComponent * 255)), Int(round(c.blueComponent * 255)))
    }
}

/// Polices et mesures de texte, en millimètres, identiques pour le dessin et pour la vérification.
enum Typo {
    static let ptParMM: CGFloat = 72 / 25.4

    /// Polices intégrées (libres) et polices du Mac proposées à Claude.
    static let integrees = ["Cormorant Garamond", "Space Mono", "VT323", "Permanent Marker", "Bebas Neue", "Archivo Black",
                            "Teko", "Caveat", "Anton", "Playfair Display", "Press Start 2P", "Rubik Mono One", "Special Elite",
                            "Monoton", "Syne", "IBM Plex Mono"]
    static let systeme = ["Futura", "Avenir Next", "Avenir Next Condensed", "Helvetica Neue", "Didot", "Bodoni 72", "Baskerville",
                          "Georgia", "American Typewriter", "Courier New", "Menlo", "Marker Felt", "Noteworthy", "Copperplate",
                          "Gill Sans", "Optima", "Rockwell", "Impact", "Arial Black", "Chalkboard SE"]

    /// Dossier des polices importées par l'utilisateur.
    static var dossierPerso: URL {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LaFleurStudio/Polices", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    /// Enregistre les polices de l'app (si macOS ne l'a pas déjà fait) et celles importées par l'utilisateur.
    static func enregistrer() {
        var dossiers = [dossierPerso]
        if let r = Bundle.main.resourceURL { dossiers.append(r.appendingPathComponent("Polices")) }
        for d in dossiers {
            let fichiers = (try? FileManager.default.contentsOfDirectory(at: d, includingPropertiesForKeys: nil)) ?? []
            for f in fichiers where ["ttf", "otf", "ttc"].contains(f.pathExtension.lowercased()) {
                CTFontManagerRegisterFontsForURL(f as CFURL, .process, nil)
            }
        }
    }

    /// Copie une police dans le dossier de l'app et l'enregistre. Renvoie ses familles.
    static func importer(_ url: URL) throws -> [String] {
        let dest = dossierPerso.appendingPathComponent(url.lastPathComponent)
        if !FileManager.default.fileExists(atPath: dest.path) { try FileManager.default.copyItem(at: url, to: dest) }
        CTFontManagerRegisterFontsForURL(dest as CFURL, .process, nil)
        let descs = (CTFontManagerCreateFontDescriptorsFromURL(dest as CFURL) as? [CTFontDescriptor]) ?? []
        return descs.compactMap { CTFontDescriptorCopyAttribute($0, kCTFontFamilyNameAttribute) as? String }
    }

    /// Toutes les familles utilisables (installées sur ce Mac).
    static var disponibles: [String] {
        let installees = Set(NSFontManager.shared.availableFontFamilies)
        let perso = ((try? FileManager.default.contentsOfDirectory(at: dossierPerso, includingPropertiesForKeys: nil)) ?? [])
            .flatMap { f -> [String] in
                ((CTFontManagerCreateFontDescriptorsFromURL(f as CFURL) as? [CTFontDescriptor]) ?? [])
                    .compactMap { CTFontDescriptorCopyAttribute($0, kCTFontFamilyNameAttribute) as? String }
            }
        var vues = Set<String>()
        return (integrees + systeme + perso).filter { installees.contains($0) && vues.insert($0).inserted }
    }

    static func nsFont(_ famille: String, _ taille: CGFloat, gras: Bool = false, italique: Bool = false) -> NSFont {
        let t = max(1, taille)
        var traits: NSFontTraitMask = []
        if gras { traits.insert(.boldFontMask) }
        if italique { traits.insert(.italicFontMask) }
        let fm = NSFontManager.shared
        if let f = fm.font(withFamily: famille, traits: traits, weight: gras ? 9 : 5, size: t) { return f }
        if let f = fm.font(withFamily: famille, traits: [], weight: 5, size: t) {
            return fm.convert(f, toHaveTrait: traits)
        }
        return NSFont(name: famille, size: t) ?? NSFont.systemFont(ofSize: t, weight: gras ? .bold : .regular)
    }

    static func font(_ famille: String, _ taille: CGFloat, gras: Bool = false, italique: Bool = false) -> Font {
        Font(nsFont(famille, taille, gras: gras, italique: italique) as CTFont)
    }

    private static func attribue(_ texte: String, _ f: NSFont, _ kerning: CGFloat) -> NSAttributedString {
        NSAttributedString(string: texte, attributes: [.font: f, .kern: kerning])
    }

    /// Largeur d'une ligne (mm) : la ligne la plus longue si le texte contient des retours.
    static func largeurMM(_ texte: String, _ f: NSFont, kerning: CGFloat = 0) -> CGFloat {
        texte.components(separatedBy: "\n").map { attribue($0, f, kerning).size().width }.max().map { $0 / ptParMM } ?? 0
    }

    /// Hauteur (mm) du texte coupé en lignes dans une largeur donnée (mm).
    static func hauteurMM(_ texte: String, _ f: NSFont, largeur: CGFloat, kerning: CGFloat = 0) -> CGFloat {
        let r = attribue(texte, f, kerning).boundingRect(with: CGSize(width: largeur * ptParMM, height: .greatestFiniteMagnitude),
                                                        options: [.usesLineFragmentOrigin, .usesFontLeading])
        return ceil(r.height) / ptParMM
    }

    static func hauteurLigneMM(_ f: NSFont) -> CGFloat { (f.ascender - f.descender + f.leading) / ptParMM }
}
