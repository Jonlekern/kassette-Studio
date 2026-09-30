# Brainstorming

## L'idée

Faire la même chose que [Tapercraft](https://vhs.texs.org/en/jcard) (générateurs de jaquettes de K7),
mais « en mode tuné avec Claude », sans abonnement, dans une app Mac perso, avec en plus un lecteur
qui enregistre la cassette.

Projet indépendant : aucun lien avec le site lafleurstudio.ch.

## Décisions

| Sujet | Décision |
|---|---|
| Nom de l'app | **LaFleurStudio** |
| Logo | Une seule version vectorielle (`ressources/logo-lafleurstudio.svg`, LAFLEURSTUDIO ©) en `currentColor` : l'app la colore automatiquement (noir, blanc, couleurs du design de chaque jaquette) |
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

## Gestion des morceaux

- Chaque morceau des faces A/B a une poignée **⋮⋮** (glisser pour réordonner ou passer d'une face à
  l'autre) et un bouton **×** pour le retirer. Retirer un morceau le sort de la cassette sans rien
  supprimer sur le Mac ni sur Spotify ; ⌘Z annule.
- Les durées et le remplissage de la bande se recalculent aussitôt.

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

## Cassette personnalisée sur l'écran d'enregistrement

- La K7 dessinée dans la platine utilise **l'étiquette faite dans le label designer** (écran
  « Étiquettes de K7 ») : c'est le même dessin, pas une copie. On change l'étiquette, la K7 de la platine
  change aussi. La face affichée (A/B) suit la face qu'on enregistre.
- **Les bobines tournent pendant l'enregistrement**, et la bande passe petit à petit de la bobine de
  gauche à celle de droite, au rythme du temps écoulé sur la face.
- **Tout s'arrête net à la fin** : quand le dernier morceau de la face est fini (ou sur STOP), le son est
  coupé, les bobines s'arrêtent et l'app affiche « Arrête la platine, retourne la cassette ». Sur PAUSE,
  les bobines se figent aussi.

## Matériel et réglages

- **Mac** : Apple Silicon (le Mac de Johnny est un M6).
- **Sortie audio** : menu Réglages → Audio qui liste toutes les sorties vues par le Mac (prise jack,
  cartes son USB, HDMI…), avec un VU-mètre de test. L'app joue seulement sur la sortie choisie, sans
  changer la sortie du reste du Mac. Le Bluetooth et AirPlay sont signalés comme déconseillés (retard,
  compression).
- **Platine** : menu Réglages → Platine.
  - **Simple, sans auto-reverse** (cas de Johnny) : après la face A, l'app s'arrête et dit « retourne la
    cassette », puis on lance la face B.
  - **Auto-reverse** : la platine se retourne toute seule en fin de bande. L'app doit donc laisser tourner
    la bande jusqu'au bout de la face A (en silence après le dernier morceau), attendre le délai
    d'inversion, puis lancer la face B toute seule. Réglages : **durée réelle d'une face** (une C60 fait
    souvent un peu plus de 30 min) et **délai d'inversion** en secondes, avec un bouton « Mesurer » : on
    lance la bande et on clique au moment où la platine se retourne.
  - **Double cassette** : prévu pour plus tard (copie d'une K7).

## Impression

Conseil par défaut, qui marche avec n'importe quelle imprimante :

- **J-card, O-card, obi** : papier mat ou satiné de 170 à 250 g/m², A4. Assez rigide pour tenir dans le
  boîtier, assez souple pour se plier sans casser.
- **Étiquettes de K7** : papier autocollant A4 pleine page, mat. L'app imprime les étiquettes avec des
  traits de coupe : pas besoin de planches prédécoupées d'une marque précise (mais des modèles de planches
  prédécoupées courantes peuvent être ajoutés).
- **Page de calibrage** : avant la première impression, l'app imprime une page de test avec des règles.
  On mesure et on corrige le décalage de l'imprimante une fois pour toutes.
- Toujours imprimer à **100 %** (jamais « ajuster à la page »). Export PDF avec fond perdu pour une
  impression en boutique.

## Premier démarrage et clé API Claude

- Au premier lancement, une fenêtre « Bienvenue dans LaFleurStudio » (avec le logo) demande quatre
  choses : **clé API Claude** (fournie par l'utilisateur, bouton « Tester »), **connexion Spotify**,
  **dossier audio**, **sortie vers la platine**. Tout reste modifiable dans Réglages.
- À côté du champ de la clé, un bouton **ⓘ** ouvre un guide :
  - **Pourquoi Claude** : l'assistant intégré ; il propose, l'utilisateur décide.
  - **Son rôle** : mixtape (sélection + équilibre des faces), design (couleurs, polices, variantes),
    textes (tranche, notes, crédits, catalogue), vérification avant impression, conseils d'enregistrement.
  - **Où trouver une clé** : platform.claude.com → compte → un peu de crédit (Billing) → API Keys →
    Create Key → copier la clé `sk-ant-…` → coller et tester.
  - **Coût et données** : paiement à l'usage, quelques centimes par cassette ; la clé reste dans le
    trousseau du Mac ; Claude reçoit titres, durées, infos d'album et une image de la jaquette, jamais
    les fichiers audio.

## Sources d'infos

L'app va chercher les infos à des sources précises, puis les donne à Claude :

1. **Spotify** (compte de l'utilisateur) : tracklist, durées, pochettes, date, ligne ℗.
2. **Tags des fichiers audio** : titre, artiste, album, cover intégrée.
3. **MusicBrainz** + **Cover Art Archive** : maison de disque, numéro de catalogue, crédits, covers HD.
4. **Discogs** (clé gratuite dans Réglages) : notes de pochette, crédits, éditions.
5. **Recherche web de Claude** (option) : limitée à des sites choisis, sources citées, validation
   par l'utilisateur.

Pas de paroles complètes (droits d'auteur) : seulement un lien vers un site de paroles.

## Maisons de disque

- Placées selon les conventions des K7 du commerce : **tranche** (nom ou logo d'un côté, numéro de
  catalogue de l'autre), **dos/rabat** (ligne ℗/©, catalogue, code-barres regroupés en bas),
  **recto** (petit logo en option), **étiquettes** (maison de disque + catalogue).
- Mixtape : LaFleurStudio est la maison de disque de la K7 ; la maison de disque d'origine de chaque
  titre va dans les crédits du volet intérieur.
- Plusieurs maisons de disque : maison de disque d'abord, distributeur ensuite. Rien d'inventé : une
  info introuvable devient une case à remplir.
- **Logos** : les logos des autres maisons de disque sont des marques ; par défaut ils sont écrits en
  texte. Option « Importer un logo » depuis ses propres fichiers, avec l'avertissement « usage perso
  uniquement ». L'app ne télécharge ni ne partage jamais de logos. Le logo LaFleurStudio est dessiné
  normalement.

## Conditions d'utilisation

À accepter au premier démarrage (case à cocher, sans elle le bouton « Commencer » reste grisé), et
rappel court au moment d'exporter ou d'imprimer :

- usage personnel et non commercial : rien n'est fait pour être vendu, loué ou distribué ;
- l'utilisateur est seul responsable de ce qu'il fait avec l'app et de ce qu'il produit (droits d'auteur,
  marques) ;
- pochettes, logos, textes et infos venant de sources externes restent à leurs auteurs ;
- app fournie telle quelle, sans garantie ; l'auteur de LaFleurStudio n'est pas responsable de l'usage
  fait de l'app ni des objets produits ;
- les propositions de Claude peuvent contenir des erreurs ; Claude (Anthropic) et Spotify ont leurs
  propres conditions.

Texte à faire relire par un juriste si l'app sort un jour du cercle perso.

## Collection

Un écran liste toutes les K7 faites (LFS-001, LFS-002…) avec leur jaquette, pour les rouvrir,
les dupliquer ou les réimprimer.

## Ce que Claude fait mieux que Tapercraft

- Faces A/B : Tapercraft coupe la liste en deux par nombre de titres (`Math.ceil(n / 2)`), sans
  regarder les durées. Claude équilibre par durée selon la cassette choisie, avec un bon enchaînement.
- Design : au lieu de 110 polices et des dizaines de réglages à la main, Claude propose palette,
  polices et variantes selon l'album et l'époque ; on corrige en lui parlant.
- Textes : tranche, liner notes, crédits écrits par Claude (pas de paroles complètes : droits d'auteur).
- Enregistrement : Tapercraft ne fait que le papier.
- Export : gratuit et natif, pas de souci Safari.

## Décisions du 30/09

- **Recherche web de Claude** : active par défaut (sites choisis, sources citées, validation par
  l'utilisateur). Désactivable dans Réglages.
- **Discogs** : intégré dès le début (clé gratuite dans Réglages).
- **Égalisation du volume** entre les morceaux : en option (désactivée par défaut).
- **Polices** : polices libres intégrées (Google Fonts, licence OFL) + import de ses propres polices.
- **Sauvegarde** : automatique, sur le Mac.
- **Langues** : français, anglais, russe, allemand. Claude répond dans la langue de l'app.
- **Spotify** : chaque utilisateur se connecte avec son propre compte Spotify dans l'app. À savoir :
  une appli Spotify en mode développeur est limitée à quelques utilisateurs (5 depuis 2026) et son
  propriétaire doit avoir Premium ; pour un usage perso, aucun souci.
- **Association fichiers ↔ titres Spotify** : par titre, artiste et durée. En cas de doute, l'app
  pose la question clairement (« Ce fichier est-il bien “Glass” de Jeremy Sadik ? ») avec les
  candidats, leur durée et un bouton d'écoute, au lieu de choisir en silence.

## Ordre de construction proposé

1. Mixtape + Enregistrement (pour graver une vraie K7 au plus vite)
2. J-card
3. Étiquettes de K7
4. O-card, obi strip, collection

## Questions ouvertes

- Maquette visuelle des écrans avant de coder ?
- Ordre de construction (quel module en premier) ?
- Détail des réglages de chaque format (volets, formes de dos, zones de texte).
