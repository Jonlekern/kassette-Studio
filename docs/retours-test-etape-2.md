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
