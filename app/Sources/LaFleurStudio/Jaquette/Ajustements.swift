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

private struct ElementAjustable: ViewModifier {
    let id: String
    let a: Ajustement
    let u: CGFloat
    let angle: Double
    @Environment(\.editionJaquette) private var edition

    /// Déplacement vu à l'écran → déplacement dans le repère (tourné) de l'élément.
    private func local(_ t: CGSize) -> CGSize {
        let r = angle * .pi / 180
        return CGSize(width: t.width * cos(r) + t.height * sin(r), height: -t.width * sin(r) + t.height * cos(r))
    }
    @State private var glisse: CGSize = .zero

    func body(content: Content) -> some View {
        let choisi = edition?.selection == id
        let cadre = content
            .scaleEffect(a.echelle)
            .rotationEffect(.degrees(a.rotation))
            // Masqué : invisible à l'impression, en transparence dans l'aperçu pour pouvoir le retrouver.
            .opacity(a.masque ? (edition == nil ? 0 : 0.2) : a.opacite)
            .overlay {
                if choisi {
                    Rectangle().stroke(Color(red: 0.1, green: 0.45, blue: 1), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .scaleEffect(a.echelle).rotationEffect(.degrees(a.rotation))
                }
            }
            .offset(x: a.dx * u + glisse.width, y: a.dy * u + glisse.height)
        if let edition {
            cadre
                .contentShape(Rectangle())
                .onTapGesture { edition.choisir(id) }
                .gesture(DragGesture(minimumDistance: 3)
                    .onChanged { v in
                        if edition.selection != id { edition.choisir(id) }
                        glisse = local(v.translation)
                    }
                    .onEnded { v in
                        glisse = .zero
                        let l = local(v.translation)
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
                .overlay {
                    if edition.selection == id {
                        Rectangle().stroke(Color(red: 0.1, green: 0.45, blue: 1), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { edition.choisir(id) }
                .gesture(DragGesture(minimumDistance: 3).onEnded { v in
                    let r = angle * .pi / 180
                    let tx = v.translation.width * cos(r) + v.translation.height * sin(r)
                    let ty = -v.translation.width * sin(r) + v.translation.height * cos(r)
                    if edition.selection != id { edition.choisir(id) }
                    // Glisser vers la droite montre la partie gauche de l'image : le cadrage diminue.
                    edition.recadrer(id, -tx / u / largeur, -ty / u / hauteur)
                })
        } else {
            vue
        }
    }
}
