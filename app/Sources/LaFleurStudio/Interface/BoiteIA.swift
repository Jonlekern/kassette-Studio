import LaFleurCore
import SwiftUI

/// Badge visible quand le mode IA expert est actif.
struct BadgeExpert: View {
    var body: some View {
        Text("IA expert").font(W98.policeGras).foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 2).background(W98.rouge)
            .help("Mode expert : l'IA peut aussi agir sur la Mixtape, les réglages de la cassette et la Collection (Réglages → IA).")
    }
}

/// Boîte « Modifier avec l'IA » (demande 8) : on écrit une modification, l'IA l'applique et résume.
struct BoiteModifierIA: View {
    @EnvironmentObject var etat: EtatApp
    @State private var demande = ""
    var exemple = "Ex. « titre plus gros », « retire la pochette de l'étiquette », « code-barres de 30 mm », « décale l'image vers la gauche »"

    var body: some View {
        Groupe(titre: "Modifier avec l'IA · \(etat.fournisseurIA.nom)") {
            if etat.modeExpert { BadgeExpert() }
            if !etat.filModif.isEmpty {
                ScrollViewReader { defil in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(etat.filModif) { m in ligne(m).id(m.id) }
                        }
                        .padding(4).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 240).creux(W98.bulle)
                    .onChange(of: etat.filModif.count) { _, _ in if let d = etat.filModif.last { defil.scrollTo(d.id, anchor: .bottom) } }
                }
            }
            ZStack(alignment: .topLeading) {
                TextEditor(text: $demande).font(W98.police).scrollContentBackground(.hidden).padding(2)
                if demande.isEmpty {
                    Text(LocalizedStringKey(exemple)).foregroundStyle(W98.grisFonce).padding(.horizontal, 6).padding(.vertical, 2)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 64).background(Color.white).creux()
            HStack {
                Button("Appliquer") { envoyer() }.buttonStyle(.w98Gras).keyboardShortcut(.return, modifiers: .command)
                    .disabled(demande.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || etat.occupe)
                    .help("Appliquer (⌘↩)")
                Spacer()
                if !etat.filModif.isEmpty { Button("Effacer le fil") { etat.effacerFilModif() }.buttonStyle(.w98) }
            }
        }
    }

    private func envoyer() {
        let t = demande
        demande = ""
        etat.modifierAvecIA(t)
    }

    @ViewBuilder private func ligne(_ m: MessageModif) -> some View {
        if m.deIA {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: etat.fournisseurIA.nom).font(W98.policeGras)
                Text(verbatim: m.texte).font(W98.police).fixedSize(horizontal: false, vertical: true)
                ForEach(m.changements, id: \.self) { c in
                    Text(verbatim: "• " + c).font(.custom("Menlo", size: 10)).foregroundStyle(W98.ombre)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let id = m.echange {
                    if m.annule {
                        Text("Annulé").foregroundStyle(W98.ombre).italic()
                    } else if etat.instantanesIA[id] != nil {
                        Button("Annuler") { etat.annulerEchange(id) }.buttonStyle(.w98)
                    }
                }
            }
        } else {
            Text(verbatim: "› " + m.texte).font(W98.policeGras).foregroundStyle(W98.bleu).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Historique des demandes faites à l'IA pour une cassette (demande 7).
struct HistoriqueIAVue: View {
    @EnvironmentObject var etat: EtatApp
    /// La cassette affichée (la courante si nil) ; en lecture seule depuis la Collection.
    var projet: Projet?
    @State private var choisi: UUID?

    private var echanges: [EchangeIA] { (projet ?? etat.projet).echangesIA }
    private var courante: Bool { projet == nil || projet?.id == etat.projet.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if echanges.isEmpty {
                Text("Aucune demande à l'IA pour cette cassette.").foregroundStyle(W98.ombre)
            } else {
                let total = echanges.compactMap(\.cout).reduce(0, +)
                Text(total > 0 ? "\(echanges.count) demandes · environ \(String(format: "%.2f", total)) $" : "\(echanges.count) demandes")
                    .foregroundStyle(W98.ombre)
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(echanges.reversed()) { e in ligne(e) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 300)
                if courante {
                    Button("Effacer l'historique") { etat.effacerHistoriqueIA() }.buttonStyle(.w98)
                }
            }
        }
    }

    @ViewBuilder private func ligne(_ e: EchangeIA) -> some View {
        let ouvert = choisi == e.id
        VStack(alignment: .leading, spacing: 3) {
            Button { choisi = ouvert ? nil : e.id } label: {
                HStack(alignment: .top, spacing: 4) {
                    Text(ouvert ? "▾" : "▸")
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: e.demande).bold().lineLimit(ouvert ? nil : 1)
                        Text(verbatim: e.date.formatted(date: .abbreviated, time: .shortened) + " · " + e.moteur
                             + (e.cout.map { " · " + String(format: "%.3f $", $0) } ?? ""))
                            .foregroundStyle(W98.ombre).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if ouvert {
                Text(verbatim: e.reponse).fixedSize(horizontal: false, vertical: true)
                ForEach(e.changements, id: \.self) { c in
                    Text(verbatim: "• " + c).font(.custom("Menlo", size: 10)).foregroundStyle(W98.ombre).fixedSize(horizontal: false, vertical: true)
                }
                if courante {
                    HStack {
                        if e.designApres != nil {
                            Button("Revenir à cette version") { etat.revenir(a: e) }.buttonStyle(.w98)
                        }
                        if e.refaisable {
                            Button("Refaire cette demande") { etat.modifierAvecIA(e.demande) }.buttonStyle(.w98).disabled(etat.occupe)
                        }
                    }
                }
            }
        }
        .padding(4).background(ouvert ? Color.white : Color.clear)
    }
}
