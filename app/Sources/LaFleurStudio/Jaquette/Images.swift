import AppKit
import SwiftUI

/// Images des jaquettes (pochettes, covers, scans, code Spotify, image perso), gardées en mémoire.
/// Les rendus PDF/PNG ne savent pas attendre un téléchargement : on précharge avant d'exporter.
@MainActor
final class Images: ObservableObject {
    static let partage = Images()
    @Published private(set) var cache: [URL: NSImage] = [:]
    private var enCours: Set<URL> = []
    private var echecs: Set<URL> = []

    /// L'image si elle est prête ; sinon lance son chargement et renvoie nil.
    func image(_ url: URL?) -> NSImage? {
        guard let url else { return nil }
        if let i = cache[url] { return i }
        if !enCours.contains(url) && !echecs.contains(url) {
            enCours.insert(url)
            // Hors de la mise à jour de la vue en cours.
            Task { @MainActor in await self.charger(url) }
        }
        return nil
    }

    func charger(_ url: URL) async {
        enCours.insert(url)
        defer { enCours.remove(url) }
        if cache[url] != nil { return }
        let img: NSImage?
        if url.isFileURL {
            img = NSImage(contentsOf: url)
        } else {
            var req = URLRequest(url: url)
            req.setValue("STUDIOLAFLEUR/0.1 ( https://lafleurstudio.ch )", forHTTPHeaderField: "User-Agent")
            let data = try? await URLSession.shared.data(for: req).0
            img = data.flatMap(NSImage.init(data:))
        }
        if let img { cache[url] = img } else { echecs.insert(url) }
    }

    func precharger(_ urls: [URL?]) async {
        await withTaskGroup(of: Void.self) { g in
            for u in Set(urls.compactMap { $0 }) where cache[u] == nil { g.addTask { await self.charger(u) } }
        }
    }

    /// JPEG d'au plus `cote` px, pour l'envoyer à Claude.
    func jpeg(_ url: URL, cote: CGFloat = 1024) async -> Data? {
        await charger(url)
        return cache[url].flatMap { Self.jpeg($0, cote: cote) }
    }

    static func jpeg(_ img: NSImage, cote: CGFloat = 1024) -> Data? {
        guard let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let f = min(1, cote / CGFloat(max(cg.width, cg.height)))
        let w = max(1, Int(CGFloat(cg.width) * f)), h = max(1, Int(CGFloat(cg.height) * f))
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let petit = ctx.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: petit).representation(using: .jpeg, properties: [.compressionFactor: 0.85])
    }
}

/// Image chargée depuis le cache, remplie dans son cadre.
struct ImageCache: View {
    let url: URL?
    var remplir = true
    var opacite = 1.0
    /// En mode remplir : partie visible quand l'image est rognée (0 = gauche / haut, 0,5 = centre, 1 = droite / bas).
    var position = CGPoint(x: 0.5, y: 0.5)
    /// Agrandissement en plus du remplissage (1 = juste de quoi remplir).
    var zoom: CGFloat = 1
    @ObservedObject private var images = Images.partage
    var body: some View {
        if let i = images.image(url) {
            if remplir && (position != CGPoint(x: 0.5, y: 0.5) || zoom != 1) {
                GeometryReader { g in
                    let iw = max(1, i.size.width), ih = max(1, i.size.height)
                    let k = max(g.size.width / iw, g.size.height / ih) * max(1, zoom)
                    let w = iw * k, h = ih * k
                    Image(nsImage: i).resizable().frame(width: w, height: h)
                        .offset(x: (g.size.width - w) * min(1, max(0, position.x)), y: (g.size.height - h) * min(1, max(0, position.y)))
                        .opacity(opacite)
                }
            } else {
                Image(nsImage: i).resizable().aspectRatio(contentMode: remplir ? .fill : .fit).opacity(opacite)
            }
        } else {
            Rectangle().fill(Color.gray.opacity(0.25))
        }
    }
}
