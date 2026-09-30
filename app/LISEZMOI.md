# LaFleurStudio — l'app Mac

Étape 1 : **Mixtape + Enregistrement**. Les jaquettes (J-card, étiquettes, O-card, obi) arrivent à l'étape 2.

## Installer

### Option A : télécharger l'app compilée par GitHub

1. Sur GitHub : onglet **Actions** → dernière « Compilation macOS » réussie → en bas, **Artifacts** →
   `LaFleurStudio` (un .zip).
2. Dézippe et glisse **LaFleurStudio.app** dans Applications.
3. Premier lancement : l'app n'est pas signée par Apple, donc macOS la bloque. Fais **clic droit →
   Ouvrir → Ouvrir**. Si ça ne suffit pas, dans le Terminal :
   `xattr -dr com.apple.quarantine /Applications/LaFleurStudio.app`

### Option B : compiler sur ton Mac

Il faut **Xcode** (App Store), pas seulement les outils en ligne de commande : SwiftUI et les tests
en ont besoin. Après l'installation : `sudo xcode-select -s /Applications/Xcode.app`.

```bash
git clone https://github.com/Jonlekern/kassette-Studio.git
cd kassette-Studio/app
./construire-app.sh --installer
```

## Premier démarrage

1. **Clé API Claude** : bouton **i** pour le guide (platform.claude.com → API Keys).
2. **Spotify** : crée une appli sur developer.spotify.com → Create app, Redirect URI
   `http://127.0.0.1:8898/callback`, API « Web API ». Colle le Client ID, puis « Se connecter… ».
3. **Dossier audio** : le dossier où sont tes fichiers (MP3, FLAC, WAV, AIFF, M4A).
4. **Sortie vers la platine** : prise jack, carte son USB…
5. Accepte les conditions → **Commencer**.

## Utilisation

- **Mixtape** : cherche un album (ou colle un lien Spotify), ou « Cassette depuis le dossier ».
  L'app coupe les faces A/B au mieux et associe chaque morceau à son fichier ; les cas douteux sont
  demandés. Mode Mixtape : décris une ambiance, Claude propose, tu coches.
- **Enregistrer** : coche la liste, règle le niveau avec la tonalité 1 kHz, mets la platine en
  ENREGISTREMENT + PAUSE, clique ● et relâche la pause pendant le compte à rebours.
- **Réglages** (⌘,) : sortie audio, platine simple ou auto-reverse (durée réelle, délai d'inversion
  avec « Mesurer »), blancs, marge, compte à rebours, égalisation du volume.

## Pas encore fait (étapes suivantes)

- Jaquettes et impression, vérification avant impression, aperçu 3D.
- Discogs, MusicBrainz, recherche web de Claude (le réglage existe, la recherche arrive).
- Traduction de l'interface en anglais, russe et allemand (Claude répond déjà dans la langue choisie).
