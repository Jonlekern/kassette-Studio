import LaFleurCore
import SwiftUI

enum Ecran: Hashable { case mixtape, jaquette, enregistrer, collection }

struct Racine: View {
    @EnvironmentObject var etat: EtatApp
    @State private var avisTrousseau = false
    var body: some View {
        ZStack {
            W98.bureau.ignoresSafeArea()
            if etat.prefs.premierDemarrageFini {
                FenetrePrincipale().padding(16)
            } else {
                ScrollView { PremierDemarrage().padding(24).frame(maxWidth: .infinity) }
            }
            if avisTrousseau {
                Color.black.opacity(0.25).ignoresSafeArea()
                AvisTrousseau { avisTrousseau = false; Task { await etat.chargerCles() } }.frame(width: 460)
            }
        }
        // Les clés sont lues après l'affichage de la fenêtre. Après une mise à jour, macOS va demander
        // l'accès au trousseau : on prévient d'abord, pour que l'app ne semble pas bloquée.
        .onAppear {
            if etat.trousseauVaDemander { avisTrousseau = true } else { Task { await etat.chargerCles() } }
        }
        .w98()
        .sansEffetDeBord()
        // Look Windows 98 : toujours en clair, même si le Mac est en mode sombre (textes d'exemple lisibles).
        .preferredColorScheme(.light)
    }
}

struct FenetrePrincipale: View {
    @EnvironmentObject var etat: EtatApp
    @EnvironmentObject var moteur: MoteurEnregistrement
    @State private var ecran: Ecran

    init(ecranInitial: Ecran = .mixtape) { _ecran = State(initialValue: ecranInitial) }

    var titre: String {
        let t = etat.projet.titre.isEmpty ? "Nouvelle cassette" : etat.projet.titre
        return "LaFleurStudio — « \(t) » · \(etat.projet.numeroCatalogue) · \(etat.projet.cassette.longueur.nom)"
    }

    var body: some View {
        Fenetre(titre: titre) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    Onglets(onglets: [(Ecran.mixtape, "1. Mixtape"), (.jaquette, "2. Jaquette"), (.enregistrer, "3. Enregistrer"),
                                      (.collection, "4. Collection")], selection: $ecran)
                    Spacer()
                    // Les réglages étaient seulement dans le menu LaFleurStudio (⌘,) : introuvables pour beaucoup.
                    SettingsLink { Text("Réglages…") }.buttonStyle(.w98).help("Réglages (⌘,)")
                }
                .padding(.horizontal, 8).padding(.top, 8).zIndex(1)
                Group {
                    switch ecran {
                    case .mixtape: EcranMixtape()
                    case .jaquette: EcranJaquette()
                    case .enregistrer: EcranEnregistrer()
                    case .collection: EcranCollection(ouvrir: { etat.ouvrir($0); ecran = .mixtape }, reimprimer: { ecran = .jaquette })
                    }
                }
                .padding(12).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .relief().padding(.horizontal, 8)
                HStack(spacing: 2) {
                    if etat.occupe { ProgressView().controlSize(.small).padding(.leading, 4) }
                    Text(etat.statut).lineLimit(1).padding(.horizontal, 6).frame(maxWidth: .infinity, alignment: .leading).frame(height: 20).creux(W98.gris)
                    Text(etat.spotifyConnecte ? "Spotify : connecté" : "Spotify : non connecté").padding(.horizontal, 6).frame(height: 20).creux(W98.gris)
                    Text(etat.cle(etat.fournisseurIA).isEmpty ? "\(etat.fournisseurIA.nom) : pas de clé" : "\(etat.fournisseurIA.nom) : prêt").padding(.horizontal, 6).frame(height: 20).creux(W98.gris)
                }
                .padding(8)
            }
        }
        .sheet(item: Binding(get: { etat.questions.first }, set: { _ in })) { q in
            QuestionAssociation(question: q).environmentObject(etat)
        }
    }
}

struct BientotDisponible: View {
    let texte: String
    var body: some View {
        VStack(spacing: 8) {
            Text("Bientôt").font(W98.lcd)
            Text(texte)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension View {
    /// macOS 26+ ajoute un fondu flou en haut des listes défilantes (bande claire sous la barre de titre) :
    /// on le retire pour garder l'aspect Windows 98.
    @ViewBuilder func sansEffetDeBord() -> some View {
        if #available(macOS 26.0, *) {
            scrollEdgeEffectHidden(true, for: .all)
        } else {
            self
        }
    }
}

/// Prévient avant la question du trousseau de macOS, qui revient après chaque mise à jour.
struct AvisTrousseau: View {
    var continuer: () -> Void
    var body: some View {
        Fenetre(titre: "Nouvelle version installée") {
            VStack(alignment: .leading, spacing: 10) {
                Text("macOS va te demander si LaFleurStudio peut utiliser tes clés (Claude, GPT, Gemini, Spotify, Discogs) rangées dans le trousseau du Mac.")
                    .fixedSize(horizontal: false, vertical: true)
                Text("Tape le mot de passe de ta session Mac, puis clique « Toujours autoriser ».").bold()
                    .fixedSize(horizontal: false, vertical: true)
                Text("C'est normal après chaque mise à jour : l'app n'est pas signée par Apple, alors macOS vérifie que c'est bien elle.")
                    .foregroundStyle(W98.ombre).fixedSize(horizontal: false, vertical: true)
                HStack { Spacer(); Button("Continuer") { continuer() }.buttonStyle(.w98Gras).keyboardShortcut(.defaultAction) }
            }
            .padding(14)
        }
        .w98()
    }
}
