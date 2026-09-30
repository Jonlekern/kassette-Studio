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

1. **Clé API Claude** (bouton **i** dans l'app pour le guide complet) :
   - l'abonnement Claude Pro/Max **ne donne pas** de clé API : c'est un compte à part, payé à l'usage ;
   - platform.claude.com → Settings → Billing (un peu de crédit) → Settings → **API keys** → **Create key**
     (workspace « Default ») ;
   - copie la clé `sk-ant-…` (affichée **une seule fois**) et colle-la **uniquement** dans l'app → « Tester ».
     Ne la colle jamais ailleurs ; si c'est arrivé, supprime-la et crée-en une autre.
2. **Spotify** (facultatif, **Premium obligatoire** : sans Premium, Spotify bloque son API) :
   developer.spotify.com/dashboard → Create app → Redirect URI exactement `http://127.0.0.1:8898/callback`
   → coche « Web API » → Save → Settings → copie le **Client ID** (pas le secret). Dans l'app : colle-le,
   « Se connecter… », clique « Agree » dans le navigateur. Guide pas à pas dans l'app (« Guide pas à pas… »).
   Sans Premium : onglet Mixtape → « Cassette depuis le dossier (sans Spotify) ».
3. **Dossier audio** : le dossier où sont tes fichiers (MP3, FLAC, WAV, AIFF, M4A).
4. **Sortie vers la platine** : prise jack, carte son USB…
5. Accepte les conditions → **Commencer**.

## Utilisation

- **Mixtape** : cherche un album (Spotify, ou **MusicBrainz** sans compte), colle un lien Spotify, ou
  « Cassette depuis le dossier ». L'app coupe les faces A/B au mieux et associe chaque morceau à son
  fichier ; les cas douteux sont demandés. Mode Mixtape : décris une ambiance, Claude propose, tu coches.
- **Jaquette** :
  - coche les formats (J-card 3 à 8 volets, O-card cassingle, étiquettes de K7, obi) et les codes
    (code-barres EAN-13 / UPC-A / Code 128, QR code, code Spotify) ; les codes sont réels et se scannent ;
  - « Proposer » : Claude cherche d'abord les vraies éditions cassette de l'album (MusicBrainz, et Discogs
    si tu as mis ton jeton), puis propose 3 variantes (A, B, C). ↻ refait une seule variante,
    « Régénérer tout » les trois, « Versions » revient en arrière. Tu peux lui parler (« plus sombre ») ;
  - pour une mixtape : collage des covers, ta propre image, style K7 maison ou design dessiné par Claude ;
  - **Vérification** : l'app mesure chaque texte à chaque modification (dépasse, trop petit, contraste,
    code illisible). « Tout corriger » ajuste tout seul ; « Vérifier avec Claude » lui montre le rendu ;
  - **Exporter** : PDF (fond perdu 3 mm, traits de coupe et de pliage), PNG 600 DPI, ou Imprimer ;
  - **Aperçu 3D** : la J-card dans son boîtier, glisse pour tourner.
- **Enregistrer** : la K7 de la platine porte ton étiquette. Coche la liste, règle le niveau avec la
  tonalité 1 kHz, mets la platine en ENREGISTREMENT + PAUSE, clique ● et relâche la pause pendant le
  compte à rebours. Les bobines tournent et tout s'arrête net en fin de face.
- **Collection** : toutes tes K7 avec leur recto ; ouvrir, dupliquer, réimprimer la jaquette.

## Imprimer à la bonne taille (une seule fois par imprimante)

1. Réglages → **Impression** : choisis l'imprimante et le papier (A4 ou Letter).
2. **Imprimer la règle** : une règle de 10 cm et une de 4 pouces sortent sur la page.
3. Mesure la règle imprimée avec une vraie règle, tape la valeur (« 9,8 » cm) → **OK**.
4. C'est tout : l'app corrige l'échelle de toutes les impressions sur cette imprimante (réglage gardé,
   bouton « Réinitialiser (100 %) »). En option : règle verticale et décalage des marges.

Toujours imprimer à **100 %**, jamais « Ajuster à la page ». Papier : 170 à 250 g/m² pour les jaquettes,
autocollant pleine page pour les étiquettes. Le PDF exporté n'est pas corrigé : il est à la taille exacte,
pour une impression en boutique.

## Réglages (⌘,)

Audio (sortie vers la platine), Platine (simple ou auto-reverse, durée réelle, délai d'inversion avec
« Mesurer », blancs, marge, compte à rebours), Impression (calibrage), Claude (clé, recherche web sur des
sites de musique choisis), Spotify, Sources (jeton Discogs gratuit), Langue, Conditions.

## Langues

Français, anglais, russe, allemand : Réglages → Langue, puis « Relancer l'app maintenant ». Claude répond
aussi dans la langue choisie.

## Pas encore fait

- Platine double cassette (copie d'une K7) : prévu plus tard.
- Modèles de planches d'étiquettes prédécoupées d'une marque précise (pour l'instant : papier autocollant
  pleine page + traits de coupe).
