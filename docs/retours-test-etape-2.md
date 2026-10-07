# Retours de test — étape 2 (jaquette)

## Demandes de Johnny : maîtriser la position et la taille de chaque élément de la J-card

### 1. Déplacer l'image du recto en mode paysage

En orientation **Paysage**, Johnny veut pouvoir **faire glisser l'image de droite à gauche** (cadrage
horizontal) pour choisir quelle partie de la pochette est visible, comme un recadrage.

- À la souris : glisser l'image directement dans l'aperçu.
- En plus, un curseur « Position horizontale » (0 % = calé à gauche, 50 % = centré, 100 % = calé à
  droite) dans la section Recto, sous « Cadrage ».
- Idéalement, la même chose en vertical pour « Pleine hauteur ».
- La position est enregistrée avec la cassette.

### 2. Choisir la taille du code-barres

Aujourd'hui, il n'y a qu'un curseur « Taille » de 60 % à 140 % (`echelleCode`). Johnny veut **décider de la
taille réelle** :

- afficher et saisir la taille en **millimètres** (largeur × hauteur), par exemple 30 × 15 mm ;
- garder la limite de lisibilité déjà prévue (largeur minimale d'un module) et prévenir, en rouge,
  si le code devient trop petit pour être scanné ;
- pareil pour le QR code et le code Spotify.

### 3. Régler la taille de tout

« La taille de tout, en somme » : chaque élément de la J-card doit avoir sa taille réglable.

- **Textes** : titre, artiste, tranche, tracklist, notes, crédits, mentions techniques (type de bande,
  Dolby), numéro de catalogue. Le modèle a déjà `echelles` (une échelle par zone), mais **rien n'est
  visible dans l'interface**. Il faut un curseur par zone, ou un réglage quand on clique sur l'élément
  dans l'aperçu.
- **Logos** : logo LaFleurStudio et logo de la maison de disque.
- **Images posées** et **codes** (voir 2).
- Afficher la taille en **points** pour les textes et en **mm** pour le reste, avec un bouton
  « Taille par défaut » par élément.
- Les alertes existantes (« dépasse », taille minimale de 5 pt) continuent de s'appliquer.

Le plus simple à l'usage serait de **cliquer sur un élément dans l'aperçu** pour le sélectionner, puis
de le **déplacer à la souris** et de régler sa **taille** (poignées ou curseur), comme dans un petit
logiciel de mise en page.

### 4. Étiquettes de K7 : pochette en fond, petite pochette ou sans pochette

Dans **Étiquettes**, Johnny veut pouvoir choisir un **mode où la pochette remplit toute l'étiquette**,
en fond, au lieu du fond uni actuel avec le petit carré d'image à gauche.

- Un choix de style pour les étiquettes, avec **trois modes** :
  - « **Petite pochette** » : le style actuel, fond uni et petit carré d'image à gauche ;
  - « **Pochette en fond** » : la pochette remplit toute l'étiquette (détails ci-dessous) ;
  - « **Sans pochette** » : aucune image sur l'étiquette, seulement le fond uni et les textes.
    Le carré gris disparaît, et les textes peuvent prendre la place libérée.
- En mode « Pochette en fond » : la pochette couvre toute l'étiquette (fond perdu compris), recadrée pour
  remplir sans être déformée. Les textes (titre, face A/B, artiste, C60, type de bande) passent
  par-dessus.
- Pour que les textes restent lisibles, prévoir un voile sombre ou clair réglable, ou un bandeau
  derrière le texte. L'alerte de contraste existante doit s'appliquer.
- La fenêtre de la bande (le rectangle blanc) reste à sa place, par-dessus l'image.
- Idéalement, on peut aussi déplacer l'image pour choisir la partie visible (comme la demande 1).
- Le réglage est commun aux faces A et B, et enregistré avec la cassette.

### 5. ~~Claude ne peut pas retirer la pochette de l'étiquette~~ — **annulée par Johnny** (couverte par la demande 6)

Johnny a demandé au Claude de l'onglet Jaquette d'**enlever la pochette de l'étiquette**. Ça n'a pas
marché.

**Cause** (lecture du code) : Claude ne peut changer que les champs de `ChampsDesign.tous`
(`LaFleurCore/Retouches.swift`). **Aucun champ ne contrôle l'image de l'étiquette** : le petit carré
de pochette est toujours dessiné. Les champs proches ne suffisent pas : `images_retirer` ne retire que
les images posées, `opacite_image` concerne le recto, `taille_etiquette` les textes de l'étiquette.

**À faire** :
- Avec la demande 4, ajouter un champ, par exemple `etiquette_pochette (petite | fond | aucune)`, à
  `ChampsDesign.tous` et à l'aide (`ChampsDesign.aide`), pour que Claude puisse changer le mode.
- Plus généralement : quand une demande ne correspond à **aucun champ modifiable**, Claude doit le
  **dire clairement** (« je ne peux pas encore changer X dans l'app ») au lieu de ne rien faire.
- Garder cette règle pour la suite : chaque nouveau réglage visible dans l'interface doit aussi être
  ajouté aux champs que Claude peut modifier.

### 6. Mode IA expert : l'IA peut tout changer (fusion des anciennes demandes 6 et 7)

Demandes de Johnny : « donne la possibilité de tout changer », puis « fais un mode IA expert où il a
tous les droits ». Les deux sont réunies ici, en **deux niveaux**. Aujourd'hui, l'IA ne touche qu'à une
liste de champs choisis à la main (`ChampsDesign.tous`).

#### Niveau 1 : mode normal, l'IA peut tout changer sur la jaquette

Tout ce que l'utilisateur peut régler sur la jaquette, l'IA peut le régler aussi, et même ce qui n'a
pas encore de bouton :
- **Tous les champs du design** (`DesignJaquette` dans `LaFleurCore/Jaquette.swift`), sans
  exception : formats, volets, dos, orientation, cadrage, styles, couleurs, polices, textes, codes,
  logos, images posées, alertes… Idéalement, la liste des champs est **générée à partir du modèle**,
  pour qu'un nouveau réglage soit automatiquement accessible à l'IA.
- **Chaque élément de chaque format** (J-card recto, verso, tranche, rabat, O-card, étiquettes A/B,
  obi) a une **position, une taille, une rotation, une couleur, une opacité et un état visible/masqué**
  que l'IA peut changer. C'est la même base que la demande 3.
- **Images** : l'IA peut afficher, masquer, déplacer, recadrer et redimensionner la pochette sur chaque
  format (recto, étiquettes, O-card…), y compris les modes d'étiquette de la demande 4 (« retire la
  pochette de l'étiquette » doit marcher).
- **Textes** : contenu, taille, police, alignement, italique/gras, nombre de lignes, pour chaque zone.
- **Formes et décors** : ajouter, modifier ou supprimer des éléments graphiques sur n'importe quel
  format.
- Chaque changement passe par l'**historique** (« Versions ») et s'annule en un clic.
- Si une demande reste vraiment impossible, l'IA le **dit clairement** au lieu de ne rien faire.
- Règle pour la suite : **chaque nouveau réglage de l'interface doit aussi être modifiable par l'IA.**

#### Niveau 2 : mode expert, l'IA a tous les droits dans l'app

**Activation** : Réglages → IA → case « Mode expert : l'IA a tous les droits », **désactivée par
défaut**. Quand il est actif, un badge « IA expert » est visible dans la barre d'état et dans la zone IA
de la Jaquette.

En plus du niveau 1, l'IA peut :
- **Mixtape** : changer l'ordre des morceaux et les faces, retirer ou ajouter des morceaux du dossier
  audio, le type de cassette (C60/C90/custom), la bande, le Dolby, la coque, le titre et l'artiste ;
- **Réglages de la cassette** : blancs, marges, compte à rebours, égalisation ;
- **Collection** : créer, dupliquer, renommer une cassette ;
- **enchaîner plusieurs actions d'un coup** (« fais-moi une C90 ambiance pluie avec une jaquette sombre
  et sans pochette sur l'étiquette »).

**Garde-fous, même en mode expert** :
- Tout passe par l'**historique** et s'annule en un clic, y compris une série d'actions.
- **Supprimer** une cassette de la Collection demande toujours une confirmation.
- L'IA ne touche jamais aux **clés API**, aux comptes (Spotify, Discogs) ni aux fichiers audio sur le
  disque. Elle ne lance pas non plus l'**enregistrement** ni l'**impression** toute seule : elle peut
  tout préparer, l'utilisateur clique.
- Un **résumé clair** de ce qui a été changé après chaque demande.

### 7. Historique des demandes faites à l'IA

Demande de Johnny : voir **un historique de tout ce qu'il a demandé à l'IA**.

- Un panneau « Historique IA » (dans la zone IA de la Jaquette, et accessible depuis la Collection pour
  chaque cassette), qui liste chaque échange :
  - **date et heure** ;
  - **la demande** telle que tapée (ou le bouton utilisé : « Proposer », « Vérifier avec Claude »,
    « Chercher les infos de l'album », « Équilibrer », « Composer la sélection »…) ;
  - **le moteur** utilisé (Claude, GPT, Gemini) ;
  - **la réponse** de l'IA (son message) ;
  - **ce qui a été changé** (liste des réglages modifiés, avant → après), ou « rien n'a été changé » ;
  - si possible, le coût approximatif de la demande.
- Un clic sur une ligne **revient à la version** de la jaquette juste après cette demande (lien avec
  « Versions »).
- Bouton « Refaire cette demande » pour la renvoyer telle quelle.
- L'historique est **enregistré avec chaque cassette**, et garde aussi les demandes du mode expert
  (niveau 2 de la demande 6).
- Un bouton pour effacer l'historique d'une cassette.
- L'historique n'enregistre jamais les clés API.

### 8. Une boîte IA dédiée aux modifications

Demande de Johnny : une **boîte IA réservée aux modifications**, séparée de la direction artistique.

Aujourd'hui, la zone « Direction artistique » mélange tout : le message de Claude, « Proposer » (3
variantes), le petit champ « Demande à Claude… » et « Chercher les infos de l'album ». Le champ de
demande est minuscule, et son texte d'exemple est coupé.

- Une **boîte « Modifier avec l'IA »** bien visible, avec un **grand champ de texte** (plusieurs lignes)
  et un bouton « Appliquer » (ou Entrée).
- On y tape une modification en langage courant : « mets le titre en plus gros », « retire la pochette
  de l'étiquette », « décale l'image vers la gauche », « code-barres de 30 mm », « tranche en rouge »…
- L'IA applique **directement** les changements (dans les limites du niveau 1 ou 2 de la demande 6), puis
  répond dans la boîte avec un **résumé** de ce qui a changé (avant → après) et un bouton « Annuler ».
- La boîte garde le fil de la **conversation** : on peut enchaîner (« encore plus gros », « non, remets
  comme avant »).
- Chaque échange va dans l'**historique IA** (demande 7).
- La zone « Direction artistique » garde « Proposer » (variantes) et « Vérifier » ; les modifications
  ponctuelles passent par la nouvelle boîte.
- Si possible, la boîte est disponible aussi dans Mixtape (par exemple « mets Glass en face B »), en mode
  expert.

---

# Test des demandes 1 à 8 (STUDIOLAFLEUR, release du 6 octobre, commit `db43923`)

7 octobre 2026, Mac mini, macOS 27.0. App `STUDIOLAFLEUR.app` téléchargée depuis Releases et installée
par-dessus l'ancienne `LaFleurStudio.app` (mise à la Corbeille). Données gardées : la cassette LFS-003
et les réglages sont bien repris. Aucun plantage pendant tout le test. Plan suivi :
`docs/test-demandes-1-a-8.md`, dans l'ordre. Rien n'a été corrigé dans le code.

## Résumé

| Point | Résultat |
|---|---|
| 0. Trousseau | ✅ Fenêtre tout de suite, avis « Nouvelle version installée » puis une question macOS, plus rien à la relance → `29` |
| 1. Recadrer l'image du recto | ✅ Curseurs, zoom, glisser, gardé après relance. ⚠️ voir P1, P2 |
| 2. Taille des codes en mm | ✅ Saisie, alerte 6 mm, « Auto ». ❌ **aucune limite haute** (P3). QR et Spotify non concluants |
| 3. Taille et place de chaque élément | ✅ Tailles en pt et ↺, panneau Élément, Masquer, Annuler. ❌ **glisser faux en paysage et sur la tranche** (P4) |
| 4. Étiquettes de K7 | ✅ Les 3 modes, voile, conseil de contraste, même étiquette dans Enregistrer |
| 6. L'IA peut tout changer | ✅ Très bien dans l'ensemble, garde-fous OK. ⚠️ P6, P7 |
| 7. Historique IA | ✅ Liste, coût, détail, boutons, Collection. ❌ **inaccessible quand le fil est long** (P5) |
| 8. Boîte « Modifier avec l'IA » | ✅ Grand champ, ⌘↩, fil, « Effacer le fil », petit champ retiré. ❌ fait déborder les colonnes (P5) |
| Rappels | ✅ VU-mètres au repos, Premium écrit, guides, calibrage à la règle. ⏳ Tonalité : FOX débranchée |

## Problèmes

### P1. Paysage : la « Position horizontale » ne fait rien tant que l'image n'est pas zoomée

**Reproduire** : Jaquette → Recto → Paysage + Pleine hauteur, zoom de l'image au minimum, curseur
« Position horizontale » de 60 % à 0 %. **Obtenu** : l'image ne bouge pas (le curseur, si). **Attendu** :
soit l'image bouge, soit le curseur est grisé avec une explication (« l'image tient déjà en largeur :
zoome pour pouvoir la déplacer »). Après un zoom, le curseur marche. → `captures/30-paysage-position-h-sans-effet.jpg`

Détail : le curseur « Zoom de l'image » n'affiche pas de valeur (les deux autres affichent un %).

### P2. Image du recto sélectionnée : pas de cadre bleu pointillé

Après avoir glissé l'image du recto dans l'aperçu, le panneau Élément indique « Image du recto », mais
**aucun cadre bleu pointillé** n'apparaît autour (il apparaît bien pour le titre). → `captures/31-image-glissee-sans-cadre.jpg`

### P3. Code-barres : aucune limite haute, la vérification dit « rien ne déborde »

**Reproduire** : Codes → Taille, hauteur **412** mm (tapée par erreur). **Obtenu** : accepté, le code-barres
traverse toute la J-card (rabat, tranche, recto). Sous le code : « ✓ EAN-13 valide · scannable », et la
vérification avant impression : « ✓ Textes lisibles, rien ne déborde, codes scannables ». **Attendu** :
une taille maximale (la zone disponible) ou une alerte « déborde ». → `captures/32-code-barres-412mm-sans-alerte.jpg`

L'alerte basse marche : 4 mm → « ⚠ Code-barres trop bas (4 mm) : 6 mm minimum pour être scanné. » → `33`

Autres détails :
- Le bouton **« Auto »** à côté de la taille a son texte coupé sur deux lignes (« Aut / o »).
- Le bouton **« ↶ Annuler »** (en haut de l'aperçu) reste grisé après des changements faits dans la
  colonne de gauche (orientation, taille du code) ; il ne s'active qu'après un glisser dans l'aperçu.
- **QR** : non concluant. La cassette n'a pas de lien Spotify, donc l'alerte « pas de lien Spotify »
  s'affiche ; avec 8 mm, aucune alerte de taille n'apparaît (masquée ?). Le menu « QR code » ne s'ouvre
  pas en arrière-plan, donc « Texte » n'a pas pu être testé.
- **Code Spotify** : non testé (cassette importée du dossier, pas de Spotify).
- **Scan au téléphone** d'un code de 30 mm imprimé : à faire par Johnny.

### P4. Glisser un élément tourné : il part dans la mauvaise direction (et peut disparaître)

**Reproduire** : Jaquette en **Paysage**, cliquer le titre du recto (cadre bleu OK), le glisser **vers le
haut**. **Obtenu** : le titre part **vers la droite** (le sens du texte tourné) ; avec un grand glisser
(y = 16,5 mm), il **sort du recto et disparaît**, sans alerte « déborde ». **Attendu** : l'élément suit
la souris à l'écran, quelle que soit sa rotation, et reste dans sa zone. → `captures/35-titre-disparu-apres-glisser.jpg`

Même problème sur le **texte de tranche** : glissé vers le bas, il part vers la gauche (y = −3 mm), et
aucun cadre pointillé ne s'affiche. Piste : convertir le déplacement de la souris dans le repère tourné
de l'élément (rotation inverse) avant de l'appliquer à x / y.

« ↶ Annuler » remet bien l'élément (« Modification annulée »).

Détail : la **vérification** affiche « Le texte de la zone titre est trop haut : il sort de 0.5 mm » **en
double** quand le titre passe à 20 pt. → `captures/34-titre-20pt-alerte-en-double.jpg`

Détail : deux libellés coupés dans le groupe Tailles : « Numéro de catalogue (tr… », « Mentions
techniques (ba… ».

### P5. Colonnes qui débordent : sections et boutons inaccessibles

Les colonnes de la Jaquette et de Mixtape **ne défilent pas** quand leur contenu grandit :
- **Jaquette, colonne de droite** : quand le panneau **Élément** est ouvert, ou quand le fil de la boîte IA
  est long, « Historique IA », « Vérification avant impression » et **« Exporter »** sont poussés hors de
  l'écran (fenêtre 1180 × 792). Les boutons « Revenir à cette version » / « Refaire cette demande » de
  l'historique sont introuvables tant que le fil n'est pas effacé. → `captures/42-colonne-droite-coupee.jpg`
- **Mixtape en mode expert** : la boîte IA pousse « **Dossier audio** » hors de l'écran (plus de
  Choisir… / Relire / « Cassette depuis le dossier ») et écrase « Composer la sélection » (3 px de
  haut). → `captures/38-mixtape-expert-colonne-debordee.jpg`

**Attendu** : chaque colonne défile, ou la boîte IA a une hauteur maximale avec son propre défilement.

### P6. IA : « remets comme avant » n'annule que la dernière étape

Après « titre plus gros » (1 → 1.3) puis « encore plus gros » (1.3 → 1.6), « remets comme avant » donne
1.6 → 1.3 (« il reste 30 % plus gros »). Défendable, mais ambigu : on attend plutôt la taille d'origine.
Proposition : « comme avant » = avant la série de demandes sur le même sujet, ou demander « juste la
dernière étape, ou la taille d'origine ? ».

Détail : dans le résumé, l'ancienne valeur s'affiche « — » au lieu de « 1 » (`echelles.titre : — → 1.3`).

### P7. IA : message de refus inexact pour « joue la face A »

Le refus est bien là (« Impossible : … »), mais l'explication dit que « l'application ne contient pas
l'audio et ne peut pas lire la face A » : faux, l'onglet Enregistrer joue les faces. Mieux : « Je ne lance
pas la lecture moi-même : va dans Enregistrer et clique ● ».

### P8. Petits défauts

- **Sortie audio absente** : FOX est débranchée ; Réglages → Audio montre un menu **vide** au lieu de
  « FOX (débranchée) » ou d'un retour sur la sortie par défaut.
- **Imprimante** : Réglages → Impression → menu « Imprimante » vide (aucune imprimante installée sur ce
  Mac ?). Un message « Aucune imprimante » serait plus clair. → `40`
- **IA, image introuvable** : pour « ambiance pluie », la recherche d'image n'a rien trouvé ; la jaquette
  garde un carré gris vide (le message le dit bien).
- **Étiquettes, pochette en fond** : à 34 % de voile, les petits textes du bas (« JEREMY SADIK ·
  LAFLEURSTUDIO · LFS-003 ») restent difficiles à lire ; le conseil de contraste n'apparaît que dans la
  Vérification, pas sous le curseur Voile. → `41`
- **Historique IA** : 7 demandes listées pour LFS-003 alors que 8 ont été faites sur cette cassette
  (à vérifier ; les 2 demandes faites sur SLF-004, annulée, ne sont plus visibles, ce qui est normal).

## Ce qui marche très bien

- **Trousseau** : avis clair, une seule question, plus rien à la relance. Bug bloquant réglé.
- **Mode expert** : badge rouge, « passe en C90 et mets Glass en face B » fait les deux avec résumé ;
  « Annuler » remet tout (C60, Glass en face A). Création d'une cassette complète (« Pluie », SLF-004 :
  palette sombre, polices, étiquette sans pochette) en une phrase ; **« Annuler » la supprime bien** et le
  compteur revient à SLF-004. « supprime la cassette SLF-004 » → **confirmation obligatoire** (Annuler /
  Supprimer). Rien lancé tout seul (enregistrement, impression), aucune clé touchée.
- **Mode normal** : « passe la cassette en C90 » → refus clair qui renvoie au mode expert.
- **Boîte IA** : « titre plus gros », « encore plus gros », « remets la pochette en fond sur l'étiquette,
  et mets le titre à sa taille normale » (2 changements en une phrase) : précis, résumé avant → après,
  Annuler par réponse, ⌘↩.
- **Historique IA** : « 7 demandes · environ 0,24 $ », date, moteur, modèle, détail, « Revenir à cette
  version », « Refaire cette demande », « Effacer l'historique », bouton « Historique IA (7) » dans la
  Collection. → `39`
- **Étiquettes** : les 3 modes, la même étiquette sur la K7 d'Enregistrer, coque fumée claire.
- **Collection** : vignette avec le vrai recto, « 1 cassette » au singulier.
- **Réglages** : guides pas à pas Claude et Spotify (« Premium obligatoire »), calibrage à la règle
  (10 cm / 4 pouces, cm ou pouces). → `40`

## Pas testé

- Tonalité 1 kHz sur la bonne sortie (la carte son FOX était débranchée) : à refaire avec Johnny.
- Export PDF (3.6) : la fenêtre d'enregistrement de macOS ne se pilote pas en arrière-plan.
- GPT et Gemini (6.5) : pas de clés.
- « Revenir à cette version » / « Refaire cette demande » : boutons vus mais pas cliqués (cela aurait
  remis la cassette en C90).

## Captures

| Fichier | Contenu |
|---|---|
| `captures/29-avis-nouvelle-version.jpg` | Avis « Nouvelle version installée » |
| `captures/30-paysage-position-h-sans-effet.jpg` | Position horizontale sans effet en paysage |
| `captures/31-image-glissee-sans-cadre.jpg` | Image du recto glissée, pas de cadre pointillé |
| `captures/32-code-barres-412mm-sans-alerte.jpg` | Code-barres de 412 mm accepté, « rien ne déborde » |
| `captures/33-code-barres-4mm-alerte.jpg` | Alerte « 6 mm minimum » |
| `captures/34-titre-20pt-alerte-en-double.jpg` | Alerte de titre affichée deux fois |
| `captures/35-titre-disparu-apres-glisser.jpg` | Titre disparu après un glisser en paysage |
| `captures/36-ia-expert-confirmation-suppression.jpg` | Confirmation avant suppression par l'IA |
| `captures/37-ia-expert-nouvelle-cassette-pluie.jpg` | Cassette « Pluie » créée par l'IA |
| `captures/38-mixtape-expert-colonne-debordee.jpg` | Mixtape en mode expert : Dossier audio disparu |
| `captures/39-historique-ia.jpg` | Historique IA ouvert |
| `captures/40-reglages-impression-calibrage.jpg` | Réglages → Impression, calibrage à la règle |
| `captures/41-etiquettes-voile-7pc.jpg` | Étiquettes avec la pochette en fond, voile à 7 % |
| `captures/42-colonne-droite-coupee.jpg` | Colonne de droite coupée, conseil de voile dans la Vérification |
