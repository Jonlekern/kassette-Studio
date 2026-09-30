# Kassette Studio

App Mac perso pour fabriquer de vraies cassettes audio, de A à Z :

1. **Préparer la mixtape** : import depuis Spotify (tracklist, durées, pochettes), faces A/B équilibrées
   par Claude selon la cassette (C60, C90 ou custom).
2. **Imprimer la jaquette** : J-card, O-card cassingle, étiquettes de K7, obi strip… (on coche ce qu'on
   veut), mise en page assistée par Claude, export PDF / PNG haute résolution.
3. **Enregistrer la K7** : lecteur façon platine Win98 avec VU-mètre, qui joue la face depuis les
   fichiers audio du Mac et s'arrête pile au bon moment.

Usage personnel uniquement, rien n'est publié.

## Où on en est

**Étape 1 en cours** : Mixtape + Enregistrement (code dans [app/](app/), mode d'emploi dans
[app/LISEZMOI.md](app/LISEZMOI.md)). L'app est compilée et testée sur macOS par GitHub Actions à chaque envoi.

- [docs/brainstorm.md](docs/brainstorm.md) : les décisions prises et les questions ouvertes
- [docs/analyse-texs.md](docs/analyse-texs.md) : analyse de Tapercraft (vhs.texs.org), l'outil de référence
- [maquettes/](maquettes/) : sources des maquettes des écrans (lien de la toile : https://claude.ai/artifact/L2NujxGroozC4qXLw1D9un)
- [prototype-v0/](prototype-v0/) : premier prototype Swift écrit trop tôt (avant le brainstorming),
  jamais compilé. Des morceaux sont réutilisables (clients Spotify et Claude), le reste sera réécrit.
