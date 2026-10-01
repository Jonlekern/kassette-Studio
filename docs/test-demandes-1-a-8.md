# Consignes de test : bug du Trousseau et demandes 1 à 8

Version à tester : la dernière de Releases (`derniere-version`). Avant de commencer : `git fetch` puis
`git reset --hard origin/etape-1` si tu as un clone. Note chaque problème dans `docs/retours-test-etape-2.md`
(ce qui se passe, ce qui était attendu, une capture), commit et push sur `etape-1`.

## 0. Trousseau (bug bloquant)

1. Installe la nouvelle version par-dessus l'ancienne et lance-la.
2. Attendu : la fenêtre s'ouvre **tout de suite**, avec l'avis « Nouvelle version installée ». Clique « Continuer ».
3. macOS pose **une seule** question pour le trousseau (avant : une par clé). Clique « Toujours autoriser ».
4. Vérifie que les clés sont là (Réglages → IA : la clé est remplie, « Tester » répond OK ; Spotify connecté).
5. Relance l'app (même version) : plus aucune question.
6. Note si macOS redemande encore à la version suivante (attendu : oui, une fois, tant que l'app n'est pas signée par Apple).

## 1. Recadrer l'image du recto

1. Jaquette → Recto : Orientation **Paysage**, puis Cadrage **Pleine hauteur**.
2. Curseurs « Position horizontale » et « Position verticale » : l'image doit glisser dans son cadre, sans déborder.
3. Dans l'aperçu, **glisse l'image** à la souris : même effet. Un cadre bleu pointillé montre ce qui est sélectionné.
4. « Zoom de l'image » : l'image grossit dans son cadre.
5. Ferme et rouvre l'app : le cadrage est gardé.

## 2. Taille des codes en mm

1. Codes → Taille : tape **30 × 12** mm. Le code-barres change dans l'aperçu ; la case grise montre la taille auto.
2. Tape une hauteur de **4** mm : alerte rouge « 6 mm minimum ». Remets 12.
3. QR : coche QR, « Côté du QR » **8** mm → alerte rouge ; 15 mm → plus d'alerte.
4. Spotify (si une cassette importée de Spotify) : largeur 15 mm → alerte ; 30 mm → OK.
5. « Auto » remet la taille automatique.
6. Vérifie au scanner du téléphone qu'un code-barres de 30 mm imprimé se lit.

## 3. Taille et place de chaque élément

1. Groupe **Tailles** (colonne de gauche) : chaque texte a sa taille en points et un bouton ↺. Monte le titre à 20 pt,
   puis ↺ : retour à 15 pt.
2. Dans l'aperçu, **clique le titre** : le panneau **Élément** (en haut à droite) montre son nom, sa taille, sa position,
   rotation, opacité, couleur, « Masquer » et « Taille et place par défaut ».
3. **Glisse** le titre, le logo, le texte de tranche, la tracklist, les codes du rabat : chacun suit la souris (y compris
   sur la tranche, qui est tournée).
4. Change la couleur du titre seul, masque le logo du recto, tourne le badge du rabat : l'aperçu suit.
5. **↶ Annuler** (ou ⌘Z) annule chaque retouche une par une.
6. Exporte en PDF : rien de sélectionné ni de pointillé dans le PDF ; un élément masqué n'apparaît pas.

## 4. Étiquettes de K7

1. Groupe **Étiquettes de K7** : « Petite pochette » (comme avant), « **Pochette en fond** », « **Sans pochette** ».
2. Pochette en fond : l'image remplit l'étiquette, la fenêtre de la bande reste blanche, les textes passent par-dessus.
   Règle le **voile** : sous 30 %, un conseil orange prévient que les textes risquent d'être illisibles.
3. Curseurs de position, ou glisse l'image dans l'aperçu des étiquettes.
4. Sans pochette : plus de carré gris.
5. Écran Enregistrer : la K7 montre la même étiquette.

## 6. L'IA peut tout changer

Réglages → IA : **Mode expert** décoché pour commencer.

1. Boîte **Modifier avec l'IA** (colonne de droite de la Jaquette), écris puis **Appliquer** (⌘↩) :
   - « titre plus gros » → réponse avec « avant → après », le titre grossit ;
   - « encore plus gros » → il grossit encore ;
   - « remets comme avant » → annulé ;
   - « retire la pochette de l'étiquette » → mode « Sans pochette » ;
   - « code-barres de 30 mm » → largeur 30 mm ;
   - « décale l'image vers la gauche », « tranche en rouge », « logo de la maison de disque 2 fois plus grand » ;
   - « mets le logo Sony » → l'image est cherchée et posée.
2. Une demande impossible (ex. « joue la face A ») : l'IA le dit clairement (« Impossible : … »).
3. Mode normal : « passe la cassette en C90 » → l'IA répond que ça demande le mode expert.
4. Coche le **Mode expert** : badge rouge « IA expert » dans la barre d'état et dans la boîte.
   - Dans la Jaquette : « passe en C90 et mets Glass en face B » → les deux sont faits, avec un résumé.
   - Dans **Mixtape** (la boîte apparaît en mode expert) : « mets Glass en premier sur la face A », « bande Type I sans Dolby ».
   - « fais-moi une nouvelle cassette ambiance pluie, jaquette sombre, sans pochette sur l'étiquette » → nouvelle cassette créée.
   - « supprime la cassette LFS-00X » → **demande de confirmation** obligatoire.
   - Bouton **Annuler** sous une réponse : tout revient (y compris la cassette créée, qui disparaît de la Collection).
   - L'IA ne doit jamais lancer l'enregistrement, imprimer, ni toucher aux clés.
5. Refais un test avec GPT puis Gemini (Réglages → IA) si tu as leurs clés.

## 7. Historique IA

1. Groupe **Historique IA** (Jaquette) : chaque demande (boîte, Proposer, Vérifier, Infos web, Équilibrer, Composer)
   avec date, moteur, coût approximatif.
2. Clique une ligne : réponse et changements. « **Revenir à cette version** » remet la jaquette de ce moment-là.
   « **Refaire cette demande** » la renvoie.
3. Collection : bouton « Historique IA (n) » sur la carte d'une cassette.
4. « Effacer l'historique » le vide. Vérifie qu'aucune clé n'apparaît nulle part.

## 8. Boîte « Modifier avec l'IA »

1. Grand champ sur plusieurs lignes, texte d'exemple lisible.
2. Le fil garde la conversation, se fait défiler, « Effacer le fil » le vide.
3. La direction artistique garde « Proposer », les variantes, « Versions » et les infos web ; le petit champ de demande
   a disparu.

## Rappels

- Tonalité 1 kHz : elle sort sur la sortie choisie dans Réglages → Audio, même sans avoir ouvert les Réglages.
- VU-mètres : au repos ils sont en bas ; en lecture ils suivent le niveau (0 VU = niveau de la tonalité).
- Spotify : « Premium obligatoire » est écrit au premier démarrage et dans Réglages → Spotify.
- Guides de connexion (bouton **i**, « Guide pas à pas… ») et calibrage à la règle (Réglages → Impression).
