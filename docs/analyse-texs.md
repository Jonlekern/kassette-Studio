# Analyse de Tapercraft (vhs.texs.org)

Analyse faite le 30/09/2026 à partir des pages `/en/jcard`, `/en/cassingle`, `/en/mcp`,
`/en/specs/cassingle` et des 30 fichiers JavaScript du site.

## Le produit

- Nom : **Tapercraft**, par un développeur solo (« Tex »). Site Next.js / React, 22 langues.
- Plus de 40 générateurs : VHS, DVD, Blu-ray, CD, vinyle, MiniDisc, Betamax ; côté cassette :
  J-card, O-card cassingle, étiquette de K7, obi strip.
- Modèle : design et aperçu gratuits (3 designs sauvegardés), **export PDF/PNG payant**
  (abonnement Stripe ou Bitcoin), parrainage, vitrine communautaire, chat, boîte à idées, aperçu 3D.
- Usage perso uniquement selon leurs conditions ; génère même une « lettre pour l'imprimeur ».

## Générateur J-card

- **Import** : recherche d'album (`/api/music/search`, `/api/music/album`), liens de playlist Spotify,
  YouTube, Apple Music, Deezer, Tidal, Amazon, Bandcamp, SoundCloud ; upload `.m3u` ; liner notes via
  Discogs ; paroles : copie la tracklist et ouvre un site de paroles.
- **Tracklist** : faces A/B, « Sync Sides », artiste et numéros affichables, disposition bas / droite /
  circulaire, séparateurs, édition en bloc de texte. Info-bulle : « Standard cassettes are usually
  30 or 45 minutes per side ».
- **Mise en page** : 3 à 8 volets (« Inner Folds ») ; dos : Cover Only, Short Back, Tapered Back,
  Extended Back, Spindle Slits.
- **Zones** : dos, tranche (1 ou 2 lignes), intérieur, rabat, bloc paroles, « Stereo Text »,
  code-barres (plusieurs normes), QR code ou code Spotify.
- **Polices** : 110 familles (Futura par défaut), réglages taille, graisse, largeur, petites
  capitales, capitales, italique, interlettrage, ombre, contour ; « Save as Default Font ».
- **Couleurs** : fond auto tiré de la pochette, texte, bordures, opacité de la pochette.
- **Déco** : stickers, holographiques, étiquettes de genre, logos de distributeurs rétro, textures.
- **Export** : 600 DPI ; 2 475 px de large pour 3 volets, jusqu'à 9 600 px pour 8 ; papiers Letter,
  Legal, A4, Tabloid, A3, 12×18, 13×19 ; avec ou sans fond perdu ; traits de coupe et de pliage.

## L'état du design dans l'URL

Exemple : `jcard?id=a.1586476451&musicArtist=…&musicA=…&bg=f30342&opacity=0.3&color=ffea80&mp=0.2.00.0.3.0&qcz=1&bcz=1&mpr=cassette.0&qr=8.16_93.9_72_0&sep=2&fb=1f.4k.7.2s.0&f2=1f.1r.4.2s.2&fi=1f.3l.4.2s.0`

| Paramètre | Sens (confirmé dans leur code) |
|---|---|
| `id`, `cid` | Identifiant d'album de leur recherche musique |
| `musicArtist`, `musicAlbum` | Artiste, album |
| `musicA`, `musicB` | Titres de chaque face, séparés par `\|`, durée `(m:ss)` |
| `bg`, `color`, `opacity` | Fond, texte, opacité de la pochette |
| `fb`, `f2`, `fi` (`f3`) | Police du dos, de la tranche, de l'intérieur (de l'album) : index de famille, taille %, graisse /100, largeur %, drapeaux, en base 36 (index 51 = Teko) |
| `qr` | QR code : x, y, échelle, rotation (valeurs par défaut du J-card : 8.16, 93.9, 72, 0) |
| `qcz` | QR colorisé |
| `sep` | Style de séparateur |
| `mpr` | Modèle de support (`cassette.0`) |

## Répartition des faces

Leur fonction `splitTracksIntoSides` :

```js
const t = Math.ceil(tracks.length / 2);
return { sideA: tracks.slice(0, t), sideB: tracks.slice(t) };
```

Aucune prise en compte des durées ni du type de cassette. Sur …Like Clockwork : face A 21:23,
face B 24:36.

## O-card cassingle

Découpe réelle : 168 × 102 mm à plat (6,63 × 4,03 in), rabats en biais, 4 plis, sur Letter ou A4.
Gabarit vierge pour un test d'impression. QR par défaut : x 67.09, y 90.08, échelle 29.

## Serveur MCP

Tapercraft expose un serveur MCP (`https://vhs.texs.org/mcp`) et une API REST : recherche de contenu,
composition d'un design, sauvegarde, export (réservé aux membres). Rien sur l'équilibrage des faces,
l'enregistrement ou l'écriture des textes. On ne s'en sert pas (option A : tout fait maison).
