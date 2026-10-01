import AppKit
import LaFleurCore
import SwiftUI

/// Réglages (⌘,) : audio, platine, impression, Claude, Spotify, sources, langue, conditions.
struct Reglages: View {
    @EnvironmentObject var etat: EtatApp
    @State private var rubrique = "Audio"
    private let rubriques = ["Audio", "Platine", "Impression", "IA", "Spotify", "Sources", "Langue", "Conditions"]

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(rubriques, id: \.self) { r in
                    Button { rubrique = r } label: {
                        Text(tr(r)).padding(.horizontal, 8).padding(.vertical, 5).frame(maxWidth: .infinity, alignment: .leading)
                            .background(rubrique == r ? W98.bleu : .clear).foregroundStyle(rubrique == r ? .white : .black)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(2).frame(width: 150).creux()
            VStack(alignment: .leading, spacing: 12) {
                Text(tr(rubrique)).font(.custom("Arial", size: 15).bold())
                switch rubrique {
                case "Audio": audio
                case "Platine": platine
                case "Impression": ScrollView { impression }
                case "Sources": sources
                case "IA": ScrollView { claude }
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

    @State private var regleH = ""
    @State private var regleV = ""
    @State private var bordGauche = ""
    @State private var bordHaut = ""
    @State private var erreurMesure = ""

    private func nombre(_ t: String) -> Double? {
        Double(t.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
    }

    private var impression: some View {
        let cm = etat.prefs.uniteMesure == "cm"
        let attendu = cm ? 10.0 : 4.0
        let unite = cm ? "cm" : "in"
        let imprimantes = NSPrinter.printerNames
        let c = etat.calibration
        return VStack(alignment: .leading, spacing: 12) {
            Groupe(titre: "Imprimante et papier") {
                Picker("Imprimante", selection: Binding(get: { etat.imprimanteCourante },
                                                         set: { etat.prefs.imprimante = $0 })) {
                    ForEach(Array(Set(imprimantes + [etat.imprimanteCourante])).sorted(), id: \.self) { Text($0).tag($0) }
                }
                Picker("Papier", selection: $etat.prefs.papierCalibrage) { Text("A4").tag("A4"); Text("US Letter").tag("Letter") }
                    .pickerStyle(.radioGroup).horizontalRadioGroupLayout()
            }
            Groupe(titre: "Imprimer à la bonne taille") {
                HStack {
                    Text("1.")
                    Button("Imprimer la règle") { etat.imprimerCalibrage() }.buttonStyle(.w98Gras)
                    Text("(une règle de 10 cm et une de 4 pouces)").foregroundStyle(W98.ombre)
                }
                HStack {
                    Text("2. Je mesure en")
                    Picker("", selection: $etat.prefs.uniteMesure) { Text("centimètres").tag("cm"); Text("pouces").tag("in") }
                        .pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
                }
                HStack {
                    Text("3. La règle de \(cm ? "10 cm" : "4 pouces") mesure :")
                    Champ(invite: cm ? "10" : "4", texte: $regleH).frame(width: 70); Text(unite)
                    Button("OK") { enregistrer(attendu: attendu) }.buttonStyle(.w98Gras).disabled(regleH.isEmpty && regleV.isEmpty && bordGauche.isEmpty && bordHaut.isEmpty)
                }
                if !erreurMesure.isEmpty { Text(erreurMesure).foregroundStyle(W98.rouge) }
                DisclosureGroup("Options : règle verticale, décalage") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Règle verticale de \(cm ? "10 cm" : "4 pouces") :"); Champ(invite: cm ? "10" : "4", texte: $regleV).frame(width: 70); Text(unite)
                        }
                        Text("À remplir seulement si ton imprimante n'a pas la même erreur dans les deux sens.").foregroundStyle(W98.ombre)
                        HStack { Text("Bord gauche → trait rouge :"); Champ(invite: "15", texte: $bordGauche).frame(width: 70); Text("mm") }
                        HStack { Text("Bord haut → trait rouge :"); Champ(invite: "15", texte: $bordHaut).frame(width: 70); Text("mm") }
                    }
                    .padding(.top, 4)
                }
                if let c {
                    let echelle = c.echelleY != c.echelleX
                        ? String(format: "%.1f × %.1f", c.echelleX * 100, c.echelleY * 100) : String(format: "%.1f", c.echelleX * 100)
                    Text("✓ \(etat.imprimanteCourante) : échelle \(echelle) %. Appliquée à toutes les impressions sur cette imprimante.")
                        .foregroundStyle(W98.vert).fixedSize(horizontal: false, vertical: true)
                    if c.decalageX != 0 || c.decalageY != 0 {
                        Text("Décalage : \(String(format: "%+.1f", c.decalageX)) mm horizontal, \(String(format: "%+.1f", c.decalageY)) mm vertical.")
                    }
                    Button("Réinitialiser (100 %)") { etat.prefs.calibrations[etat.imprimanteCourante] = nil }.buttonStyle(.w98)
                } else {
                    Text("Cette imprimante n'est pas encore calibrée : elle imprime sans correction.").foregroundStyle(W98.ombre)
                }
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

    private func enregistrer(attendu: Double) {
        var c = etat.calibration ?? CalibrationImprimante()
        erreurMesure = ""
        if !regleH.isEmpty {
            guard let m = nombre(regleH), let e = CalibrationImprimante.echelle(attendu: attendu, mesure: m) else {
                erreurMesure = "Mesure « \(regleH) » improbable : vérifie l'unité (cm ou pouces)."; return
            }
            c.echelleX = e; c.echelleY = e
        }
        if !regleV.isEmpty {
            guard let m = nombre(regleV), let e = CalibrationImprimante.echelle(attendu: attendu, mesure: m) else {
                erreurMesure = "Mesure verticale « \(regleV) » improbable."; return
            }
            c.echelleY = e
        }
        if let g = nombre(bordGauche) { c.decalageX = 15 - g }
        if let b = nombre(bordHaut) { c.decalageY = 15 - b }
        etat.prefs.calibrations[etat.imprimanteCourante] = c
        regleH = ""; regleV = ""; bordGauche = ""; bordHaut = ""
    }

    @State private var testIA = ""

    private var claude: some View {
        let f = etat.prefs.fournisseurIA
        return VStack(alignment: .leading, spacing: 12) {
            Groupe(titre: "Moteur d'IA") {
                Picker("Moteur", selection: $etat.prefs.fournisseurIA) {
                    ForEach(FournisseurIA.allCases, id: \.self) { Text(verbatim: "\($0.nom) (\($0.societe))").tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden()
                .onChange(of: etat.prefs.fournisseurIA) { _, _ in testIA = "" }
                if f != .claude {
                    Text("Claude est recommandé : l'app a été réglée et testée avec lui. GPT et Gemini font le même travail, mais leurs designs peuvent être moins soignés.")
                        .foregroundStyle(W98.ombre).fixedSize(horizontal: false, vertical: true)
                }
            }
            Groupe(titre: "Clé API \(f.nom)") {
                HStack {
                    Champ(invite: f.inviteCle, texte: etat.lienCle(f), secret: true)
                    Button("Tester") { testerIA() }.buttonStyle(.w98)
                    Text(testIA).foregroundStyle(testIA == "OK" ? W98.vert : W98.rouge).bold().lineLimit(1)
                }
                Text("Rangée dans le trousseau du Mac.").foregroundStyle(W98.ombre)
                Link("Créer une clé \(f.nom)…", destination: f.pageCles).foregroundStyle(W98.bleu)
                HStack {
                    Text("Modèle")
                    Champ(invite: f.modeleParDefaut, texte: Binding(
                        get: { etat.prefs.modelesIA[f.rawValue] ?? "" },
                        set: { etat.prefs.modelesIA[f.rawValue] = $0.trimmingCharacters(in: .whitespaces) }))
                }
                Text("Vide = modèle conseillé (\(f.modeleParDefaut)).").foregroundStyle(W98.ombre)
            }
            if f == .claude { GuideCleClaude() }
            Groupe(titre: "Recherche web") {
                Toggle("L'IA peut chercher sur des sites choisis (sources citées)", isOn: $etat.prefs.rechercheWebClaude).toggleStyle(.checkbox)
                Text("Sites : " + sitesMusique.joined(separator: ", ") + ". L'IA cite ses sources ; ce qu'elle trouve est à valider avant l'impression.")
                    .foregroundStyle(W98.ombre).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func testerIA() {
        let f = etat.prefs.fournisseurIA
        let c = etat.cle(f).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !c.isEmpty else { testIA = tr("Colle d'abord ta clé"); return }
        testIA = "…"
        Task {
            do { try await ClientClaude(cleAPI: c, fournisseur: f).testerCle(); testIA = "OK" }
            catch { testIA = tr("Clé refusée") }
        }
    }

    private var langue: some View {
        Groupe(titre: "Langue de l'app et de Claude") {
            Picker("", selection: $etat.prefs.langue) {
                Text("Français").tag("fr"); Text("English").tag("en"); Text("Русский").tag("ru"); Text("Deutsch").tag("de")
            }
            .pickerStyle(.radioGroup).labelsHidden()
            Text("Claude répond dans cette langue. L'interface change au prochain lancement de l'app.")
                .foregroundStyle(W98.ombre)
            Button("Relancer l'app maintenant") {
                let url = Bundle.main.bundleURL
                let config = NSWorkspace.OpenConfiguration()
                config.createsNewApplicationInstance = true
                NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
                    DispatchQueue.main.async { NSApp.terminate(nil) }
                }
            }
            .buttonStyle(.w98)
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
