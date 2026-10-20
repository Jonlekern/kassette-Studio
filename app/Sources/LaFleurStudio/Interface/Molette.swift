import AppKit

/// La molette fait défiler la zone qui peut défiler sous la souris : la plus proche (liste, champ de texte long),
/// sinon la colonne qui la contient.
///
/// Sur le Mac, les colonnes ne défilaient pas à la molette quand la souris était sur un curseur, un champ, une liste
/// ou le panneau Élément (seule leur barre de défilement marchait) : l'événement s'arrêtait en chemin. L'app le prend
/// donc en main, pour toutes les fenêtres.
@MainActor
enum Molette {
    private static var moniteur: Any?

    static func installer() {
        guard moniteur == nil else { return }
        moniteur = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { e in
            guard let w = e.window else { return e }
            return defiler(e, fenetre: w, point: e.locationInWindow) ? nil : e
        }
    }

    /// `point` : position dans la fenêtre. Renvoie true si une zone a défilé (l'événement est alors consommé).
    @discardableResult
    static func defiler(_ e: NSEvent, fenetre w: NSWindow, point: NSPoint) -> Bool {
        // Souris classique : en lignes ; trackpad et Magic Mouse : en points.
        let dy = e.scrollingDeltaY * (e.hasPreciseScrollingDeltas ? 1 : 14)
        guard dy != 0, abs(e.scrollingDeltaY) >= abs(e.scrollingDeltaX),
              let racine = w.contentView, let cadre = racine.superview,
              let touchee = racine.hitTest(cadre.convert(point, from: nil)) else { return false }
        var v: NSView? = touchee
        while let courante = v {
            if let sv = courante as? NSScrollView, deplacer(sv, dy) { return true }
            v = courante.superview
        }
        return false
    }

    /// Fait défiler `sv` de `dy` points si elle le peut dans ce sens.
    private static func deplacer(_ sv: NSScrollView, _ dy: CGFloat) -> Bool {
        guard let doc = sv.documentView else { return false }
        let clip = sv.contentView
        let vu = clip.bounds
        let maxi = doc.frame.height - vu.height
        guard maxi > 0.5 else { return false }
        // dy > 0 : la molette monte, on revient vers le haut du contenu.
        let y = doc.isFlipped ? vu.origin.y - dy : vu.origin.y + dy
        let borne = min(max(y, 0), maxi)
        guard abs(borne - vu.origin.y) > 0.01 else { return false }
        clip.scroll(to: NSPoint(x: vu.origin.x, y: borne))
        sv.reflectScrolledClipView(clip)
        return true
    }
}
