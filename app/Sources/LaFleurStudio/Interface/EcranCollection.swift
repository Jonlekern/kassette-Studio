import LaFleurCore
import SwiftUI

/// Toutes les cassettes (LFS-001, LFS-002…) : ouvrir, dupliquer, supprimer.
struct EcranCollection: View {
    @EnvironmentObject var etat: EtatApp
    let ouvrir: (Projet) -> Void
    var reimprimer: () -> Void = {}
    @State private var recherche = ""
    @State private var aSupprimer: Projet?

    private var liste: [Projet] {
        let r = recherche.lowercased()
        return etat.collection.filter { r.isEmpty || "\($0.numeroCatalogue) \($0.titre) \($0.artiste)".lowercased().contains(r) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Champ(invite: "Chercher une cassette, un artiste…", texte: $recherche).frame(width: 280)
                Spacer()
                Button("Nouvelle cassette…") { etat.nouvelleCassette() }.buttonStyle(.w98Gras)
            }
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 214), spacing: 16)], spacing: 16) {
                    ForEach(liste) { p in
                        VStack(alignment: .leading, spacing: 6) {
                            // Le recto de sa jaquette (ou la pochette si le design n'est pas encore fait).
                            ImageRecto(mise: Mise(projet: p, design: p.design ?? Design()), largeur: 64, hauteur: 64, u: 196 / 64)
                                .frame(width: 196, height: 196).clipped()
                            HStack {
                                Text(p.numeroCatalogue).bold()
                                Spacer()
                                Text(p.enregistree.count == 2 || (p.enregistree.contains(.a) && p.faceB.isEmpty) ? "Enregistrée" : "Brouillon")
                                    .foregroundStyle(p.enregistree.isEmpty ? W98.grisFonce : W98.vert).bold()
                            }
                            Text(p.titre.isEmpty ? "Sans titre" : p.titre).bold().lineLimit(1)
                            Text("\(p.artiste) · \(tr(p.mode == .album ? "album" : "mixtape")) · \(p.cassette.longueur.nom)").foregroundStyle(W98.ombre).lineLimit(1)
                            HStack(spacing: 4) {
                                Button("Ouvrir") { ouvrir(p) }.buttonStyle(.w98Gras)
                                Button("Dupliquer") { etat.dupliquer(p) }.buttonStyle(.w98)
                                Button("×") { aSupprimer = p }.buttonStyle(.w98).help("Supprimer")
                            }
                            Button("Réimprimer la jaquette") { ouvrir(p); reimprimer() }.buttonStyle(.w98)
                        }
                        .padding(8).relief()
                    }
                }
                .padding(16)
            }
            .background(W98.grisFonce).creux(W98.grisFonce)
            let prochain = String(format: "%@-%03d", etat.prefs.prefixeCatalogue, etat.prefs.prochainNumero)
            Text(etat.collection.count > 1 ? "\(etat.collection.count) cassettes · prochain numéro : \(prochain)"
                                           : "\(etat.collection.count) cassette · prochain numéro : \(prochain)")
        }
        .onAppear { etat.rafraichirCollection() }
        .alert("Supprimer \(aSupprimer?.numeroCatalogue ?? "") ?", isPresented: Binding(get: { aSupprimer != nil }, set: { if !$0 { aSupprimer = nil } })) {
            Button("Supprimer", role: .destructive) { if let p = aSupprimer { etat.supprimer(p) }; aSupprimer = nil }
            Button("Annuler", role: .cancel) { aSupprimer = nil }
        } message: { Text("La cassette est retirée de la collection. Tes fichiers audio ne sont pas touchés.") }
    }
}
