# Retours de test — étape 1

Test sur un vrai Mac, le 30 septembre 2026. **Rapport partiel** : l'installation et le premier
lancement sont testés. Les étapes qui demandent la clé API Claude, le compte Spotify et le dossier
audio attendent que Johnny les remplisse. Ce fichier sera complété ensuite.

## Machine

- Mac mini Apple Silicon (arm64), **macOS 27.0** (build 26A428)
- **Outils en ligne de commande seulement** (`xcode-select -p` → `/Library/Developer/CommandLineTools`),
  **pas d'Xcode**
- Swift 6.4 (`swiftlang-6.4.0.34.1`), cible `arm64-apple-macosx27.0.0`
- Commit testé : `b0a3828` (branche `etape-1`)

## Résumé

| Étape | Résultat |
|---|---|
| `swift build` | ❌ Échoue : il manque Xcode sur la machine, pas un bug de code (voir 1) |
| `swift test` | ❌ Échoue : même cause, `XCTest` absent (voir 1) |
| `./construire-app.sh --installer` | ⏭️ Pas lancé, puisque `swift build` échoue |
| App compilée par GitHub Actions (run 36750162886, commit `b0a3828`) | ✅ Installée dans `/Applications`, se lance |
| Premier démarrage : affichage | ✅ OK |
| Premier démarrage : « Tester » sans clé | ⚠️ Marche, message peu clair (voir 2) |
| Premier démarrage : bouton « i » | ✅ Ouvre l'aide |
| Clé Claude, Spotify, dossier, sortie, conditions | ⏳ À faire avec Johnny |
| Onglets Mixtape, Enregistrer, Réglages, Collection | ⏳ À faire |

## 1. `swift build` et `swift test` échouent sans Xcode (bloquant pour compiler sur le Mac)

**Pour reproduire** : sur un Mac sous macOS 27 avec seulement les outils en ligne de commande
installés (`xcode-select --install`), sans Xcode :

```bash
cd app
swift build
swift test
```

**`swift build`** : 60 erreurs, soit 30 erreurs différentes affichées deux fois, toutes identiques
à celle-ci, une par `@State` :

```
app/Sources/LaFleurStudio/Interface/EcranCollection.swift:8:24: error: external macro implementation type 'SwiftUIMacros.StateMacro' could not be found for macro 'State()'; plugin for module 'SwiftUIMacros' not found
```

Fichiers touchés (nombre d'erreurs) : `EcranMixtape.swift` (8), `PremierDemarrage.swift` (8),
`EcranCollection.swift` (4), `EcranEnregistrer.swift` (4), `Reglages.swift` (4), `Racine.swift` (2).
Aucune autre erreur : le module `LaFleurCore` compile.

**`swift test`** :

```
error: /Users/jkern/Developer/kassette-Studio/app/Tests/LaFleurCoreTests/LaFleurCoreTests.swift:1:8 unable to resolve module dependency: 'XCTest'
error: Build failed
```

**Cause** : dans le SDK macOS 27, `@State` de SwiftUI est une macro dont le plugin
(`SwiftUIMacros`) n'est livré qu'avec **Xcode**, pas avec les outils en ligne de commande. `XCTest`
non plus (`find /Library/Developer/CommandLineTools -iname "*SwiftUIMacros*"` ne trouve rien). Sur
GitHub Actions, `macos-latest` a Xcode, donc ça compile et les 11 tests passent.

**Proposition** :
- Dans `app/LISEZMOI.md`, option B : remplacer « Il faut les outils de développement
  (`xcode-select --install`) » par « Il faut **Xcode** (App Store), puis
  `sudo xcode-select -s /Applications/Xcode.app` ».
- En option, `construire-app.sh` peut vérifier au début que `xcode-select -p` pointe vers Xcode et
  afficher un message clair sinon.

**Contournement utilisé pour le test** : l'app compilée par GitHub Actions (option A du LISEZMOI),
téléchargée avec `gh run download 36750162886`. Le binaire est arm64, signé localement (ad hoc),
sans attribut de quarantaine, donc aucun blocage de Gatekeeper au lancement.

## 2. Premier démarrage

Lancement depuis le Terminal (`/Applications/LaFleurStudio.app/Contents/MacOS/LaFleurStudio`) : **aucun
plantage, aucun message** dans la sortie standard ni dans les erreurs.

- ✅ L'écran « Bienvenue dans LaFleurStudio » s'affiche correctement : logo, les 5 sections, bouton
  « Commencer » grisé tant que rien n'est rempli. → `captures/01-premier-demarrage.jpg`
- ⚠️ **« Tester » avec le champ de clé vide** répond « Clé refusée » (en rouge). Ce n'est pas faux,
  mais c'est trompeur : aucune clé n'a été saisie.
  **Suggestion** : ne pas appeler l'API si le champ est vide, et afficher « Colle d'abord ta clé ».
  Autre détail : quand le message apparaît, le bouton « Tester » se décale vers la gauche.
  → `captures/02-tester-cle-vide.jpg`
- ✅ **Bouton « i »** : ouvre la fenêtre « Aide — Claude dans LaFleurStudio » à côté (rôle,
  obtention de la clé avec lien vers platform.claude.com, coût). Elle se ferme avec son bouton.
  → `captures/03-aide-cle-api.jpg`
- Détail visuel, à confirmer : en haut de la fenêtre principale, une bande de teal un peu plus
  claire, sur environ 630 × 32 px, est visible au centre de la barre de titre (voir capture 01).

## Pas encore testé (en attente)

- Clé API Claude valide + « Tester »
- Client ID Spotify + « Se connecter… »
- Dossier audio, choix de la sortie audio, « Tonalité 1 kHz », conditions, « Commencer »
- Mixtape : « An Afternoon at the Lake » (Jeremy Sadik). Attendu : face A 25:10, face B 25:40
- Enregistrer : ● sans cassette (sortie, VU-mètres, bobines, blancs, arrêt en fin de face)
- Réglages (⌘,) et Collection

## Captures

| Fichier | Contenu |
|---|---|
| `captures/01-premier-demarrage.jpg` | Écran de bienvenue au premier lancement |
| `captures/02-tester-cle-vide.jpg` | « Clé refusée » après « Tester » sans clé |
| `captures/03-aide-cle-api.jpg` | Fenêtre d'aide du bouton « i » |
