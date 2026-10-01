import LaFleurCore
import SwiftUI

/// Bienvenue : clé Claude, Spotify, dossier audio, sortie vers la platine, conditions.
struct PremierDemarrage: View {
    @EnvironmentObject var etat: EtatApp
    @State private var aide = false
    @State private var aideSpotify = false
    @State private var testCle = ""
    @State private var accepte = false

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            Fenetre(titre: "Bienvenue dans LaFleurStudio") {
                VStack(alignment: .leading, spacing: 12) {
                    Logo().frame(height: 26).foregroundStyle(.black)
                    Text("Quatre réglages et une validation, et tu peux faire ta première cassette. Tout est modifiable plus tard dans Réglages.")
                        .fixedSize(horizontal: false, vertical: true)
                    Groupe(titre: "1. Clé API Claude") {
                        HStack {
                            Champ(invite: "sk-ant-…", texte: $etat.cleClaude, secret: true)
                            Button("Tester") { tester() }.buttonStyle(.w98)
                            Text(testCle).foregroundStyle(testCle == "OK" ? W98.vert : W98.rouge).bold()
                                .frame(width: 150, alignment: .leading).lineLimit(1)
                            Button("i") { aide.toggle() }.buttonStyle(.w98).accessibilityLabel("Aide sur la clé API Claude")
                        }
                        Text("Tu préfères GPT ou Gemini ? Choisis-le plus tard dans Réglages → IA.").foregroundStyle(W98.ombre)
                    }
                    Groupe(titre: "2. Spotify (facultatif, Premium obligatoire)") {
                        ReglageSpotify()
                        Button("Guide pas à pas…") { aideSpotify.toggle() }.buttonStyle(.w98)
                    }
                    Groupe(titre: "3. Dossier audio") {
                        HStack {
                            Text(etat.prefs.dossierAudio?.path(percentEncoded: false) ?? "Aucun dossier choisi")
                                .lineLimit(1).truncationMode(.middle).padding(.horizontal, 6).frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 22).creux()
                            Button("Choisir…") { etat.choisirDossier() }.buttonStyle(.w98)
                        }
                    }
                    Groupe(titre: "4. Sortie vers la platine") { ChoixSortie() }
                    Groupe(titre: "5. Conditions d'utilisation") {
                        ScrollView { TexteConditions().padding(6) }.frame(height: 110).creux()
                        Toggle("J'ai lu et j'accepte ces conditions", isOn: $accepte).toggleStyle(.checkbox).bold()
                    }
                    HStack {
                        Spacer()
                        Button("Quitter") { NSApplication.shared.terminate(nil) }.buttonStyle(.w98)
                        Button("Commencer") { etat.prefs.conditionsAcceptees = true }.buttonStyle(.w98Gras).disabled(!accepte)
                    }
                }
                .padding(16)
            }
            .frame(width: 580)
            VStack(spacing: 16) {
                if aide { AideClaude(fermer: { aide = false }).frame(width: 540) }
                if aideSpotify {
                    Fenetre(titre: "Guide — connecter Spotify", fermer: { aideSpotify = false }) { GuideSpotify().padding(14) }.frame(width: 540)
                }
            }
        }
    }

    private func tester() {
        guard !etat.cleClaude.trimmingCharacters(in: .whitespaces).isEmpty else { testCle = "Colle d'abord ta clé"; return }
        testCle = "…"
        Task {
            do { try await ClientClaude(cleAPI: etat.cleClaude).testerCle(); testCle = "OK" }
            catch { testCle = "Clé refusée" }
        }
    }
}

/// Le guide « i » : pourquoi Claude, son rôle, où trouver une clé, coût et données.
struct AideClaude: View {
    var fermer: () -> Void
    var body: some View {
        Fenetre(titre: "Aide — Claude dans LaFleurStudio", fermer: fermer) {
            VStack(alignment: .leading, spacing: 12) {
                Groupe(titre: "Pourquoi Claude ?") {
                    Text("Claude est l'assistant intégré à l'app. Il t'aide à préparer la cassette, mais c'est toi qui décides : tu acceptes, modifies ou refuses chacune de ses propositions.")
                }
                Groupe(titre: "Son rôle") {
                    Text("• Mixtape : compose une sélection à partir d'une ambiance et équilibre les faces A/B selon la cassette.")
                    Text("• Design : propose couleurs, polices et variantes à partir de ta pochette.")
                    Text("• Textes : tranche, notes, crédits, numéro de catalogue.")
                    Text("• Vérification : repère ce qui déborde, les codes pas scannables, le contraste trop faible.")
                    Text("• Enregistrement : conseils selon ton type de bande et ta platine.")
                }
                GuideCleClaude()
                Groupe(titre: "Ce que ça coûte, ce qui est envoyé") {
                    Text("Tu paies à l'usage : préparer une cassette coûte en général quelques centimes. La clé reste dans le trousseau de ton Mac. Claude reçoit les titres, les durées et les infos d'album, jamais tes fichiers audio.")
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(14)
        }
    }
}

struct TexteConditions: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("• Usage personnel et non commercial uniquement : les cassettes, jaquettes et étiquettes créées ne sont pas faites pour être vendues, louées ou distribuées.")
            Text("• Tu es seul responsable de ce que tu fais avec l'app et de ce que tu produis, y compris du respect des droits d'auteur et des marques.")
            Text("• Pochettes, logos, textes et infos venant de Spotify, MusicBrainz, Discogs ou d'ailleurs restent la propriété de leurs auteurs.")
            Text("• L'app est fournie telle quelle, sans garantie. L'auteur de LaFleurStudio n'est pas responsable de l'usage fait de l'app ni des objets produits.")
            Text("• Les propositions de Claude peuvent contenir des erreurs : vérifie avant d'imprimer. Claude et Spotify ont leurs propres conditions d'utilisation.")
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct ReglageSpotify: View {
    @EnvironmentObject var etat: EtatApp
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Client ID")
                Champ(invite: "Client ID de ton appli Spotify", texte: $etat.prefs.spotifyClientID)
            }
            Text("Spotify n'ouvre son API qu'aux comptes Premium. Sans Premium, l'app marche quand même avec « Cassette depuis le dossier ».")
                .foregroundStyle(W98.ombre).fixedSize(horizontal: false, vertical: true)
            HStack {
                if etat.spotifyConnecte {
                    Text("Connecté ✓").foregroundStyle(W98.vert).bold()
                    Button("Déconnecter") { etat.deconnecterSpotify() }.buttonStyle(.w98)
                } else if etat.occupe {
                    Button("Annuler") { etat.annulerConnexionSpotify() }.buttonStyle(.w98)
                } else {
                    Button("Se connecter…") { etat.connecterSpotify() }.buttonStyle(.w98).disabled(etat.prefs.spotifyClientID.isEmpty)
                }
            }
        }
    }
}

struct ChoixSortie: View {
    @EnvironmentObject var etat: EtatApp
    @EnvironmentObject var moteur: MoteurEnregistrement
    @State private var sorties: [SortieAudio] = []
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Picker("", selection: $etat.prefs.sortieAudioUID) {
                    Text("Sortie par défaut du Mac").tag(String?.none)
                    ForEach(sorties) { s in
                        Text(s.nom + (s.deconseillee ? " (déconseillé : retard, compression)" : "")).tag(String?.some(s.uid))
                    }
                }
                .labelsHidden()
                Button("Actualiser") { sorties = SortiesAudio.lister() }.buttonStyle(.w98)
                Button(moteur.tonaliteActive ? "Couper la tonalité" : "Tonalité 1 kHz") { moteur.basculerTonalite() }.buttonStyle(.w98)
            }
            Text("L'app joue seulement sur cette sortie ; le reste du Mac ne change pas.").foregroundStyle(W98.ombre)
        }
        .onAppear { sorties = SortiesAudio.lister(); moteur.sortieCourante = etat.prefs.sortieAudioUID }
        .onChange(of: etat.prefs.sortieAudioUID) { moteur.changerSortie(etat.prefs.sortieAudioUID) }
    }
}

/// Logo LAFLEURSTUDIO © : une seule version vectorielle, colorée par `foregroundStyle`.
struct Logo: View {
    var body: some View {
        LogoForme().aspectRatio(LogoForme.largeur / LogoForme.hauteur, contentMode: .fit).accessibilityLabel("LAFLEURSTUDIO")
    }
}

/// Guide pas à pas : obtenir une clé API Claude.
struct GuideCleClaude: View {
    var body: some View {
        Groupe(titre: "Obtenir une clé API Claude, pas à pas") {
            Text("Attention : l'abonnement Claude (Pro ou Max) ne donne pas de clé API. L'API est un compte à part, payé à l'usage.").bold()
            Text("1. Va sur platform.claude.com et connecte-toi (ou crée un compte).")
            Link("   Ouvrir platform.claude.com", destination: URL(string: "https://platform.claude.com")!).foregroundStyle(W98.bleu)
            Text("2. Ajoute un peu de crédit : Settings → Billing (quelques francs suffisent pour beaucoup de cassettes).")
            Text("3. Settings → API keys → Create key. Donne-lui un nom (« LaFleurStudio »), garde le workspace « Default ».")
            Text("4. Copie la clé qui commence par sk-ant-. Elle ne s'affiche qu'une seule fois : si tu la perds, crée-en une autre.")
            Text("5. Colle-la uniquement ici, dans LaFleurStudio, puis clique « Tester » : « OK » s'affiche.")
            Text("Ne colle jamais ta clé ailleurs (conversation, message, site) : n'importe qui pourrait l'utiliser à tes frais. Si ça arrive, supprime-la dans API keys et crée-en une nouvelle.")
                .foregroundStyle(W98.rouge)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Guide pas à pas : créer l'appli Spotify et se connecter.
struct GuideSpotify: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Groupe(titre: "Avant de commencer") {
                Text("Spotify n'ouvre son API qu'aux comptes Premium. Sans Premium, Spotify bloque l'appli : utilise alors « Cassette depuis le dossier » dans l'onglet Mixtape, qui marche sans Spotify.").bold()
            }
            Groupe(titre: "1. Créer l'appli Spotify (une seule fois)") {
                Text("1. Va sur developer.spotify.com et connecte-toi avec ton compte Spotify.")
                Link("   Ouvrir developer.spotify.com/dashboard", destination: URL(string: "https://developer.spotify.com/dashboard")!).foregroundStyle(W98.bleu)
                Text("2. Accepte les conditions des développeurs si Spotify te les montre.")
                Text("3. Clique « Create app ». Nom : LaFleurStudio. Description : ce que tu veux.")
                Text("4. Redirect URI : copie exactement l'adresse ci-dessous, puis clique « Add » :")
                Text(ClientSpotify.redirection).font(.system(size: 12, design: .monospaced)).textSelection(.enabled).padding(4).creux()
                Text("5. Dans « Which API/SDKs are you planning to use? », coche « Web API ». Accepte et clique « Save ».")
                Text("6. Ouvre l'appli → Settings : copie le « Client ID ». Ne prends pas le « Client secret », l'app n'en a pas besoin.")
            }
            Groupe(titre: "2. Se connecter depuis LaFleurStudio") {
                Text("1. Colle le Client ID dans LaFleurStudio, puis clique « Se connecter… ».")
                Text("2. Ton navigateur ouvre une page Spotify qui demande l'accès à tes playlists : clique « Agree » (Accepter).")
                Text("3. La page affiche « C'est bon, Spotify est connecté », et LaFleurStudio « Connecté ✓ ». Tu peux fermer l'onglet.")
                Text("Si Spotify refuse l'accès, c'est en général qu'il faut Premium, ou que la Redirect URI ne correspond pas exactement.")
                    .foregroundStyle(W98.ombre)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
