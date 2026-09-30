# Brainstorming

## L'idée

Faire la même chose que [Tapercraft](https://vhs.texs.org/en/jcard) (générateurs de jaquettes de K7),
mais « en mode tuné avec Claude », sans abonnement, dans une app Mac perso, avec en plus un lecteur
qui enregistre la cassette.

Projet indépendant : aucun lien avec le site lafleurstudio.ch.

## Décisions

| Sujet | Décision |
|---|---|
| Plateforme | App macOS native |
| Deux modes | **Album** (l'ordre de l'album est gardé, simple découpe A/B) et **Mixtape** (plusieurs artistes, Claude compose et équilibre) |
| Maison de disque | Champ « maison de disque » sur la jaquette et le code-barres. Exemple : **LAFLEURSTUDIO**, catalogue LFS-001, LFS-002… |
| Référence | Tapercraft (vhs.texs.org), option A : on fait tout nous-mêmes, pas d'abonnement, pas de dépendance à leur service |
| Spotify | Connexion à mon compte perso : tracklist, durées exactes, pochettes, infos d'album |
| Claude | Compose des sélections, équilibre les faces A/B, écrit les textes de jaquette, propose le design (palette, polices, variantes), vérifie avant impression |
| Formats | Tous, avec des cases à cocher dans l'app : J-card (3 à 8 volets), O-card cassingle, étiquettes de K7, obi strip… |
| Source audio | Fichiers audio locaux (MP3, FLAC…) dans un dossier du Mac, associés aux morceaux Spotify. L'app n'intègre pas de téléchargeur. |
| Cassettes | C60 = 30 min/face, C90 = 45 min/face, Custom = minutes par face au choix |
| Réglages avancés (modifiables) | 5 s de blanc en début de bande, 2 s entre morceaux, 30 s de marge en fin de face |
| Look des éditeurs | Comme la mise en page du site lafleurstudio : fenêtres Win98 |
| Écran d'enregistrement | Platine K7 Win98 : VU-mètre à aiguilles, compteur de bande, bobines qui tournent, REC / PLAY / STOP |

## Le lecteur d'enregistrement

1. Choix de la face, vérification que tout tient sur la bande.
2. Tonalité de test pour régler le niveau de la platine (VU-mètre).
3. Compte à rebours : la platine passe de PAUSE à ENREGISTREMENT.
4. Blanc de début de bande, puis les morceaux dans l'ordre avec les blancs entre eux,
   coupure à la milliseconde (c'est l'app qui joue les fichiers).
5. Fin de face A : « stoppe la platine, retourne la K7 », puis face B.

## Type de cassette (connu de Claude)

On dit à l'app (et donc à Claude) quelle cassette on utilise :

- **Bande** : Type I · Normal (ferro), Type II · Chrome (CrO₂), Type IV · Métal
- **Réducteur de bruit** : Dolby B, Dolby C ou aucun
- **Marque / modèle** en texte libre (ex. « TDK SA60 »)
- **Longueur** : C60, C90, custom

Claude s'en sert pour :

- **le design** : badge d'époque sur le rabat ou la tranche (« TYPE II · CrO₂ · HIGH POSITION · 70 µs ·
  DOLBY B NR »), dessiné en texte, sans reprendre les logos déposés des marques ;
- **l'enregistrement** : il rappelle de mettre la platine sur la bonne position de bande et d'activer le
  bon Dolby, et adapte ses conseils de niveau (un Type I sature plus vite qu'un Type II) ;
- **la platine à l'écran** : l'étiquette de la K7 affiche le type et la longueur.

## Code-barres

- **Place par défaut** : en bas du rabat du J-card, centré.
- **Couleurs** : trois choix en un clic : **Blanc** (barres noires sur fond blanc), **Design** (barres
  et fond pris dans la palette de la jaquette, ex. bleu nuit sur blanc écume), ou **Perso** (n'importe
  quelles couleurs). Claude vérifie le contraste : des barres claires sur fond foncé ne se scannent
  souvent pas, il le signale. Autres places : sur la tranche, ou libre (on le glisse où on veut).
- **Types** : EAN-13, UPC-A, Code 128 (accepte des lettres, pratique pour un numéro de catalogue),
  QR code.
- **Chiffres liés aux barres** : les barres sont toujours calculées à partir du numéro (on tape le
  numéro, les barres se redessinent). Les chiffres prennent la même couleur et la même taille que les
  barres et restent placés comme sur un vrai EAN (1 chiffre à gauche, puis 2 groupes de 6 sous
  chaque moitié).
- **Personnalisation** : le numéro (la clé de contrôle EAN est calculée toute seule), une ligne de texte
  au-dessus (ex. « LAFLEURSTUDIO · LFS-001 »), les couleurs des barres et du fond, la taille,
  la rotation, afficher ou non les chiffres.
- **Numéro par défaut** : un EAN commençant par 2 (plage réservée à l'usage interne, qui ne correspond
  à aucun vrai produit), avec numérotation automatique des K7 : LFS-001, LFS-002…
- Claude peut proposer le texte et le numéro de catalogue, et la vérification avant impression contrôle
  que le code-barres reste scannable (taille minimale, contraste, pas de débordement).

## QR code et code Spotify

- **Au choix de l'utilisateur** : trois cases à cocher, code-barres, QR code, code Spotify. On en met
  un seul, deux ou les trois, et Claude replace les autres éléments en conséquence.
- **Générateur de QR code** intégré : lien Spotify de l'album (rempli automatiquement), lien perso
  (Bandcamp, site, Instagram…) ou texte libre. Mêmes couleurs que le code-barres (blanc, design, perso),
  taille et place réglables (recto, rabat, intérieur).
- **Code Spotify** (le code en ondes que l'appli Spotify scanne) : généré depuis l'adresse officielle de
  Spotify pour l'album ou la playlist, dans les couleurs du design. Place par défaut : rabat, au-dessus
  de l'EAN.
- Tous les codes sont réels : scannés, le QR et le code Spotify ouvrent l'album, l'EAN donne son numéro.

## Vérification avant impression (Claude)

Exemple réel trouvé sur la maquette : le texte de la tranche « JEREMY SADIK · AN AFTERNOON AT THE LAKE »
sortait du J-card. L'agent Claude embarqué doit repérer ce genre de problème tout seul, en deux temps :

1. **Mesure automatique** par l'app, à chaque modification : chaque texte est comparé à sa zone
   (tranche, rabat, recto…). Tout ce qui dépasse, passe dans le fond perdu ou devient illisible
   (trop petit à l'impression, contraste trop faible) est signalé.
2. **Regard de Claude** : l'app lui envoie une image du rendu et la liste des alertes. Claude confirme
   et propose une correction, par exemple réduire la police, passer sur 2 lignes, raccourcir
   (« J. SADIK · AFTERNOON AT THE LAKE ») ou changer la mise en page.

Rien ne part à l'impression tant qu'une alerte est ouverte, sauf si on la force.

## Ce que Claude fait mieux que Tapercraft

- Faces A/B : Tapercraft coupe la liste en deux par nombre de titres (`Math.ceil(n / 2)`), sans
  regarder les durées. Claude équilibre par durée selon la cassette choisie, avec un bon enchaînement.
- Design : au lieu de 110 polices et des dizaines de réglages à la main, Claude propose palette,
  polices et variantes selon l'album et l'époque ; on corrige en lui parlant.
- Textes : tranche, liner notes, crédits écrits par Claude (pas de paroles complètes : droits d'auteur).
- Enregistrement : Tapercraft ne fait que le papier.
- Export : gratuit et natif, pas de souci Safari.

## Questions ouvertes

- Maquette visuelle des écrans avant de coder ?
- Ordre de construction (quel module en premier) ?
- Détail des réglages de chaque format (volets, formes de dos, zones de texte).
