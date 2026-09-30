import LaFleurCore
import SwiftUI

/// Réglages (⌘,) : audio, platine, impression, Claude, Spotify, sources, langue, conditions.
struct Reglages: View {
    @EnvironmentObject var etat: EtatApp
    @State private var rubrique = "Audio"
    private let rubriques = ["Audio", "Platine", "Impression", "Claude", "Spotify", "Sources", "Langue", "Conditions"]

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
                case "Impression": ScrollView { impression }
                case "Sources": sources
                case "Claude": claude
                case "Spotify": ScrollView { VStack(alignment: .leading, spacing: 12) { Groupe(titre: "Compte Spotify") { ReglageSpotify() }; GuideSpotify() } }
                case "Langue": langue
                default: Groupe(titre: "Conditions d'utilisation") { TexteConditions() }
                }
                Spacer()
            }
        }
        .padding(14).frame(width: 760, height: 560).background(W98.gris).w98().preferredColorScheme(.light)
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

    @State private var papierCalibrage = "A4"
    @State private var regleH = ""
    @State private var regleV = ""
    @State private var bordGauche = ""
    @State private var bordHaut = ""

    private func nombre(_ t: String) -> Double? {
        Double(t.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
    }

    private var impression: some View {
        let cm = etat.prefs.uniteMesure == "cm"
        return VStack(alignment: .leading, spacing: 12) {
            Groupe(titre: "Calibrage : l'impression à la bonne taille") {
                HStack {
                    Text("1. Papier :")
                    Picker("", selection: $papierCalibrage) { Text("A4").tag("A4"); Text("US Letter").tag("Letter") }
                        .labelsHidden().frame(width: 110)
                    Button("Imprimer la page de calibrage…") { etat.imprimerCalibrage(papierCalibrage == "A4" ? .a4 : .letter) }
                        .buttonStyle(.w98Gras)
                }
                Text("La page sort avec une règle en cm et une en pouces. Imprime à 100 %.").foregroundStyle(W98.ombre)
                HStack {
                    Text("2. Je mesure en :")
                    Picker("", selection: $etat.prefs.uniteMesure) { Text("centimètres").tag("cm"); Text("pouces").tag("in") }
                        .pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
                }
                HStack {
                    Text("Règle horizontale (\(cm ? "15 cm" : "6 in")) mesurée :")
                    Champ(invite: cm ? "15" : "6", texte: $regleH).frame(width: 70); Text(cm ? "cm" : "in")
                }
                HStack {
                    Text("Règle verticale (\(cm ? "20 cm" : "8 in")) mesurée :")
                    Champ(invite: cm ? "20" : "8", texte: $regleV).frame(width: 70); Text(cm ? "cm" : "in")
                }
                HStack {
                    Text("Bord gauche → trait rouge A :"); Champ(invite: "15", texte: $bordGauche).frame(width: 70); Text("mm")
                }
                HStack {
                    Text("Bord haut → trait rouge A :"); Champ(invite: "15", texte: $bordHaut).frame(width: 70); Text("mm")
                }
                Button("3. Enregistrer le calibrage") {
                    let attenduH = cm ? 15.0 : 6.0, attenduV = cm ? 20.0 : 8.0
                    if let h = nombre(regleH), h > 0 { etat.prefs.echelleX = attenduH / h }
                    if let v = nombre(regleV), v > 0 { etat.prefs.echelleY = attenduV / v }
                    if let g = nombre(bordGauche) { etat.prefs.decalageX = 15 - g }
                    if let b = nombre(bordHaut) { etat.prefs.decalageY = 15 - b }
                    etat.prefs.calibrationFaite = true
                    regleH = ""; regleV = ""; bordGauche = ""; bordHaut = ""
                }
                .buttonStyle(.w98Gras).disabled([regleH, regleV, bordGauche, bordHaut].allSatisfy { $0.isEmpty })
                Text(etat.prefs.calibrationFaite
                     ? "Réglage enregistré : échelle \(String(format: "%.2f", etat.prefs.echelleX * 100)) % × \(String(format: "%.2f", etat.prefs.echelleY * 100)) %, décalage \(String(format: "%+.1f", etat.prefs.decalageX)) mm / \(String(format: "%+.1f", etat.prefs.decalageY)) mm. Il s'applique à toutes tes impressions."
                     : "Pas encore calibré : les impressions partent sans correction.")
                    .foregroundStyle(etat.prefs.calibrationFaite ? W98.vert : W98.ombre).fixedSize(horizontal: false, vertical: true)
                Button("Remettre à zéro") {
                    etat.prefs.echelleX = 1; etat.prefs.echelleY = 1; etat.prefs.decalageX = 0; etat.prefs.decalageY = 0
                    etat.prefs.calibrationFaite = false
                }
                .buttonStyle(.w98)
            }
            Groupe(titre: "Papier conseillé") {
                Text("J-card, O-card, obi : papier mat ou satiné de 170 à 250 g/m², A4.")
                Text("Étiquettes de K7 : papier autocollant A4 pleine page, mat. L'app imprime les traits de coupe.")
                Text("Le PDF exporté garde le fond perdu (3 mm) pour une impression en boutique ; le calibrage ne s'applique qu'à ton imprimante.")
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var sources: some View {
        VStack(alignment: .leading, spacing: 12) {
            Groupe(titre: "MusicBrainz et Cover Art Archive") {
                Text("Gratuit, sans compte : albums, tracklists, maisons de disque, scans des vraies éditions cassette.")
                    .fixedSize(horizontal: false, vertical: true)
            }
            Groupe(titre: "Discogs (jeton personnel gratuit)") {
                Champ(invite: "Jeton Discogs", texte: $etat.jetonDiscogs, secret: true)
                Text("1. Connecte-toi sur discogs.com (compte gratuit).")
                Text("2. Settings → Developers → « Generate new token ».")
                Link("   Ouvrir la page Developers de Discogs", destination: URL(string: "https://www.discogs.com/settings/developers")!).foregroundStyle(W98.bleu)
                Text("3. Copie le jeton ici. Il est rangé dans le trousseau du Mac.")
                Text("Discogs ajoute les photos de milliers d'éditions K7 : Claude s'en sert pour sa première proposition.")
                    .foregroundStyle(W98.ombre).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var claude: some View {
        VStack(alignment: .leading, spacing: 12) {
            Groupe(titre: "Clé API") {
                Champ(invite: "sk-ant-…", texte: $etat.cleClaude, secret: true)
                Text("Rangée dans le trousseau du Mac.").foregroundStyle(W98.ombre)
            }
            GuideCleClaude()
            Groupe(titre: "Recherche web") {
                Toggle("Claude peut chercher sur des sites choisis (sources citées)", isOn: $etat.prefs.rechercheWebClaude).toggleStyle(.checkbox)
                Text("Sites : " + sitesMusique.joined(separator: ", ") + ". Claude cite ses sources ; ce qu'il trouve est à valider avant l'impression.")
                    .foregroundStyle(W98.ombre).fixedSize(horizontal: false, vertical: true)
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
