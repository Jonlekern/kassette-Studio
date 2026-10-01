import LaFleurCore
import SwiftUI

/// Retouches à la main dans l'aperçu (sélection, glisser, taille, recadrage) et annulation.
extension EtatApp {
    /// Change le design en gardant l'ancien pour « Annuler ».
    func modifierDesign(_ changement: (inout Design) -> Void) {
        var d = design
        let avant = d
        changement(&d)
        guard d != avant else { return }
        memoriser(avant)
        design = d
    }

    func memoriser(_ d: Design) {
        annulations.append(d)
        if annulations.count > 60 { annulations.removeFirst(annulations.count - 60) }
    }

    func annuler() {
        guard let d = annulations.popLast() else { return }
        design = d
        statut = String(localized: "Modification annulée")
    }

    func ajuster(_ id: String, _ changement: (inout Ajustement) -> Void) {
        modifierDesign { d in
            var a = d.ajustement(id)
            changement(&a)
            d.ajustements[id] = a.estNeutre ? nil : a
        }
    }

    func reinitialiser(_ id: String) {
        modifierDesign { d in
            d.ajustements[id] = nil
            if let zone = ElementsJaquette.element(id)?.zoneTexte { d.echelles[zone] = nil }
            if id == "recto-image" { d.cadrageX = 0.5; d.cadrageY = 0.5 }
            if id == "etiquette-pochette" { d.cadrageEtiquetteX = 0.5; d.cadrageEtiquetteY = 0.5 }
        }
    }

    /// Mode édition de l'aperçu : clic = sélection, glisser = déplacer (ou recadrer une image).
    var edition: EditionJaquette {
        EditionJaquette(
            selection: elementSelectionne,
            choisir: { [weak self] id in self?.elementSelectionne = id },
            deplacer: { [weak self] id, dx, dy in
                self?.ajuster(id) { a in
                    a.dx = ((a.dx + Double(dx)) * 2).rounded() / 2
                    a.dy = ((a.dy + Double(dy)) * 2).rounded() / 2
                }
            },
            recadrer: { [weak self] id, fx, fy in
                self?.modifierDesign { d in
                    let borne = { (v: Double) in min(1, max(0, v)) }
                    if id == "etiquette-pochette" {
                        d.cadrageEtiquetteX = borne(d.cadrageEtiquetteX + Double(fx))
                        d.cadrageEtiquetteY = borne(d.cadrageEtiquetteY + Double(fy))
                    } else {
                        d.cadrageX = borne(d.cadrageX + Double(fx))
                        d.cadrageY = borne(d.cadrageY + Double(fy))
                    }
                }
            })
    }
}
