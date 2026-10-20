# Consignes de test : corrections après les tests du 7 et du 19 octobre

Version à tester : la dernière de Releases (`derniere-version`). Avant de commencer : `git fetch` puis
`git reset --hard origin/etape-1` si tu as un clone. Teste sur des **cassettes de test** (Dupliquer), pas sur LFS-003.
Note chaque problème à la fin de `docs/retours-test-etape-2.md` (ce qui se passe, ce qui était attendu, une capture),
commit et push sur `etape-1`. Ne corrige rien dans le code.

## 1. Colonnes et export (T7, P5 — bloquant avant)

1. Jaquette : clique le titre (panneau Élément ouvert), « Proposer » (3 variantes), « Vérifier avec Claude », et écris
   5 demandes dans « Modifier avec l'IA ». Attendu : la colonne de droite **défile à la molette**, et **« Exporter » reste
   toujours visible en bas**.
2. Conversation de la direction artistique : au-delà de 2 messages, bouton « Voir les n messages précédents ».
   L'avis de « Vérifier avec Claude » se replie (« Replier » / « Afficher l'avis »).
3. Menu **Fichier → Exporter le PDF… (⇧⌘E)**, **Exporter les PNG 600 DPI…**, **Imprimer la jaquette… (⌘P)** : marchent
   depuis n'importe quel onglet, avec le rappel avant export.
4. Le dossier proposé à l'export est **Documents**, puis le dernier dossier utilisé (plus le dossier musique).
5. Mixtape en mode expert : la colonne de gauche défile, « Dossier audio » et « Composer la sélection » restent accessibles.

## 2. Jaquette

1. **Glisser un élément tourné** (P4) : en Paysage, glisse le titre du recto vers le haut → il monte. Glisse le texte de
   tranche vers le bas → il descend. Un grand glisser ne fait plus sortir l'élément de son panneau (il s'arrête au bord).
2. **Cadre bleu** (P2) : l'image du recto et le texte de tranche sélectionnés ont un cadre pointillé visible.
3. **Position de l'image** (P1) : Paysage + Pleine hauteur, zoom 100 % : le curseur qui ne peut rien faire est grisé, avec
   une phrase qui explique de zoomer. « Zoom de l'image » affiche un %.
4. **Taille du code-barres** (P3) : tape 412 en hauteur → ramené au maximum, affiché sous les champs (« Maximum à cette
   place : … mm »). Le bouton « Auto » n'est plus coupé.
5. **↶ Annuler** s'active aussi après un changement dans la colonne de gauche (orientation, couleur, taille du code, curseurs).
   Un curseur bougé d'un coup = une seule annulation.
6. Plus d'alerte **en double** (titre à 20 pt, tracklist qui dépasse).
7. Groupe Tailles : « Numéro de catalogue (tranche) » et « Mentions techniques (badge) » en entier.
8. Étiquettes « pochette en fond » : le conseil orange apparaît **sous le curseur Voile** sous 30 % ; le titre et la ligne du
   bas ont un petit bandeau de fond qui les rend lisibles. Vérifie aussi à l'impression.
9. Aperçu 3D : tourne le boîtier : au dos, on voit le rabat et la cassette avec son étiquette (plus de bloc noir).

## 3. Mixtape

1. **MusicBrainz** (T1) : « Miles Davis - Kind of Blue » avec le bouton **Chercher** (nouveau). Les éditions cassette
   sont en haut. Importer : la fenêtre « aucun fichier trouvé » propose **Garder sans fichier** (Échap) et **Garder les n
   sans fichier**. L'album reste sur la cassette, sans fichiers.
2. **Composer avec l'IA** (T2) : sans Spotify, avec le dossier Jeremy Sadik → la sélection vient **du dossier** (durées
   affichées). Les idées extérieures sont marquées « à trouver » en orange et ne sont pas cochées.
3. **Réordonner** (T4) : glisse un morceau par la souris sur un autre (trait bleu) → il se place au-dessus. Glisse un
   morceau de la face A vers la face B, ou sous le dernier morceau → il va à la fin.
4. **Vider les faces** : demande confirmation, puis « Remettre les morceaux (n) » les rend.
5. **Remettre « … »** : après 3 morceaux retirés, 3 clics les remettent un par un. Le bouton disparaît quand on change
   de cassette.
6. **Tracklist en Mixtape** (T3) : l'artiste n'est plus répété s'il est le même partout. Avec des artistes différents et
   un titre long, le titre passe sur deux lignes ; **la durée est toujours là**. Vérifie le verso et l'O-card, et le PDF.
7. **Équilibrer** : l'explication parle de morceaux 1 à 6 et de durées en min:s.
8. Spotify sans Premium : la barre d'état dit « Spotify : connecté, sans Premium » en rouge après le refus.

## 4. IA

1. « titre plus gros », « encore plus gros », puis « remets comme avant » → retour à la taille **d'origine** (toute la
   série). « juste la dernière étape » → une seule étape. Le résumé montre « echelles.titre : 1 → 1.3 » (plus de « — »).
2. L'annulation apparaît dans l'Historique IA (le compte correspond au nombre de demandes).
3. « joue la face A » → refus qui dit d'aller dans Enregistrer et de cliquer ●.

## 5. Audio, réglages, langue

1. **VU-mètres pendant la musique** (T9) : lis un passage fort d'un morceau dans Enregistrer → les aiguilles bougent.
   (Le test automatique de la CI le vérifie avec un signal à −12 dBFS.)
2. Réglages → Audio, carte FOX **débranchée** : le menu affiche « Carte son choisie, débranchée… » (plus vide).
3. Réglages → Impression sans imprimante : phrase « Aucune imprimante installée… » au lieu d'un menu vide.
4. Langue anglaise : le rappel avant export et le pied de page du PDF sont en anglais. Collection : « Untitled ».
5. Collection : pendant une recherche, le bas dit « 1 sur 3 cassettes ».

## Pas changé, à dire à Johnny

- **Dupliquer** copie aussi l'historique IA (voulu : la copie garde de quoi « Revenir à cette version »).
- Libellés de bande (« Type I · Normal ») : laissés tels quels.

---

# Recontrôle des points C1 à C5 (retours du 20 octobre)

1. **C1 / C2 Molette** : mets la souris **au-dessus d'un curseur, d'un champ, du panneau Élément ou de la liste de
   « Composer »**, puis tourne la molette. La colonne doit défiler (Jaquette gauche et droite, Mixtape gauche). Au-dessus
   du fil de « Modifier avec l'IA », le fil défile d'abord, puis la colonne quand il est au bout.
2. **C3 MusicBrainz** : « Miles Davis - Kind of Blue » → les **éditions cassette en tête** (1981, 1982, 1987…).
   **Chercher** marche au premier clic juste après avoir tapé. Après import + « Garder sans fichier », la vignette de
   la Collection garde la pochette (même après avoir relancé l'app).
3. **C4 Composer** : sur une cassette qui contient déjà tout le dossier → « Tous les morceaux de ton dossier sont déjà
   sur la cassette · n idées à trouver ailleurs ». Nouvelle cassette : le champ Ambiance est vide.
4. **C5 Glisser vers l'autre face** : à la **vraie souris** (bouton maintenu, déplacement lent), glisse « Glass » de la
   face A sur un morceau de la face B, puis sous le dernier morceau de la face B. L'aperçu pendant le glisser montre
   **le titre du morceau déplacé**. (Avec un outil d'automatisation qui « téléporte » la souris, le glisser part du
   morceau d'arrivée : c'est ce qu'on a vu le 20 octobre. La logique est vérifiée par la CI.)
5. Les points non testés le 20 : 1.2, 2.2, 3.8, 4.2, 5.2.
