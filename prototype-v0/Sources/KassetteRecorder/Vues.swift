import KassetteCore
import SwiftUI

struct VuePrincipale: View {
    @EnvironmentObject var modele: Modele

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                VueMixtape().tabItem { Label("Mixtape", systemImage: "music.note.list") }
                VueJaquette().tabItem { Label("Jaquette", systemImage: "photo.on.rectangle") }
                VueEnregistrement().tabItem { Label("Enregistrer", systemImage: "record.circle") }
            }
            .padding(8)
            Divider()
            HStack {
                if modele.occupe { ProgressView().controlSize(.small) }
                Text(modele.statut).lineLimit(2).textSelection(.enabled)
                Spacer()
                Text(modele.spotifyConnecte ? "Spotify ✓" : "Spotify ✗").foregroundStyle(modele.spotifyConnecte ? Color.green : Color.secondary)
                Text(modele.cleClaude.isEmpty ? "Claude ✗" : "Claude ✓").foregroundStyle(modele.cleClaude.isEmpty ? Color.secondary : Color.green)
            }
            .font(.callout).padding(.horizontal, 12).padding(.vertical, 6)
        }
    }
}

// MARK: - Mixtape

struct VueMixtape: View {
    @EnvironmentObject var modele: Modele

    var body: some View {
        HSplitView {
            VueSources().frame(minWidth: 280, idealWidth: 320, maxWidth: 420)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Picker("Cassette", selection: $modele.mix.cassette) {
                        ForEach(TypeCassette.allCases) { Text("\($0.rawValue) (\(Int($0.secondesParFace / 60)) min/face)").tag($0) }
                    }.frame(width: 250)
                    Stepper("Blanc entre morceaux : \(Int(modele.mix.reglages.blanc)) s", value: $modele.mix.reglages.blanc, in: 0...10)
                    Stepper("Amorce : \(Int(modele.mix.reglages.amorce)) s", value: $modele.mix.reglages.amorce, in: 0...20)
                    Spacer()
                }
                HStack {
                    Button("✨ Équilibrer les faces avec Claude") { modele.equilibrer() }
                        .disabled(modele.occupe || modele.mix.tous.isEmpty)
                    Button("Remplir dans l'ordre") { modele.repartirSimplement() }.disabled(modele.mix.tous.isEmpty)
                    Spacer()
                    Button("Nouvelle mixtape") { modele.nouvelleMixtape() }
                }
                if !modele.commentaireClaude.isEmpty {
                    Text("Claude : " + modele.commentaireClaude).font(.callout).foregroundStyle(.secondary)
                }
                HStack(alignment: .top, spacing: 10) {
                    ColonneFace(titre: "Réserve", face: nil, morceaux: $modele.mix.reserve)
                    ColonneFace(titre: "Face A", face: .a, morceaux: $modele.mix.faceA)
                    ColonneFace(titre: "Face B", face: .b, morceaux: $modele.mix.faceB)
                }
            }
            .padding(10)
        }
    }
}

struct VueSources: View {
    @EnvironmentObject var modele: Modele
    @State private var ambiance = ""
    @State private var lien = ""
    @State private var recherche = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                GroupBox("✨ Composer avec Claude") {
                    VStack(alignment: .leading) {
                        TextField("Ambiance : « road trip d'été, funk brésilien et soul 70s »", text: $ambiance, axis: .vertical)
                            .lineLimit(2...4)
                        Button("Composer") { modele.composer(ambiance: ambiance) }
                            .disabled(ambiance.isEmpty || modele.occupe || !modele.spotifyConnecte)
                        Text("Claude choisit les morceaux, l'app les retrouve sur Spotify avec leur durée exacte. Ils arrivent dans la réserve.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("Lien Spotify") {
                    HStack {
                        TextField("Playlist, album ou morceau", text: $lien).onSubmit { modele.importer(lien: lien) }
                        Button("Importer") { modele.importer(lien: lien); lien = "" }.disabled(lien.isEmpty || modele.occupe)
                    }
                }
                GroupBox("Chercher un morceau") {
                    VStack(alignment: .leading) {
                        TextField("Artiste, titre…", text: $recherche).onSubmit { modele.chercher(recherche) }
                        ForEach(modele.resultats) { m in
                            HStack {
                                LigneMorceau(m: m)
                                Button { modele.ajouterEnReserve([m]) } label: { Image(systemName: "plus.circle") }.buttonStyle(.borderless)
                            }
                        }
                    }
                }
                GroupBox("Mes playlists") {
                    VStack(alignment: .leading, spacing: 4) {
                        if !modele.spotifyConnecte {
                            Text("Connecte Spotify dans les Réglages (⌘,)").foregroundStyle(.secondary)
                        } else if modele.playlists.isEmpty {
                            Button("Charger mes playlists") { modele.chargerPlaylists() }
                        }
                        ForEach(modele.playlists) { p in
                            Button { modele.importer(playlist: p) } label: {
                                Label(p.name, systemImage: "music.note.list").frame(maxWidth: .infinity, alignment: .leading)
                            }.buttonStyle(.borderless).disabled(modele.occupe)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(10)
        }
    }
}

struct ColonneFace: View {
    @EnvironmentObject var modele: Modele
    let titre: String
    let face: Face?
    @Binding var morceaux: [Morceau]

    var body: some View {
        let r = modele.mix.reglages, capacite = modele.mix.cassette.secondesParFace
        let total = face == nil ? morceaux.reduce(0) { $0 + $1.duree } : dureeFace(morceaux, r)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(titre).font(.headline)
                Spacer()
                if face != nil {
                    Text("\(formaterDuree(total)) / \(formaterDuree(capacite))")
                        .monospacedDigit().foregroundStyle(total > capacite ? Color.red : Color.secondary)
                } else {
                    Text(formaterDuree(total)).monospacedDigit().foregroundStyle(.secondary)
                }
            }
            if face != nil {
                ProgressView(value: min(total, capacite), total: capacite).tint(total > capacite ? Color.red : Color.accentColor)
                if total > capacite { Text("Dépasse de \(formaterDuree(total - capacite))").font(.caption).foregroundStyle(.red) }
                else if !morceaux.isEmpty { Text("Reste \(formaterDuree(capacite - total)) de bande").font(.caption).foregroundStyle(.secondary) }
            }
            List {
                ForEach(Array(morceaux.enumerated()), id: \.element.id) { i, m in
                    HStack(spacing: 6) {
                        Text("\(i + 1)").monospacedDigit().foregroundStyle(.secondary).frame(width: 20, alignment: .trailing)
                        LigneMorceau(m: m)
                    }
                    .contextMenu {
                        if face != .a { Button("Vers la face A") { modele.deplacer(m, vers: .a) } }
                        if face != .b { Button("Vers la face B") { modele.deplacer(m, vers: .b) } }
                        if face != nil { Button("Remettre en réserve") { modele.deplacer(m, vers: nil) } }
                        Divider()
                        Button("Retirer", role: .destructive) { modele.supprimer(m) }
                    }
                }
                .onMove { morceaux.move(fromOffsets: $0, toOffset: $1) }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))
            Text("Glisse pour réordonner · clic droit pour changer de face").font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct LigneMorceau: View {
    let m: Morceau
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(m.titre).lineLimit(1)
                Text(m.artiste).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(formaterDuree(m.duree)).monospacedDigit().foregroundStyle(.secondary)
        }
        .help("\(m.album)\(m.annee.map { " (\($0))" } ?? "")")
    }
}

// MARK: - Jaquette

struct VueJaquette: View {
    @EnvironmentObject var modele: Modele
    @State private var idee = ""

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            Form {
                Section("Textes (zones de Kassette Creator)") {
                    TextField("Titre", text: $modele.mix.jaquette.titre)
                    TextField("Artiste / signature", text: $modele.mix.jaquette.artiste)
                    TextField("Tranche", text: $modele.mix.jaquette.tranche)
                    TextField("Rabat (liner notes)", text: $modele.mix.jaquette.rabat, axis: .vertical).lineLimit(3...6)
                    TextField("Production (crédits)", text: $modele.mix.jaquette.production)
                }
                Section("✨ Claude") {
                    TextField("Une idée, un ton ? (facultatif)", text: $idee)
                    Button("Écrire la jaquette avec Claude") { modele.ecrireJaquette(idee: idee) }
                        .disabled(modele.occupe || modele.mix.faceA.isEmpty && modele.mix.faceB.isEmpty)
                }
                Section("Exporter") {
                    Button("Projet Kassette Creator (.json) avec pochette") { modele.exporterKassetteCreator() }
                        .disabled(modele.occupe)
                    Button("Copier la tracklist (texte)") { modele.copierTracklist() }
                    Button("Playlist .m3u") { modele.exporterM3U() }
                }
            }
            .formStyle(.grouped)
            .frame(maxWidth: 520)

            VStack(alignment: .leading) {
                Text("Pochette du recto").font(.headline)
                let choisie = modele.mix.jaquette.pochetteURL ?? modele.pochettes.first?.url
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 10) {
                        ForEach(modele.pochettes) { p in
                            Button { modele.mix.jaquette.pochetteURL = p.url } label: {
                                VStack {
                                    AsyncImage(url: p.url) { $0.resizable().aspectRatio(1, contentMode: .fit) }
                                        placeholder: { Color.gray.opacity(0.2).aspectRatio(1, contentMode: .fit) }
                                    Text(p.album).font(.caption).lineLimit(1)
                                }
                                .padding(4)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(choisie == p.url ? Color.accentColor : .clear, lineWidth: 3))
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Enregistrement

struct VueEnregistrement: View {
    @EnvironmentObject var modele: Modele
    @EnvironmentObject var enr: Enregistreur
    @StateObject private var tonalite = Tonalite()
    @State private var face: Face = .a

    var morceaux: [Morceau] { modele.mix.morceaux(face) }

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Avant de lancer").font(.headline)
                Group {
                    Text("• Sortie casque/ligne du Mac → entrée LINE IN de la platine.")
                    Text("• Dans Spotify → Réglages : fondu enchaîné désactivé, lecture automatique désactivée, normalisation du volume désactivée, qualité « Très élevée ».")
                    Text("• Volume Spotify à fond, et règle le niveau avec le volume du Mac.")
                    Text("• Active un mode Concentration : pas de son de notification sur la bande.")
                    Text("• Bande rembobinée, amorce passée.")
                }.font(.callout).fixedSize(horizontal: false, vertical: true)
                Button(tonalite.active ? "Couper la tonalité" : "Tonalité 1 kHz (réglage du niveau)") { tonalite.basculer() }
                    .disabled(enr.enCours)
                Text("Règle le niveau d'entrée de la platine pour que la tonalité tape vers 0 VU / −3 dB.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(width: 330)

            VStack(alignment: .leading, spacing: 14) {
                Picker("Face", selection: $face) {
                    ForEach(Face.allCases, id: \.self) { f in
                        Text("Face \(f.rawValue) — \(formaterDuree(dureeFace(modele.mix.morceaux(f), modele.mix.reglages)))").tag(f)
                    }
                }
                .pickerStyle(.segmented).frame(width: 360).disabled(enr.enCours)

                if !tientSurLaFace(morceaux, modele.mix.cassette, modele.mix.reglages) {
                    Text("⚠︎ Cette face dépasse la durée d'une \(modele.mix.cassette.rawValue) : la fin sera coupée.").foregroundStyle(.red)
                }

                Text(texteEtat).font(.system(size: 26, weight: .semibold, design: .rounded)).monospacedDigit()

                HStack {
                    if enr.enCours {
                        Button("■ Arrêter") { enr.arreter() }.keyboardShortcut(.escape, modifiers: [])
                    } else {
                        Button("● Démarrer la face \(face.rawValue)") {
                            if tonalite.active { tonalite.basculer() }
                            enr.demarrer(face, morceaux: morceaux, reglages: modele.mix.reglages)
                        }
                        .keyboardShortcut(.return, modifiers: [.command])
                        .disabled(morceaux.isEmpty)
                    }
                }
                .controlSize(.large)
                Text("Mets la platine en ENREGISTREMENT + PAUSE, clique Démarrer, puis relâche la pause pendant le compte à rebours.")
                    .font(.callout).foregroundStyle(.secondary)

                List {
                    ForEach(Array(morceaux.enumerated()), id: \.element.id) { i, m in
                        HStack {
                            Image(systemName: icone(i)).frame(width: 18)
                            LigneMorceau(m: m)
                        }
                        .fontWeight(enCours(i) ? .bold : .regular)
                    }
                }
                .listStyle(.bordered)
            }
        }
        .padding()
        .onChange(of: face) { enr.reinitialiser() }
    }

    private func enCours(_ i: Int) -> Bool { if case .lecture(let j) = enr.phase { return i == j }; return false }

    private func icone(_ i: Int) -> String {
        switch enr.phase {
        case .lecture(let j): i < j ? "checkmark" : i == j ? "play.fill" : "circle"
        case .fini: "checkmark"
        default: "circle"
        }
    }

    private var texteEtat: String {
        switch enr.phase {
        case .pret: "Prêt — face \(face.rawValue), \(morceaux.count) morceaux"
        case .compteARebours(let s): "Relâche la pause… \(s)"
        case .amorce(let s): "Amorce… \(Int(s.rounded(.up))) s"
        case .lecture(let i):
            i < morceaux.count
                ? "▶︎ \(i + 1)/\(morceaux.count)  \(morceaux[i].titre)  \(formaterDuree(enr.positionMorceau)) / \(formaterDuree(morceaux[i].duree))"
                : "▶︎"
        case .blanc(let s): "Blanc… \(Int(s.rounded(.up))) s"
        case .fini:
            "Face \(enr.face.rawValue) terminée (\(formaterDuree(enr.ecoule))). Arrête la platine" + (enr.face == .a ? ", puis retourne la cassette !" : ". C'est dans la boîte ✿")
        case .erreur(let m): "⚠︎ " + m
        }
    }
}

// MARK: - Réglages

struct VueReglages: View {
    @EnvironmentObject var modele: Modele

    var body: some View {
        Form {
            Section("Claude") {
                SecureField("Clé API (sk-ant-…)", text: $modele.cleClaude)
                Text("À créer sur platform.claude.com → API Keys. Rangée dans le trousseau du Mac.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Spotify") {
                TextField("Client ID de ton appli Spotify", text: $modele.clientIDSpotify)
                Text("Sur developer.spotify.com → Dashboard → Create app. Redirect URI : \(ClientSpotify.redirection) · API : Web API.")
                    .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                HStack {
                    if modele.spotifyConnecte {
                        Label("Connecté", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        Button("Déconnecter") { modele.deconnecterSpotify() }
                    } else if modele.occupe {
                        Button("Annuler la connexion") { modele.annulerConnexion() }
                    } else {
                        Button("Se connecter à Spotify") { modele.connecterSpotify() }.disabled(modele.clientIDSpotify.isEmpty)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
