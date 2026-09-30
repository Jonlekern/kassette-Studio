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

## Réponse de la session cloud (corrections)

1. **Compiler sans Xcode** : pas un bug, SwiftUI et XCTest demandent Xcode. `app/LISEZMOI.md` (option B)
   dit maintenant d'installer Xcode, et `construire-app.sh` s'arrête avec un message clair s'il manque.
2. **« Tester » sans clé** : l'API n'est plus appelée, l'app affiche « Colle d'abord ta clé ». Le message
   a une largeur fixe, le bouton ne bouge plus.
3. **Bande teal plus claire en haut** : c'est l'effet de bord flou que macOS 26+ ajoute aux zones
   défilantes. Il est désactivé dans toute l'app (`sansEffetDeBord()`), et la zone défilante du premier
   démarrage prend toute la largeur. À vérifier sur la prochaine version.

Suite du test : clé Claude, Spotify, dossier, sortie, puis Mixtape et Enregistrer (voir « Pas encore testé »).

---

# Test 2

30 septembre 2026, même Mac (macOS 27.0, sans Xcode). App compilée par GitHub Actions :
run 36752993090, commit `03a0d4c` (« Icône : retour au fond bleu-vert, nette à chaque taille »),
installée dans `/Applications` et lancée depuis le Terminal. **Aucun plantage, aucun message** dans la
sortie standard ou les erreurs, sur trois lancements.

Sortie audio réelle vers la platine : carte son USB **« FOX »**. Johnny a écouté et donné ses retours
sur le son.

## Résumé du test 2

| Point | Résultat |
|---|---|
| Icône dans le Finder | ✅ Cassette rose sur fond bleu-vert → `captures/04-icone-finder.png` |
| Icône dans le Dock | ✅ Vérifiée par Johnny |
| « Tester » avec clé vide | ✅ « Colle d'abord ta clé », le bouton ne bouge plus → `06` |
| Bande claire en haut de la fenêtre | ✅ Disparue → `05` |
| Textes d'exemple des champs clé / Client ID | ⚠️ Parfois absents (voir T2-7) |
| Clé API Claude + « Tester » | ✅ « OK » → `07` |
| Spotify : création de l'appli, Client ID | ✅ Mais **Web API bloquée sans Premium** (voir T2-1) → `08` |
| Spotify « Se connecter… » | ⏳ Page d'autorisation ouverte, pas validée (inutile sans Premium) |
| Dossier audio, conditions, « Commencer » | ✅ → `09` |
| **« Tonalité 1 kHz » sur la sortie choisie** | ❌ **Sort toujours sur les haut-parleurs du Mac mini** (voir T2-2) |
| Mixtape : « Cassette depuis le dossier (sans Spotify) » | ✅ 12 titres, faces A 25:11 / B 25:40, 12 fichiers associés → `11` |
| Mixtape : ⇄ changer de face | ✅ Marche, avec deux remarques (T2-4) → `12` |
| Mixtape : × retirer | ✅ Marche, totaux mis à jour |
| Mixtape : glisser pour réordonner | ❓ Pas concluant (T2-5) |
| Enregistrer : compte à rebours, 5 s de blanc, lecture | ✅ → `13`, `14` |
| Enregistrer : son sur la bonne sortie | ✅ Sort bien sur FOX (confirmé à l'oreille par Johnny) |
| Enregistrer : blanc de 2 s entre morceaux 1 et 2 | ✅ Minutage cohérent → `16` |
| Enregistrer : compteur, barre « Bande utilisée », statuts « Fait / En cours » | ✅ |
| Enregistrer : Pause / Reprendre / Stop | ✅ |
| **Enregistrer : VU-mètres** | ❌ **Aiguilles collées à +3, même à l'arrêt** (T2-3) → `15`, `17` |
| Enregistrer : bobines qui tournent | ✅ Vérifiées à l'œil par Johnny |
| Enregistrer : arrêt net en fin de face | ⏳ Pas testé (face de 25 min) |
| Réglages (⌘,) : les 6 rubriques s'ouvrent | ✅ Audio, Platine, Claude, Spotify, Langue, Conditions → `19` |
| Réglages gardés après relance | ✅ (égalisation, blanc 3 s, sortie FOX, dernière cassette rouverte) |
| Collection : cassette présente, Ouvrir, Dupliquer | ✅ Mais numérotée **LFS-002** au lieu de LFS-001 (T2-6) → `18` |
| Onglet Jaquette | ⏭️ Pas testé (étape 2) |

## T2-1. Spotify : l'API est réservée aux comptes Premium (bloquant pour la recherche d'album)

Après la création de l'appli sur developer.spotify.com (nom LaFleurStudio, Redirect URI
`http://127.0.0.1:8898/callback`), le tableau de bord de Spotify affiche en haut :

```
Your application is blocked from accessing the Web API since you do not have a Spotify Premium subscription. Upgrade to Spotify Premium to access the Web API and unlock additional features for your app.
```

Johnny **n'a pas Premium**. La recherche d'album, les liens Spotify et « Mes playlists » ne peuvent donc
pas marcher pour lui. Heureusement, **« Cassette depuis le dossier (sans Spotify) » marche très bien**
(voir T2-4). → `captures/08-spotify-premium-requis.jpg`

**À faire** :
- Dire clairement, dans l'app (premier démarrage, rubrique Spotify, aide) et dans le LISEZMOI, que
  **Spotify Premium est obligatoire** pour la partie Spotify, et que l'app marche aussi sans.
- Quand Spotify répond « Premium requis » (sans doute une erreur 403), afficher un message clair au
  lieu d'un échec muet. Pas testé ici, puisque la connexion n'a pas été validée.
- Envisager une autre source d'infos d'album sans compte payant (MusicBrainz, Discogs, déjà prévus).

### Demande de Johnny : un guide complet de connexion

Johnny demande un **guide pas à pas complet**, dans l'app (bouton « i ») et dans le LISEZMOI, pour :
1. **La clé API Claude** : l'abonnement Claude (Pro/Max) **ne donne pas** de clé API, c'est un compte à
   part sur platform.claude.com avec du crédit. Dire où cliquer (Settings → API keys → Create key),
   quoi choisir (**Scope : Default workspace**, expiration), que la clé ne s'affiche qu'une fois, et
   qu'elle ne doit **jamais être collée ailleurs que dans l'app** (Johnny ne trouvait pas la clé
   « déjà payée » et l'a d'abord collée dans une conversation).
2. **L'appli Spotify** : créer le compte développeur, accepter les conditions, Create app, Redirect
   URI exacte, cocher Web API, où trouver le Client ID (pas le secret), et **Premium obligatoire**.
3. **Se connecter à Spotify** : ce qui s'ouvre dans le navigateur, bouton « Agree », ce que l'app
   affiche ensuite.

## T2-2. « Tonalité 1 kHz » ignore la sortie choisie (bug)

**Pour reproduire** : au premier démarrage (section 4) ou dans Réglages → Audio, choisir une sortie
autre que celle par défaut du Mac (ici « FOX », carte son USB), puis cliquer sur « Tonalité 1 kHz ».
**Attendu** : le bip sort sur FOX. **Obtenu** : il sort **toujours sur les haut-parleurs du Mac mini**
(sortie par défaut du système), quelle que soit la sortie choisie (Johnny a essayé plusieurs sorties).

L'**enregistrement**, lui, sort bien sur FOX.

**Cause probable** (lecture du code, rien n'a été modifié) : dans `app/Sources/LaFleurStudio/Audio/MoteurEnregistrement.swift`,
`choisirSortie(_:)` n'est appelée que dans `charger(...)` (ligne 57), au chargement d'une face.
`basculerTonalite()` (ligne 254) attache la source et démarre `moteur` **sans appeler
`choisirSortie`**, donc l'`AVAudioEngine` utilise la sortie par défaut. Changer la sortie dans le menu
ne redirige pas non plus un moteur déjà démarré.

**Correction proposée** : dans `basculerTonalite()`, appliquer la sortie des préférences avant
`moteur.start()` (moteur arrêté). Et quand la sortie change dans le menu : arrêter le moteur,
`choisirSortie(nouvelleUID)`, puis redémarrer si une tonalité ou une face était en cours.

## T2-3. VU-mètres collés à +3 (bug)

Pendant la lecture, les deux aiguilles (GAUCHE et DROITE) sont **tout à droite, sur +3, sans
bouger** entre deux captures prises à une seconde d'écart. Après **Stop**, alors que rien ne joue,
elles **restent collées à +3**. Pendant la pause, elles étaient retombées. → `captures/15-vu-metres-colles-lecture.jpg`,
`captures/17-stop-vu-colles-a-l-arret.jpg`

Pistes : l'échelle est peut-être trop sensible pour une musique masterisée (un mastering actuel tourne
autour de −9 dBFS RMS, ce qui dépasse +3 VU si 0 VU = −18 dBFS). Et la valeur n'est pas remise à zéro au
Stop.

## T2-4. Mixtape sans Spotify

Dossier `/Users/jkern/musique/` contenant `an afternoon at the lake/` (12 MP3). Au début, il était vide
(Johnny venait de le créer) : la barre d'état a affiché « Aucun fichier audio dans le dossier »,
ce qui est correct. → `10`

« Relire » puis « Cassette depuis le dossier (sans Spotify) » :
- ✅ Titre et artiste remplis tout seuls (« An Afternoon at the Lake », « Jeremy Sadik »)
- ✅ 12 titres, **face A 25:11** (Sun Cream At The Lake → Glass), **face B 25:40** (Mushroom Forest →
  Unknown Number). Attendu 25:10 pour la face A : **1 s d'écart**, sans doute un arrondi (durées des
  fichiers ou des métadonnées).
- ✅ Les 12 fichiers sont associés, aucun « pas de fichier » en rouge
- ✅ Message de Claude : « Ordre gardé. Face A 25:11, face B 25:40 : 0:29 d'écart. »

**⇄ (changer de face)** marche, avec deux remarques :
- Le morceau arrive **en 1ʳᵉ position** de l'autre face, pas à la fin. Est-ce voulu ?
- Le **message de Claude n'est pas mis à jour** : il affiche toujours « Face A 25:11, face B 25:40 »
  alors que les faces font 22:33 et 28:18.

**× (retirer)** marche, et les totaux se mettent à jour (11 titres). Il n'y a ni confirmation ni annulation.

## T2-5. Glisser pour réordonner : pas concluant

Un glisser par la poignée ⋮⋮ (fait par l'outil d'automatisation, en moins d'une seconde) affiche bien
l'aperçu du morceau qui suit la souris, mais **l'ordre ne change pas**. Ensuite, l'arbre
d'accessibilité de la fenêtre est resté vide jusqu'à ce que Johnny clique dans l'app. C'est peut-être
dû à l'outil plutôt qu'à l'app : **à revérifier à la main**.

## T2-6. Collection

- ⚠️ La première cassette est numérotée **LFS-002**, pas LFS-001, alors que la collection était vide
  (la première version installée, `b0a3828`, avait été lancée sans jamais dépasser l'écran de bienvenue).
- ✅ Dupliquer crée LFS-003, et « prochain numéro » passe à LFS-004.
- ✅ Ouvrir charge la cassette dans Mixtape.
- Petite faute : « **1 cassettes** » · prochain numéro…
- Au passage, les durées de LFS-003 ont suivi le changement de blanc (3 s) : A 25:16, B 25:45. ✅

## T2-7. Textes d'exemple des champs

Juste après le lancement, les champs « Clé API Claude » et « Client ID » n'affichaient **aucun texte
d'exemple** (`sk-ant-…`, « Client ID de ton appli Spotify ») → `05`. Un peu plus tard, avec la fenêtre
en arrière-plan, le texte d'exemple du Client ID était visible. Ils semblent donc disparaître quand la
fenêtre est active : à vérifier.

## Autres remarques

- Réglages → Claude : la case « Claude peut chercher sur des sites choisis (sources citées) » est
  cochée par défaut, alors que le LISEZMOI dit que la recherche web n'est pas encore faite.
- L'**arrêt net en fin de face** n'a pas été testé (il faut laisser tourner 25 min).

## Captures du test 2

| Fichier | Contenu |
|---|---|
| `captures/04-icone-finder.png` | Icône telle que le Finder l'affiche |
| `captures/05-premier-demarrage-v2.jpg` | Écran de bienvenue v2 : bande disparue, textes d'exemple absents |
| `captures/06-tester-cle-vide-v2.jpg` | « Colle d'abord ta clé » |
| `captures/07-cle-claude-ok.jpg` | Clé Claude « OK » (clé masquée) |
| `captures/08-spotify-premium-requis.jpg` | Tableau de bord Spotify : Web API bloquée sans Premium |
| `captures/09-premier-demarrage-rempli.jpg` | Écran de bienvenue rempli (dossier, sortie FOX) |
| `captures/10-mixtape-dossier-vide.jpg` | « Aucun fichier audio dans le dossier » (dossier encore vide) |
| `captures/11-mixtape-album-charge.jpg` | Album chargé sans Spotify : A 25:11, B 25:40 |
| `captures/12-mixtape-changer-face.jpg` | Après ⇄ : morceau en tête de face B, message Claude pas à jour |
| `captures/13-enregistrer-compte-a-rebours.jpg` | Compte à rebours « Relâche la pause… 5 » |
| `captures/14-enregistrer-morceau-1.jpg` | Lecture du morceau 1 |
| `captures/15-vu-metres-colles-lecture.jpg` | VU-mètres collés à +3 pendant la lecture |
| `captures/16-passage-morceau-2.jpg` | Passage au morceau 2 (« Fait » / « En cours ») |
| `captures/17-stop-vu-colles-a-l-arret.jpg` | Après Stop : remis à zéro, mais VU toujours à +3 |
| `captures/18-collection-dupliquer.jpg` | Collection : LFS-002 et sa copie LFS-003 |
| `captures/19-reglages-platine.jpg` | Réglages → Platine |

## Réponse de la session cloud au test 2

- **T2-1 Spotify Premium** : dit clairement au premier démarrage, dans Réglages → Spotify et dans le
  LISEZMOI ; une réponse 403 de Spotify affiche « son API demande un compte Premium… utilise « Cassette
  depuis le dossier » ». **Guides pas à pas** ajoutés dans l'app : clé Claude (Pro/Max ≠ API, Billing,
  API keys → Create key, workspace Default, affichée une fois, ne jamais la coller ailleurs) et Spotify
  (création de l'appli, Redirect URI, Web API, Client ID, « Agree »). MusicBrainz/Discogs restent prévus
  comme source sans compte payant.
- **T2-2 Tonalité sur la mauvaise sortie** : corrigé. La tonalité démarre sur la sortie choisie, et changer
  de sortie dans le menu redirige le moteur tout de suite (sauf pendant un enregistrement).
- **T2-3 VU-mètres collés** : corrigé. Mesure en RMS (plus en crête), 0 VU = −12 dBFS RMS = niveau de la
  tonalité (la tonalité est passée à −12 dBFS RMS), balistique d'un vrai VU (~300 ms), et aiguilles au
  repos dès que rien ne joue (pause, stop, fin de face).
- **T2-4** : ⇄ est voulu ainsi : la fin de la face A continue au début de la face B (et la face B revient
  à la fin de la face A), l'info-bulle le dit. Le message de Claude s'efface dès qu'on modifie les faces
  à la main. × : bouton « Remettre « titre » » pour annuler le dernier retrait. Les 25:11 au lieu de 25:10
  viennent des durées réelles des fichiers (elles font foi pour l'enregistrement).
- **T2-5 Glisser** : à revérifier à la main. En plus : clic droit sur un morceau → Monter / Descendre.
- **T2-6** : une cassette neuve est enregistrée tout de suite, son numéro n'est plus perdu (les suivantes
  repartent de la bonne valeur ; tes LFS-002/003 existantes ne sont pas renumérotées). « 1 cassette » au
  singulier.
- **T2-7 Textes d'exemple invisibles** : l'app était affichée en mode sombre par macOS (texte d'exemple
  clair sur fond blanc). Elle est maintenant toujours en mode clair.
- **Recherche web de Claude** : la case est grisée avec « Arrive dans une prochaine étape ».

---

# Demande de Johnny : calibrer l'échelle d'impression

**Problème** : l'utilisateur n'a aucun moyen de savoir si son imprimante sort les jaquettes à la bonne
taille. Une J-card imprimée à 98 % ne rentre pas dans le boîtier.

**Ce que Johnny veut, en simple** :

1. Réglages → Impression : on choisit le **format du papier** (A4, Letter…).
2. « Imprimer la règle » : l'app imprime une page avec **une règle de 10 cm et une de 4 pouces**, pour
   que chacun mesure avec la règle qu'il a.
3. On **mesure** la règle imprimée avec une vraie règle.
4. On **tape la valeur mesurée** dans l'app (« la règle de 10 cm mesure : 9,8 cm »).
5. **C'est tout** : l'app calcule la correction (10 / 9,8 = 102 %), la garde dans les Réglages et
   l'applique à toutes les impressions et exports.

**Détails utiles** (à garder discrets, sans compliquer le flux ci-dessus) :

- Écrire sur la page imprimée : « Imprime à 100 %, pas “Ajuster à la page” ».
- Garder le réglage **par imprimante**, avec un bouton « Réinitialiser (100 %) ».
- À la première impression d'une jaquette, si rien n'est calibré, proposer d'imprimer la règle d'abord.
- En option : une règle verticale aussi, si certaines imprimantes n'ont pas la même erreur dans les
  deux sens.

C'est lié à la « page de calibrage » déjà prévue dans `docs/brainstorm.md` (section Impression), qui ne
parle que du décalage, pas de l'échelle.

## Réponse (session cloud) : calibrage fait

- Réglages → **Impression** : choix de l'imprimante et du papier (A4 ou Letter) ; bouton **Imprimer la
  règle** (une règle de 10 cm et une de 4 pouces, « Imprime à 100 %, pas “Ajuster à la page” » écrit en
  rouge sur la page).
- On choisit l'unité (cm ou pouces), on tape la longueur mesurée → **OK**. L'app calcule la correction
  (10 / 9,8 = 102 %) et la garde **par imprimante**, avec « Réinitialiser (100 %) ». Une mesure absurde
  (4 au lieu de 10 : sûrement des pouces) est refusée avec un message.
- Options discrètes (repliées) : règle verticale si l'erreur n'est pas la même dans les deux sens, et
  décalage des marges (traits rouges à 15 mm des bords).
- À la première impression d'une jaquette sur une imprimante pas calibrée, l'app propose
  « Imprimer la règle d'abord ».
- Choix assumé : la correction s'applique à **toutes les impressions**, mais **pas au PDF exporté**. Le PDF
  est à la taille exacte pour qu'une boutique (ou une autre imprimante) l'imprime juste ; corriger le PDF
  avec l'erreur de ton imprimante le fausserait partout ailleurs.
