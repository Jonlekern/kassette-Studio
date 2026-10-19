import AVFoundation
import LaFleurCore
import SwiftUI

struct EcranMixtape: View {
    @EnvironmentObject var etat: EtatApp

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Toute la colonne défile : la boîte IA du mode expert ne pousse plus « Dossier audio » hors de l'écran.
            ScrollView {
                VStack(spacing: 14) {
                    Sources()
                    // Mode expert : la boîte IA marche aussi ici (« mets Glass en face B »).
                    if etat.modeExpert {
                        BoiteModifierIA(exemple: "Ex. « mets Glass en face B », « passe en C90 », « bande Type I sans Dolby »")
                    }
                }
                .padding(.top, 4).padding(.trailing, 15)
            }
            .scrollIndicators(.visible)
            .frame(width: 305)
            VStack(alignment: .leading, spacing: 10) {
                // Hauteur naturelle : sinon l'encadré se partage la hauteur avec les listes et s'étire en blancs.
                ReglagesCassette().fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .top, spacing: 10) {
                    ListeFace(face: .a)
                    ListeFace(face: .b)
                }
                if !etat.commentaireClaude.isEmpty { BulleClaude(texte: etat.commentaireClaude) }
            }
            Actions().frame(width: 200)
        }
    }
}

// MARK: - Sources (Spotify, Claude, dossier)

private struct Sources: View {
    @EnvironmentObject var etat: EtatApp
    @State private var recherche = ""
    @State private var ambiance = ""
    @State private var rechercheMB = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
                Groupe(titre: "Spotify") {
                    Text("Album, playlist ou lien").bold()
                    Champ(invite: "Chercher un album ou coller un lien…", texte: $recherche).onSubmit { etat.chercherAlbums(recherche) }
                    if !etat.albumsTrouves.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(etat.albumsTrouves) { a in
                                Button { etat.importerAlbum(a) } label: {
                                    HStack(spacing: 8) {
                                        AsyncImage(url: a.pochetteURL) { $0.resizable() } placeholder: { W98.grisFonce }.frame(width: 32, height: 32)
                                        VStack(alignment: .leading) {
                                            Text(a.titre).bold().lineLimit(1)
                                            Text("\([a.artiste, a.annee].compactMap { $0 }.joined(separator: " · ")) · \(a.nombreTitres) titres").lineLimit(1)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .padding(5).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain).disabled(etat.occupe)
                            }
                        }
                        .creux()
                    }
                    HStack {
                        Button("Mes playlists…") { etat.chargerPlaylists() }.buttonStyle(.w98).disabled(!etat.spotifyConnecte)
                    }
                    ForEach(etat.playlists) { p in
                        Button(p.name) { etat.importerPlaylist(p) }.buttonStyle(.plain).foregroundStyle(W98.bleu)
                    }
                }
                Groupe(titre: "MusicBrainz (gratuit, sans compte)") {
                    Champ(invite: "Album, ou « Artiste - Album »…", texte: $rechercheMB).onSubmit { etat.chercherMusicBrainz(rechercheMB) }
                    if !etat.albumsMusicBrainz.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(etat.albumsMusicBrainz) { a in
                                Button { etat.importerMusicBrainz(a) } label: {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(a.titre).bold().lineLimit(1)
                                        Text([a.artiste, a.annee, a.formats.joined(separator: "+"), a.maisonDeDisque, a.catalogue]
                                                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")).lineLimit(1)
                                    }
                                    .padding(5).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain).disabled(etat.occupe)
                            }
                        }
                        .creux()
                    }
                    Text("Titres, durées, maison de disque et pochette, sans Spotify.").foregroundStyle(W98.ombre)
                }
                Groupe(titre: "Composer avec l'IA (mixtape)") {
                    Text("Avec la musique de ton dossier audio d'abord, puis quelques idées à trouver ailleurs.").foregroundStyle(W98.ombre)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Ambiance").bold()
                    TextEditor(text: $ambiance).font(W98.police).frame(height: 54).scrollContentBackground(.hidden).creux()
                    Button("Composer la sélection") { etat.composer(ambiance: ambiance) }.buttonStyle(.w98)
                        .disabled(ambiance.isEmpty || etat.occupe)
                    if !etat.propositions.isEmpty {
                        Text("Coche ce que tu gardes. Rien n'est ajouté sans toi.").foregroundStyle(W98.ombre)
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach($etat.propositions) { $p in
                                Toggle(isOn: $p.gardee) {
                                    HStack {
                                        Text("\(p.idee.artiste) – \(p.idee.titre)").lineLimit(1)
                                        Spacer()
                                        if p.fichier != nil {
                                            Text(p.morceau.map { formaterDuree($0.duree) } ?? "").monospacedDigit()
                                        } else {
                                            Text(p.morceau.map { "à trouver · " + formaterDuree($0.duree) } ?? "à trouver").foregroundStyle(W98.orange)
                                        }
                                    }
                                }
                                .toggleStyle(.checkbox).disabled(p.morceau == nil)
                                .help(p.fichier != nil ? "Dans ton dossier audio" : "Pas dans ton dossier audio : à te procurer avant l'enregistrement")
                            }
                        }
                        .padding(6).creux()
                        HStack {
                            Button("Ajouter la sélection") { etat.ajouterPropositions() }.buttonStyle(.w98Gras)
                            Button("Autres idées") { etat.composer(ambiance: ambiance) }.buttonStyle(.w98)
                        }
                    }
                }
                Groupe(titre: "Dossier audio") {
                    Text(etat.prefs.dossierAudio?.path(percentEncoded: false) ?? String(localized: "Aucun dossier")).lineLimit(1).truncationMode(.middle)
                        .padding(4).frame(maxWidth: .infinity, alignment: .leading).creux()
                    HStack {
                        Button("Choisir…") { etat.choisirDossier() }.buttonStyle(.w98)
                        Button("Relire") { Task { await etat.associerFichiers() } }.buttonStyle(.w98)
                    }
                    Button("Cassette depuis le dossier (sans Spotify)") { etat.importerDossierSeul() }.buttonStyle(.w98)
                }
        }
    }
}

// MARK: - Réglages de la cassette

private struct ReglagesCassette: View {
    @EnvironmentObject var etat: EtatApp

    private var minutesCustom: Binding<Int> {
        Binding(get: { etat.projet.cassette.longueur.minutesParFace },
                set: { etat.projet.cassette.longueur = .custom(minutesParFace: max(5, min(90, $0))) })
    }
    private var choixLongueur: Binding<Int> {
        Binding(get: {
            switch etat.projet.cassette.longueur { case .c60: 0; case .c90: 1; case .custom: 2 }
        }, set: {
            etat.projet.cassette.longueur = [.c60, .c90, .custom(minutesParFace: etat.projet.cassette.longueur.minutesParFace)][$0]
        })
    }

    var body: some View {
        Groupe(titre: "Cassette") {
            HStack(spacing: 14) {
                Picker("", selection: $etat.projet.mode) {
                    Text("Album").tag(ModeCassette.album)
                    Text("Mixtape").tag(ModeCassette.mixtape)
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 150)
                Picker("", selection: choixLongueur) {
                    Text("C60 · 30 min/face").tag(0)
                    Text("C90 · 45 min/face").tag(1)
                    Text("Custom").tag(2)
                }
                .pickerStyle(.radioGroup).horizontalRadioGroupLayout().labelsHidden()
                if case .custom = etat.projet.cassette.longueur {
                    Stepper(value: minutesCustom, in: 5...90) { Text("\(etat.projet.cassette.longueur.minutesParFace) min/face") }
                }
                Spacer()
            }
            HStack(spacing: 14) {
                Picker("Bande", selection: $etat.projet.cassette.bande) {
                    ForEach(TypeBande.allCases, id: \.self) { Text(tr($0.nom)).tag($0) }
                }
                .fixedSize()
                Picker("Réducteur de bruit", selection: $etat.projet.cassette.reducteur) {
                    ForEach(ReducteurBruit.allCases, id: \.self) { Text(tr($0.nom)).tag($0) }
                }
                .fixedSize()
                Spacer(minLength: 0)
            }
            HStack(spacing: 14) {
                Picker("Coque", selection: $etat.projet.cassette.coque) {
                    ForEach(CouleurCoque.allCases, id: \.self) { Text(tr($0.nom)).tag($0) }
                }
                .fixedSize()
                Text("Marque / modèle").fixedSize()
                Champ(invite: "TDK SA60", texte: $etat.projet.cassette.marque).frame(maxWidth: 160)
                Spacer(minLength: 0)
            }
            HStack {
                Text("Titre")
                Champ(invite: "Titre de la cassette", texte: $etat.projet.titre)
                Text("Artiste")
                Champ(invite: "Artiste", texte: $etat.projet.artiste)
            }
        }
    }
}

// MARK: - Faces

private struct ListeFace: View {
    @EnvironmentObject var etat: EtatApp
    let face: Face
    /// Morceau au-dessus duquel on s'apprête à lâcher (trait bleu).
    @State private var survol: UUID?
    @State private var finCiblee = false

    var pistes: [Piste] { etat.projet.pistes(face) }

    var body: some View {
        let duree = Faces.duree(pistes, etat.prefs.platine)
        let capacite = Double(etat.projet.cassette.longueur.minutesParFace * 60)
        let deborde = duree > Faces.capacite(etat.projet.cassette, etat.prefs.platine)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Face \(face.rawValue)").bold()
                Spacer()
                Text("\(formaterDuree(duree)) / \(formaterDuree(capacite))").foregroundStyle(deborde ? W98.rouge : .black)
            }
            Blocs(valeur: duree, total: capacite, couleur: deborde ? W98.rouge : W98.bleu)
            if deborde { Text("Dépasse la bande : retire ou déplace un morceau.").foregroundStyle(W98.rouge) }
            // Liste maison : la List de macOS gardait le glisser pour elle, et réordonner ne marchait pas.
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(pistes.enumerated()), id: \.element.id) { i, p in
                        LignePiste(numero: i + 1, piste: p, face: face, survol: survol == p.id)
                            .padding(.horizontal, 4).padding(.vertical, 3)
                            .draggable(p.id.uuidString)
                            .dropDestination(for: String.self) { ids, _ in
                                guard let id = ids.first.flatMap(UUID.init(uuidString:)) else { return false }
                                etat.deplacer(id, avant: p.id, face: face)
                                return true
                            } isTargeted: { if $0 { survol = p.id } else if survol == p.id { survol = nil } }
                        Divider()
                    }
                    // Lâché sous le dernier morceau : à la fin de la face.
                    Color.clear.frame(height: 40).contentShape(Rectangle())
                        .dropDestination(for: String.self) { ids, _ in
                            guard let id = ids.first.flatMap(UUID.init(uuidString:)) else { return false }
                            etat.deplacer(id, avant: nil, face: face)
                            return true
                        } isTargeted: { finCiblee = $0 }
                        .overlay(alignment: .top) { if finCiblee { Rectangle().fill(W98.bleu).frame(height: 2) } }
                }
            }
            .scrollIndicators(.visible)
            .frame(maxHeight: .infinity)
            .background(Color.white).creux()
            Text("Glisse (même vers l'autre face) ou clic droit pour réordonner · ⇄ change de face · × retire").foregroundStyle(W98.ombre).font(W98.police)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct LignePiste: View {
    @EnvironmentObject var etat: EtatApp
    let numero: Int
    let piste: Piste
    let face: Face
    var survol = false

    var body: some View {
        HStack(spacing: 6) {
            Text("⋮⋮").foregroundStyle(W98.grisFonce).fixedSize()
            Text("\(numero)").foregroundStyle(W98.grisFonce).frame(width: 18, alignment: .trailing)
            // Le titre prend toute la place libre avant la durée (avant, il se coupait trop tôt).
            VStack(alignment: .leading, spacing: 1) {
                Text(piste.morceau.titre).bold().lineLimit(1).truncationMode(.tail).help(piste.morceau.titre)
                Text(piste.morceau.artiste).foregroundStyle(W98.ombre).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if piste.fichier == nil {
                Text("⚠︎ fichier").foregroundStyle(W98.rouge).fixedSize()
                    .help("Aucun fichier audio associé : ce morceau ne peut pas être enregistré. Choisis ton dossier audio à gauche.")
            }
            // Durée et boutons toujours entiers : c'est le titre qui se coupe s'il manque de la place.
            Text(formaterDuree(piste.duree)).monospacedDigit().fixedSize()
            Button("⇄") { etat.changerDeFace(piste.id) }.buttonStyle(.plain).fixedSize()
                .help(face == .a ? "Passer au début de la face B" : "Passer à la fin de la face A")
            Button { etat.retirer(piste.id) } label: { Text("×").bold().foregroundStyle(W98.rouge) }
                .buttonStyle(.plain).fixedSize().help("Retirer de la cassette (ne sera pas enregistré)").accessibilityLabel("Retirer ce morceau")
        }
        .font(W98.police)
        .contentShape(Rectangle())
        // Trait bleu au-dessus : le morceau glissé viendra ici.
        .overlay(alignment: .top) { if survol { Rectangle().fill(W98.bleu).frame(height: 2).offset(y: -3) } }
        .contextMenu {
            Button("Monter") { etat.monter(piste.id, de: -1) }
            Button("Descendre") { etat.monter(piste.id, de: 1) }
            Button(face == .a ? "Passer au début de la face B" : "Passer à la fin de la face A") { etat.changerDeFace(piste.id) }
            Divider()
            Button("Retirer de la cassette") { etat.retirer(piste.id) }
        }
    }
}

// MARK: - Actions et total

private struct Actions: View {
    @EnvironmentObject var etat: EtatApp
    @State private var confirmerVidage = false
    var body: some View {
        let r = etat.prefs.platine
        let musique = etat.projet.toutes.reduce(0) { $0 + $1.duree }
        let bande = Double(etat.projet.cassette.longueur.minutesParFace * 60 * 2)
        let libre = bande - Faces.duree(etat.projet.faceA, r) - Faces.duree(etat.projet.faceB, r)
        VStack(alignment: .leading, spacing: 14) {
            Groupe(titre: "Actions") {
                Button("Équilibrer avec Claude") { etat.equilibrerAvecClaude() }.buttonStyle(.w98Gras)
                    .disabled(etat.occupe || etat.projet.toutes.isEmpty)
                Button("Garder l'ordre (auto)") { etat.repartirDansLOrdre() }.buttonStyle(.w98).disabled(etat.projet.toutes.isEmpty)
                Button("Vider les faces") { confirmerVidage = true }.buttonStyle(.w98).disabled(etat.projet.toutes.isEmpty)
                if let v = etat.avantVidage {
                    Button("Remettre les morceaux (\(v.a.count + v.b.count))") { etat.annulerVidage() }.buttonStyle(.w98)
                }
                if let r = etat.dernierRetire {
                    Button("Remettre « \(r.piste.morceau.titre) »") { etat.annulerRetrait() }.buttonStyle(.w98).lineLimit(1)
                        .help(etat.retires.count > 1 ? "\(etat.retires.count) morceaux retirés : clique plusieurs fois pour les remettre un par un" : "")
                }
                Button("Nouvelle cassette") { etat.nouvelleCassette() }.buttonStyle(.w98)
            }
            .alert("Vider les deux faces ?", isPresented: $confirmerVidage) {
                Button("Vider", role: .destructive) { etat.viderFaces() }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Les \(etat.projet.toutes.count) morceaux sont retirés de la cassette. Tes fichiers audio ne sont pas touchés, et « Remettre les morceaux » les rend.")
            }
            Groupe(titre: "Total") {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(etat.projet.toutes.count) TITRES")
                    Text("\(formaterDuree(musique)) DE MUSIQUE")
                    Text("\(formaterDuree(max(0, libre))) LIBRES")
                }
                .font(.system(size: 16, design: .monospaced))
            }
        }
    }
}

// MARK: - Association des fichiers

struct QuestionAssociation: View {
    @EnvironmentObject var etat: EtatApp
    let question: QuestionFichier
    @State private var choix: URL?
    @State private var ecoute: AVAudioPlayer?

    var body: some View {
        Fenetre(titre: "Associer les fichiers audio") {
            VStack(alignment: .leading, spacing: 12) {
                if question.candidats.isEmpty {
                    Text("« \(question.titre) » (\(formaterDuree(question.duree))) : aucun fichier trouvé").font(.custom("Arial", size: 14).bold())
                    Text("Le morceau n'est pas dans ton dossier audio. Sans fichier, il ne peut pas être enregistré.")
                } else {
                    Text("Ce fichier est-il bien « \(question.titre) » de \(question.artiste) (\(formaterDuree(question.duree))) ?")
                        .font(.custom("Arial", size: 14).bold())
                    Text("Plusieurs fichiers ressemblent à ce titre. Choisis le bon :")
                    VStack(spacing: 0) {
                        ForEach(question.candidats, id: \.url) { f in
                            HStack {
                                Image(systemName: choix == f.url ? "largecircle.fill.circle" : "circle")
                                VStack(alignment: .leading) {
                                    Text(f.url.lastPathComponent).bold()
                                    Text(f.url.deletingLastPathComponent().path(percentEncoded: false)).foregroundStyle(W98.ombre).lineLimit(1)
                                }
                                Spacer()
                                Text(formaterDuree(f.duree)).foregroundStyle(abs(f.duree - question.duree) <= 2 ? W98.vert : .black)
                                Button("Écouter") { ecouter(f.url) }.buttonStyle(.w98)
                            }
                            .padding(6).contentShape(Rectangle()).onTapGesture { choix = f.url }
                            .background(choix == f.url ? Color(red: 0.91, green: 0.94, blue: 0.91) : .clear)
                        }
                    }
                    .creux()
                }
                if question.candidats.isEmpty {
                    Text("Tu peux le garder sans fichier (pour faire la jaquette avant d'avoir la musique) : il sera associé quand tu ajouteras le fichier au dossier, avec « Relire ».")
                        .foregroundStyle(W98.ombre).fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    Button("Retirer de la cassette") { ecoute?.stop(); etat.repondre(question, fichier: nil, duree: nil) }.buttonStyle(.w98)
                    // Échap = garder sans fichier : la fenêtre ne bloque plus rien.
                    Button("Garder sans fichier") { ecoute?.stop(); etat.garderSansFichier(question) }.buttonStyle(.w98)
                        .keyboardShortcut(.cancelAction)
                    let autres = etat.questions.filter { $0.candidats.isEmpty }.count
                    if question.candidats.isEmpty && autres > 1 {
                        Button("Garder les \(autres) sans fichier") { ecoute?.stop(); etat.garderTousSansFichier() }.buttonStyle(.w98Gras)
                    }
                    Spacer()
                    Button("Choisir un fichier…") { ecoute?.stop(); etat.choisirFichierAMain(question) }.buttonStyle(.w98)
                    if !question.candidats.isEmpty {
                        Button("C'est celui-là") {
                            ecoute?.stop()
                            let f = question.candidats.first { $0.url == choix }
                            etat.repondre(question, fichier: f?.url, duree: f?.duree)
                        }
                        .buttonStyle(.w98Gras).disabled(choix == nil)
                    }
                }
            }
            .padding(14)
        }
        .frame(width: 640).w98()
        .onAppear { choix = question.candidats.first?.url }
    }

    private func ecouter(_ url: URL) {
        ecoute?.stop()
        ecoute = try? AVAudioPlayer(contentsOf: url)
        ecoute?.play()
    }
}
