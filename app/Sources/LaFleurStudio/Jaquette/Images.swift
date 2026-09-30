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
            req.setValue("LaFleurStudio/0.1 ( https://lafleurstudio.ch )", forHTTPHeaderField: "User-Agent")
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
    @ObservedObject private var images = Images.partage
    var body: some View {
        if let i = images.image(url) {
            Image(nsImage: i).resizable().aspectRatio(contentMode: remplir ? .fill : .fit).opacity(opacite)
        } else {
            Rectangle().fill(Color.gray.opacity(0.25))
        }
    }
}
