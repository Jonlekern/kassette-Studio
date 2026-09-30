# Kassette Recorder (macOS)

App Mac perso pour enregistrer de vraies cassettes depuis Spotify :

1. **Mixtape** : importe tes playlists, un lien d'album ou de morceau, ou fais composer une sélection
   par Claude à partir d'une ambiance. Les durées exactes viennent de Spotify. Claude répartit ensuite
   les morceaux sur la face A et la face B sans dépasser la longueur de la bande (C46, C60, C90, C120),
   en comptant l'amorce et les blancs entre les morceaux.
2. **Jaquette** : Claude écrit le titre, la tranche, les liner notes et les crédits. Tu choisis la pochette
   parmi celles des albums. Export en projet `.json` que **Kassette Creator** ouvre directement
   (Fichier → Ouvrir un projet), avec la tracklist A/B et la pochette.
3. **Enregistrer** : l'app pilote l'app Spotify du Mac et joue la face dans l'ordre, avec un compte à rebours,
   l'amorce, un blanc entre chaque morceau, et un arrêt net à la fin de chaque titre. Une tonalité 1 kHz
   sert à régler le niveau d'entrée de la platine.

## Ce qu'il te faut

- macOS 14 ou plus récent, et les outils de développement Xcode (`xcode-select --install` suffit
  pour compiler ; Xcode complet pour lancer les tests).
- L'app **Spotify** installée sur le Mac et un compte **Premium** (obligatoire depuis 2026 pour
  créer une appli développeur Spotify).
- Une **clé API Claude** : [platform.claude.com](https://platform.claude.com) → API Keys.
- Une platine K7 branchée sur la sortie casque ou ligne du Mac.

## 1. Créer ton appli Spotify (une seule fois, 2 minutes)

1. Va sur [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard) → **Create app**.
2. Nom : `Kassette Recorder` (peu importe). **Redirect URI** : `http://127.0.0.1:8898/callback`
   (exactement ça : Spotify refuse `localhost`). Coche **Web API**.
3. Copie le **Client ID**. Pas besoin du Client Secret : l'app se connecte en PKCE.

L'appli reste en « Development Mode » : elle ne marche que pour ton compte, rien n'est publié.

## 2. Compiler et lancer

```bash
cd kassette-mac
./construire-app.sh --installer   # compile, crée « Kassette Recorder.app » et la met dans /Applications
```

Pour tester sans fabriquer l'app : `swift run` (c'est alors le Terminal qui demande l'autorisation
de piloter Spotify). Tests de la logique : `swift test`.

## 3. Premier lancement

1. **⌘,** (Réglages) : colle ta clé Claude et ton Client ID Spotify, puis **Se connecter à Spotify**.
   Le navigateur s'ouvre, tu acceptes, c'est fait. Les secrets sont rangés dans le trousseau du Mac.
2. Au premier enregistrement, macOS demande si Kassette Recorder peut contrôler Spotify : accepte
   (sinon : Réglages Système → Confidentialité et sécurité → Automatisation).

## Réglages Spotify pour une K7 propre

Dans l'app Spotify → Réglages :

- **Fondu enchaîné** : désactivé (sinon les fins de morceaux se chevauchent).
- **Lecture automatique** : désactivée.
- **Normalisation du volume** : désactivée, et qualité de streaming **Très élevée**.
- Volume Spotify à fond ; règle le niveau avec le volume du Mac en t'aidant de la tonalité 1 kHz
  (vise 0 VU / −3 dB sur la platine).

Active un mode Concentration pendant l'enregistrement pour ne pas graver un son de notification.

## Limites connues

- Pas d'enregistrement du flux Spotify par l'app : c'est la platine qui enregistre la sortie audio
  du Mac, comme une chaîne hi-fi. Les conditions de Spotify interdisent en principe de copier
  leurs contenus ; ça reste un usage perso, à tes risques pour ton compte.
- La recherche Spotify renvoie au plus 10 résultats (limite 2026 des applis en Development Mode).
- Les podcasts et les fichiers locaux des playlists sont ignorés.
- La précision de coupure en fin de morceau est d'environ un dixième de seconde.
