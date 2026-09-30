# Test de l'étape 2 (jaquette) et des nouveautés

À faire sur le Mac avec l'app du dernier artefact « LaFleurStudio » de GitHub Actions. Pour chaque point :
OK, ou ce qui ne va pas (+ capture dans `docs/captures/`). Les retours vont dans
`docs/retours-test-etape-2.md`, puis `git add`, `git commit`, `git push` sur la branche `etape-1`.

## A. Jaquette

1. Onglet **2. Jaquette** : l'aperçu montre la J-card entière (bouton « Ajuster »). Zoom : le curseur marche.
2. Coche/décoche J-card, O-card, Étiquettes, Obi : les boutons au-dessus de l'aperçu suivent.
3. Volets 3 à 8, dos Court/Normal/Long/Biseauté/Recto seul : les dimensions en bas changent.
   À 3 volets, un bouton « J-card verso » apparaît (notes et crédits au dos).
4. Codes : Barres + QR + Spotify. Scanne avec le téléphone : l'EAN donne 2000126000012 (LFS-001),
   le QR ouvre l'album, le code Spotify (appli Spotify → recherche → icône appareil photo) aussi.
5. Couleurs du code : Blanc / Design / Perso. Mets des barres claires sur fond foncé : alerte rouge.
6. Tape un texte de tranche très long : alerte « dépasse ». « Tout corriger » : la taille baisse
   (jamais sous 5 pt) ou le texte est raccourci.
7. Avec la clé Claude : « Proposer » → 3 variantes A/B/C. Clic sur une variante = appliquée.
   ↻ refait une seule variante. « Versions » revient en arrière. Demande « plus sombre ».
8. « Vérifier avec Claude » : il commente le rendu et propose des corrections.
9. « Chercher les infos de l'album sur le web » : maison de disque, catalogue, sources citées.
10. Album connu en cassette (ex. un album des années 80-90) : « Chercher sur MusicBrainz » montre des
    scans de vraies K7 avec leur source.
11. Mixtape : style « Collage des covers », « Style K7 maison », « Ta propre image » (Choisir une image…).
12. Aperçu 3D : la K7 tourne à la souris.
13. Exporter : PDF (ouvre-le : fond perdu, traits de coupe et pointillés de pliage), PNG 600 DPI.

14b. Codes → Place « Libre (à glisser) » : glisse les codes dans l'aperçu de la J-card, change la rotation.
14c. Maison de disque autre que LAFLEURSTUDIO → « Importer un logo… » : l'avertissement « usage perso »
     s'affiche, puis le logo remplace le nom sur le recto et la tranche.
14d. Case « Lien vers les paroles » : une ligne « Paroles : genius.com » apparaît dans les crédits.
14e. Avec Discogs : « Reprendre crédits et notes » sur une édition remplit les crédits.
14f. « Cassette depuis le dossier » avec des MP3/M4A qui ont une pochette intégrée : la pochette apparaît
     sur la jaquette sans Spotify.

## B. Impression

14. Réglages → Impression : « Imprimer la règle ». Mesure, tape la valeur, OK. Le message vert affiche
    l'échelle.
15. Imprime une J-card : elle doit rentrer pile dans un boîtier de K7 (plis aux bons endroits).
16. Étiquettes sur papier autocollant : elles tiennent sur une cassette, la fenêtre tombe au bon endroit.

## C. Enregistrer

17. La K7 dessinée dans la platine porte l'étiquette de la jaquette (titre, face A/B, couleurs).
18. Pendant l'enregistrement, les bobines tournent et la bande passe de gauche à droite.

## D. Langues et collection

19. Réglages → Langue → English → « Relancer l'app maintenant » : l'interface est en anglais.
    Pareil en русский et Deutsch. Reviens en français.
20. Collection : chaque cassette montre son recto ; « Réimprimer la jaquette » ouvre l'onglet Jaquette.

## E. Sources

21. Réglages → Sources : colle un jeton Discogs (guide dans la page). Les éditions Discogs apparaissent
    en plus de MusicBrainz au point 10.
