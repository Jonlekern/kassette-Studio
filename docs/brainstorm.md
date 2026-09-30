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
