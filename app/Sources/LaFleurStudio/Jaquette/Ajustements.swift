import LaFleurCore
import SwiftUI

/// Mode édition de l'aperçu : clic pour sélectionner un élément, glisser pour le déplacer.
/// Absent (nil) à l'export et à l'impression : rien n'y est sélectionnable ni encadré.
struct EditionJaquette {
    var selection: String?
    var choisir: (String) -> Void
    /// Déplacement terminé, en mm.
    var deplacer: (String, CGFloat, CGFloat) -> Void
    /// Image glissée dans son cadre (recadrage) : identifiant, déplacement en fraction du cadre.
    var recadrer: (String, CGFloat, CGFloat) -> Void
}

private struct CleEdition: EnvironmentKey { static let defaultValue: EditionJaquette? = nil }

extension EnvironmentValues {
    var editionJaquette: EditionJaquette? {
        get { self[CleEdition.self] }
        set { self[CleEdition.self] = newValue }
    }
}

extension View {
    /// Applique le réglage libre de l'élément `id` (décalage, taille, rotation, opacité, masqué),
    /// et le rend sélectionnable et déplaçable dans l'aperçu. À poser avant `.placer(…)`.
    /// `angle` : rotation du parent (tranche +90°, recto paysage −90°), pour que le glisser suive la souris.
    func element(_ id: String, _ mise: Mise, _ u: CGFloat, angle: Double = 0) -> some View {
        modifier(ElementAjustable(id: id, a: mise.design.ajustement(id), u: u, angle: angle))
    }
}

/// Zone (panneau) qui contient les éléments : un élément glissé n'en sort pas.
enum ZoneJaquette {
    static let nom = "zone-jaquette"
}

extension View {
    /// Pose sur chaque panneau (recto, tranche, rabat, volet, étiquette, obi) : les éléments y restent quand on les glisse.
    func zoneJaquette() -> some View { coordinateSpace(.named(ZoneJaquette.nom)) }
}

/// Place de l'élément dans sa zone, vue à l'écran (sans rotation).
private struct PlaceDansZone: Equatable {
    var centre: CGPoint = .zero
    var zone: CGSize = .zero
}

/// Déplacement vu à l'écran → déplacement dans le repère (tourné de `angle` degrés) de l'élément.
func versRepereTourne(_ t: CGSize, angle: Double) -> CGSize {
    let r = angle * .pi / 180
    return CGSize(width: t.width * cos(r) + t.height * sin(r), height: -t.width * sin(r) + t.height * cos(r))
}

private struct ElementAjustable: ViewModifier {
    let id: String
    let a: Ajustement
    let u: CGFloat
    let angle: Double
    @Environment(\.editionJaquette) private var edition
    @State private var glisse: CGSize = .zero
    @State private var place = PlaceDansZone()
    /// Centre de l'élément au début du glisser.
    @State private var depart: CGPoint?

    /// Le glisser est mesuré à l'écran (repère global, sans rotation) : on le limite pour que le centre de l'élément
    /// reste dans sa zone, puis on le tourne dans le repère de l'élément (tranche, recto paysage).
    private func deplacement(_ t: CGSize) -> CGSize {
        var t = t
        if let c = depart, place.zone.width > 0, place.zone.height > 0 {
            let marge = min(2 * u, place.zone.width / 2, place.zone.height / 2)
            t.width = min(max(c.x + t.width, marge), place.zone.width - marge) - c.x
            t.height = min(max(c.y + t.height, marge), place.zone.height - marge) - c.y
        }
        return versRepereTourne(t, angle: angle)
    }

    func body(content: Content) -> some View {
        let choisi = edition?.selection == id
        let tourne = abs(angle.truncatingRemainder(dividingBy: 180)) == 90
        let cadre = content
            .onGeometryChange(for: PlaceDansZone.self) { g in
                let f = g.frame(in: .named(ZoneJaquette.nom))
                guard let b = g.bounds(of: .named(ZoneJaquette.nom)) else { return PlaceDansZone() }
                return PlaceDansZone(centre: CGPoint(x: f.midX, y: f.midY),
                                     zone: tourne ? CGSize(width: b.height, height: b.width) : b.size)
            } action: { place = $0 }
            .scaleEffect(a.echelle)
            .rotationEffect(.degrees(a.rotation))
            // Masqué : invisible à l'impression, en transparence dans l'aperçu pour pouvoir le retrouver.
            .opacity(a.masque ? (edition == nil ? 0 : 0.2) : a.opacite)
            .overlay {
                if choisi {
                    // À l'intérieur de l'élément : sur la tranche, un cadre posé sur le bord était caché par les plis.
                    Rectangle().strokeBorder(Color(red: 0.1, green: 0.45, blue: 1), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .scaleEffect(a.echelle).rotationEffect(.degrees(a.rotation))
                }
            }
            .offset(x: a.dx * u + glisse.width, y: a.dy * u + glisse.height)
        if let edition {
            cadre
                .contentShape(Rectangle())
                .onTapGesture { edition.choisir(id) }
                .gesture(DragGesture(minimumDistance: 3, coordinateSpace: .global)
                    .onChanged { v in
                        if edition.selection != id { edition.choisir(id) }
                        if depart == nil { depart = place.centre }
                        glisse = deplacement(v.translation)
                    }
                    .onEnded { v in
                        let l = deplacement(v.translation)
                        glisse = .zero
                        depart = nil
                        edition.deplacer(id, l.width / u, l.height / u)
                    })
        } else {
            cadre
        }
    }
}

extension View {
    /// Image rognée (recto, étiquette) : sélectionnable, et glisser la souris choisit la partie visible.
    /// `largeur`, `hauteur` : taille du cadre en mm.
    func cadrageImage(_ mise: Mise, _ u: CGFloat, id: String = "recto-image", largeur: CGFloat = 64, hauteur: CGFloat = 64,
                      angle: Double = 0) -> some View {
        modifier(ImageRecadrable(id: id, masque: mise.design.ajustement(id).masque, u: u, largeur: largeur, hauteur: hauteur, angle: angle))
    }
}

private struct ImageRecadrable: ViewModifier {
    let id: String
    let masque: Bool
    let u: CGFloat
    let largeur: CGFloat
    let hauteur: CGFloat
    let angle: Double
    @Environment(\.editionJaquette) private var edition

    func body(content: Content) -> some View {
        let vue = content.opacity(masque ? (edition == nil ? 0 : 0.2) : 1)
        if let edition {
            vue
                // Cadre dessiné à l'intérieur de l'image : sur les bords, il était caché par la coupe et les plis.
                .overlay {
                    if edition.selection == id {
                        Rectangle().strokeBorder(Color(red: 0.1, green: 0.45, blue: 1), style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                            .padding(1.5)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { edition.choisir(id) }
                .gesture(DragGesture(minimumDistance: 3, coordinateSpace: .global)
                    .onChanged { _ in if edition.selection != id { edition.choisir(id) } }
                    .onEnded { v in
                        let t = versRepereTourne(v.translation, angle: angle)
                        // Glisser vers la droite montre la partie gauche de l'image : le cadrage diminue.
                        edition.recadrer(id, -t.width / u / largeur, -t.height / u / hauteur)
                    })
        } else {
            vue
        }
    }
}
