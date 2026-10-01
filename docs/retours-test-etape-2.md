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

### 5. Claude ne peut pas retirer la pochette de l'étiquette (et ne le dit pas)

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

### 6. Claude doit pouvoir **tout** changer sur la jaquette

Demande de Johnny : « donne la possibilité de tout changer ». Aujourd'hui, Claude ne touche qu'à une
liste de champs choisis à la main (`ChampsDesign.tous`). Il faut que **tout ce que l'utilisateur peut
régler, Claude puisse le régler aussi**, et même ce qui n'a pas encore de bouton.

Concrètement :
- **Tous les champs du design** (`DesignJaquette` dans `LaFleurCore/Jaquette.swift`) sont modifiables
  par Claude, sans exception : formats, volets, dos, orientation, cadrage, styles, couleurs, polices,
  textes, codes, logos, images posées, alertes… Idéalement, la liste des champs est **générée à partir
  du modèle**, pour qu'un nouveau réglage soit automatiquement accessible à Claude.
- **Chaque élément de chaque format** (J-card recto, verso, tranche, rabat, O-card, étiquettes A/B,
  obi) a une **position, une taille, une rotation, une couleur, une opacité et un état visible/masqué**
  que Claude peut changer. C'est la même base que la demande 3 (sélectionner un élément, le déplacer,
  le redimensionner).
- **Images** : Claude peut afficher, masquer, déplacer, recadrer et redimensionner la pochette sur
  chaque format (recto, étiquettes, O-card…), pas seulement retirer les images posées. Ça inclut les
  modes d'étiquette de la demande 4.
- **Textes** : contenu, taille, police, alignement, italique/gras, nombre de lignes, pour chaque zone.
- **Formes et décors** : ajouter, modifier ou supprimer des éléments graphiques sur n'importe quel
  format, pas seulement sur le recto.
- Chaque changement de Claude passe par l'**historique** (« Versions ») et s'annule en un clic.
- Si une demande reste vraiment impossible, Claude le **dit clairement** (voir demande 5).

### 7. Un « mode IA expert » où Claude a tous les droits

Demande de Johnny : un **mode expert** où l'IA peut tout faire dans l'app, sans être limitée à une
liste de réglages.

**Activation** : Réglages → IA → case « Mode expert : l'IA a tous les droits », **désactivée par
défaut**. Quand il est actif, un badge « IA expert » est visible dans la barre d'état et dans la zone
Claude de la Jaquette.

**Ce que l'IA peut faire en mode expert** :
- **Jaquette** : tout ce qui est décrit dans la demande 6, sans exception, sur tous les formats.
- **Mixtape** : changer l'ordre des morceaux, les faces, retirer ou ajouter des morceaux du dossier
  audio, le type de cassette (C60/C90/custom), la bande, le Dolby, la coque, le titre et l'artiste.
- **Réglages de la cassette** : blancs, marges, compte à rebours, égalisation.
- **Collection** : créer, dupliquer ou renommer une cassette.
- Enchaîner plusieurs actions d'un coup (« fais-moi une C90 ambiance pluie avec une jaquette sombre
  et sans pochette sur l'étiquette »).

**Garde-fous, même en mode expert** :
- Tout passe par l'**historique** (« Versions ») et s'annule en un clic, y compris une série d'actions.
- **Supprimer** une cassette de la Collection demande toujours une confirmation.
- L'IA ne touche jamais aux **clés API**, aux comptes (Spotify, Discogs) ni aux fichiers audio sur le
  disque. Elle ne lance pas non plus l'**enregistrement** ni l'**impression** toute seule : elle peut
  tout préparer, l'utilisateur clique.
- Un résumé clair de ce qui a été changé après chaque demande.

**Hors mode expert** : comportement actuel, l'IA propose et l'utilisateur applique.
