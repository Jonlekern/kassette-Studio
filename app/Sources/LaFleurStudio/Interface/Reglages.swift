import LaFleurCore
import SwiftUI

/// Réglages (⌘,) : audio, platine, Claude, Spotify, langue, conditions.
struct Reglages: View {
    @EnvironmentObject var etat: EtatApp
    @State private var rubrique = "Audio"
    private let rubriques = ["Audio", "Platine", "Claude", "Spotify", "Langue", "Conditions"]

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(rubriques, id: \.self) { r in
                    Button { rubrique = r } label: {
                        Text(r).padding(.horizontal, 8).padding(.vertical, 5).frame(maxWidth: .infinity, alignment: .leading)
                            .background(rubrique == r ? W98.bleu : .clear).foregroundStyle(rubrique == r ? .white : .black)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(2).frame(width: 150).creux()
            VStack(alignment: .leading, spacing: 12) {
                Text(rubrique).font(.custom("Arial", size: 15).bold())
                switch rubrique {
                case "Audio": audio
                case "Platine": platine
                case "Claude": claude
                case "Spotify": Groupe(titre: "Compte Spotify") { ReglageSpotify() }
                case "Langue": langue
                default: Groupe(titre: "Conditions d'utilisation") { TexteConditions() }
                }
                Spacer()
            }
        }
        .padding(14).frame(width: 760, height: 520).background(W98.gris).w98()
    }

    private var audio: some View {
        VStack(alignment: .leading, spacing: 12) {
            Groupe(titre: "Sortie vers la platine") { ChoixSortie() }
            Groupe(titre: "Lecture") {
                Toggle("Égaliser le volume entre les morceaux", isOn: $etat.prefs.egaliserVolume).toggleStyle(.checkbox)
                Text("Baisse les morceaux les plus forts au niveau du plus calme. Désactivé : chaque fichier est joué tel quel.")
                    .foregroundStyle(W98.ombre)
            }
        }
    }

    private func secondes(_ titre: String, _ valeur: Binding<TimeInterval>, _ plage: ClosedRange<TimeInterval>, pas: TimeInterval = 1) -> some View {
        Stepper(value: valeur, in: plage, step: pas) { Text("\(titre) : \(String(format: pas < 1 ? "%.1f" : "%.0f", valeur.wrappedValue)) s") }
    }

    private var platine: some View {
        VStack(alignment: .leading, spacing: 12) {
            Groupe(titre: "Type de platine") {
                Picker("", selection: $etat.prefs.platine.type) {
                    Text("Simple, sans auto-reverse : l'app dit de retourner la cassette").tag(TypePlatine.simple)
                    Text("Auto-reverse : la platine se retourne toute seule").tag(TypePlatine.autoReverse)
                }
                .pickerStyle(.radioGroup).labelsHidden()
            }
            Groupe(titre: "Auto-reverse") {
                let auto = etat.prefs.platine.type == .autoReverse
                Stepper(value: Binding(get: { (etat.prefs.platine.dureeReelleFace ?? Double(etat.projet.cassette.longueur.minutesParFace * 60)) / 60 },
                                       set: { etat.prefs.platine.dureeReelleFace = $0 * 60 }), in: 10...70, step: 0.25) {
                    Text("Durée réelle d'une face : \(formaterDuree(etat.prefs.platine.dureeReelleFace ?? Double(etat.projet.cassette.longueur.minutesParFace * 60)))")
                }
                .disabled(!auto)
                secondes("Délai d'inversion", $etat.prefs.platine.delaiInversion, 0...10, pas: 0.1).disabled(!auto)
                MesureInversion().disabled(!auto)
            }
            Groupe(titre: "Timing") {
                secondes("Blanc de début de bande", $etat.prefs.platine.amorce, 0...20)
                secondes("Blanc entre les morceaux", $etat.prefs.platine.blanc, 0...10)
                secondes("Marge de fin de face", $etat.prefs.platine.margeFin, 0...120, pas: 5)
                Stepper(value: $etat.prefs.platine.compteARebours, in: 0...15) { Text("Compte à rebours : \(etat.prefs.platine.compteARebours) s") }
            }
        }
    }

    private var claude: some View {
        VStack(alignment: .leading, spacing: 12) {
            Groupe(titre: "Clé API") {
                Champ(invite: "sk-ant-…", texte: $etat.cleClaude, secret: true)
                Text("Rangée dans le trousseau du Mac.").foregroundStyle(W98.ombre)
            }
            Groupe(titre: "Recherche web") {
                Toggle("Claude peut chercher sur des sites choisis (sources citées)", isOn: $etat.prefs.rechercheWebClaude).toggleStyle(.checkbox)
            }
        }
    }

    private var langue: some View {
        Groupe(titre: "Langue de l'app et de Claude") {
            Picker("", selection: $etat.prefs.langue) {
                Text("Français").tag("fr"); Text("English").tag("en"); Text("Русский").tag("ru"); Text("Deutsch").tag("de")
            }
            .pickerStyle(.radioGroup).labelsHidden()
            Text("Claude répond dans cette langue. La traduction complète de l'interface arrive dans une prochaine étape.")
                .foregroundStyle(W98.ombre)
        }
    }
}

/// Mesure du délai d'inversion : on clique quand la bande arrive au bout, puis quand la platine repart.
struct MesureInversion: View {
    @EnvironmentObject var etat: EtatApp
    @State private var debut: Date?
    var body: some View {
        HStack {
            if let debut {
                Button("La platine repart : clique ici") {
                    etat.prefs.platine.delaiInversion = (Date().timeIntervalSince(debut) * 10).rounded() / 10
                    self.debut = nil
                }
                .buttonStyle(.w98Gras)
            } else {
                Button("Mesurer… (clique au bout de la bande)") { debut = Date() }.buttonStyle(.w98)
            }
        }
    }
}
