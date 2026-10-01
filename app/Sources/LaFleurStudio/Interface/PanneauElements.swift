import LaFleurCore
import SwiftUI

/// Champ numérique Windows 98 ; vide ou 0 = automatique (`invite` montre la valeur automatique).
struct ChampNombre: View {
    let invite: String
    @Binding var valeur: Double
    var largeur: CGFloat = 52
    @State private var texte = ""
    var body: some View {
        TextField(invite, text: $texte)
            .textFieldStyle(.plain).font(W98.police).multilineTextAlignment(.trailing)
            .padding(.horizontal, 4).frame(width: largeur, height: 20).creux()
            .onAppear { texte = valeur > 0 ? Self.format(valeur) : "" }
            .onChange(of: valeur) { _, v in if Double(texte.replacingOccurrences(of: ",", with: ".")) != v { texte = v > 0 ? Self.format(v) : "" } }
            .onSubmit(valider)
            .onChange(of: texte) { _, _ in valider() }
    }
    private func valider() {
        let t = texte.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        if t.isEmpty { if valeur != 0 { valeur = 0 } } else if let v = Double(t), v > 0, v != valeur { valeur = v }
    }
    static func format(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v) }
}

/// Panneau de l'élément sélectionné dans l'aperçu : position, taille, rotation, opacité, couleur, masqué.
struct PanneauElement: View {
    @EnvironmentObject var etat: EtatApp

    var body: some View {
        Groupe(titre: "Élément") {
            if let id = etat.elementSelectionne, let e = ElementsJaquette.element(id) {
                let a = etat.design.ajustement(id)
                HStack {
                    Text(tr(e.nom)).bold().lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button("×") { etat.elementSelectionne = nil }.buttonStyle(.w98).help("Désélectionner")
                }
                Text(tr(e.format)).foregroundStyle(W98.ombre)
                taille(e, a)
                HStack {
                    Text("Position")
                    Stepper("x \(ChampNombre.format(a.dx)) mm", value: Binding(get: { a.dx }, set: { v in etat.ajuster(id) { $0.dx = v } }), step: 0.5)
                    Stepper("y \(ChampNombre.format(a.dy)) mm", value: Binding(get: { a.dy }, set: { v in etat.ajuster(id) { $0.dy = v } }), step: 0.5)
                }
                if id == "recto-image" || id == "etiquette-pochette" {
                    Text("Glisse l'image dans l'aperçu pour choisir la partie visible.").foregroundStyle(W98.ombre)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack {
                        Text("Rotation")
                        Slider(value: Binding(get: { a.rotation }, set: { v in etat.ajuster(id) { $0.rotation = (v / 5).rounded() * 5 } }), in: -180...180)
                        Text("\(Int(a.rotation))°").frame(width: 34, alignment: .trailing)
                    }
                    HStack {
                        Text("Opacité")
                        Slider(value: Binding(get: { a.opacite }, set: { v in etat.ajuster(id) { $0.opacite = v } }), in: 0.1...1)
                    }
                }
                if e.zoneTexte != nil {
                    HStack {
                        ColorPicker("Couleur", selection: Binding(
                            get: { Color(hex: a.couleur.isEmpty ? etat.design.variante.palette.texte : a.couleur) },
                            set: { c in etat.ajuster(id) { $0.couleur = NSColor(c).hex } }), supportsOpacity: false)
                        if !a.couleur.isEmpty {
                            Button("Couleur du design") { etat.ajuster(id) { $0.couleur = "" } }.buttonStyle(.w98)
                        }
                    }
                }
                Toggle("Masquer", isOn: Binding(get: { a.masque }, set: { v in etat.ajuster(id) { $0.masque = v } })).toggleStyle(.checkbox)
                Button("Taille et place par défaut") { etat.reinitialiser(id) }.buttonStyle(.w98)
            } else {
                Text("Clique un élément dans l'aperçu (titre, logo, code, tracklist…) pour le déplacer, l'agrandir ou le masquer.")
                    .foregroundStyle(W98.ombre).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Textes : taille en points ; logos et images : taille en mm.
    @ViewBuilder private func taille(_ e: ElementsJaquette.Element, _ a: Ajustement) -> some View {
        if let zone = e.zoneTexte, let pt = e.taillePt {
            let ech = etat.design.echelle(zone)
            HStack {
                Stepper("Taille \(String(format: "%.1f", pt * ech)) pt",
                        value: Binding(get: { pt * ech },
                                       set: { v in etat.modifierDesign { $0.echelles[zone] = max(0.3, min(4, v / pt)) } }),
                        step: 0.5)
            }
        } else if let mm = e.tailleMM {
            HStack {
                Text("Taille")
                Slider(value: Binding(get: { a.echelle }, set: { v in etat.ajuster(e.id) { $0.echelle = (v * 20).rounded() / 20 } }),
                       in: e.id == "recto-image" || e.id == "etiquette-pochette" ? 1...3 : 0.3...3)
                Text("\(ChampNombre.format((mm[0] * a.echelle * 10).rounded() / 10)) × \(ChampNombre.format((mm[1] * a.echelle * 10).rounded() / 10)) mm")
                    .fixedSize()
            }
        } else {
            HStack {
                Text("Taille")
                Slider(value: Binding(get: { a.echelle }, set: { v in etat.ajuster(e.id) { $0.echelle = (v * 20).rounded() / 20 } }), in: 0.3...3)
                Text("\(Int((a.echelle * 100).rounded())) %").frame(width: 42, alignment: .trailing)
            }
        }
    }
}

/// Taille de chaque texte, en points, avec retour à la taille par défaut (demande 3).
struct GroupeTailles: View {
    @EnvironmentObject var etat: EtatApp
    var body: some View {
        Groupe(titre: "Tailles") {
            ForEach(ElementsJaquette.tous.filter { $0.zoneTexte != nil }) { e in
                let zone = e.zoneTexte!, pt = e.taillePt ?? 5
                let ech = etat.design.echelle(zone)
                HStack(spacing: 4) {
                    Text(tr(e.nom)).lineLimit(1).truncationMode(.tail).help(tr(e.nom))
                    Spacer(minLength: 2)
                    Stepper("\(String(format: "%.1f", pt * ech)) pt",
                            value: Binding(get: { pt * ech }, set: { v in etat.modifierDesign { $0.echelles[zone] = max(0.3, min(4, v / pt)) } }),
                            step: 0.5)
                        .fixedSize()
                    Button("↺") { etat.modifierDesign { $0.echelles[zone] = nil } }.buttonStyle(.w98)
                        .help("Taille par défaut").disabled(etat.design.echelles[zone] == nil)
                }
            }
            Text("Sous 5 pt, l'app prévient : c'est trop petit pour être lu une fois imprimé.").foregroundStyle(W98.ombre)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Étiquettes de K7 : petite pochette, pochette en fond ou sans pochette (demande 4).
struct GroupeEtiquettes: View {
    @EnvironmentObject var etat: EtatApp
    var body: some View {
        let d = etat.design
        Groupe(titre: "Étiquettes de K7") {
            Picker("Pochette", selection: Binding(get: { d.etiquettePochette }, set: { v in etat.modifierDesign { $0.etiquettePochette = v } })) {
                ForEach(ModeEtiquette.allCases, id: \.self) { Text(tr($0.nom)).tag($0) }
            }
            .pickerStyle(.radioGroup)
            if d.etiquettePochette == .fond {
                HStack {
                    Text("Voile")
                    Slider(value: Binding(get: { d.voileEtiquette }, set: { v in etat.modifierDesign { $0.voileEtiquette = v } }), in: 0...0.9)
                    Text("\(Int(d.voileEtiquette * 100)) %").frame(width: 36, alignment: .trailing)
                }
                curseur("Position horizontale", d.cadrageEtiquetteX) { v in etat.modifierDesign { $0.cadrageEtiquetteX = v } }
                curseur("Position verticale", d.cadrageEtiquetteY) { v in etat.modifierDesign { $0.cadrageEtiquetteY = v } }
                Text("Ou glisse l'image dans l'aperçu des étiquettes.").foregroundStyle(W98.ombre)
            }
        }
    }
}

/// Curseur 0 → 100 % (gauche/haut → droite/bas).
func curseur(_ titre: String, _ valeur: Double, _ changer: @escaping (Double) -> Void) -> some View {
    HStack {
        Text(LocalizedStringKey(titre)).fixedSize()
        Slider(value: Binding(get: { valeur }, set: changer), in: 0...1)
        Text("\(Int((valeur * 100).rounded())) %").frame(width: 36, alignment: .trailing)
    }
}
