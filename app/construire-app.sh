#!/usr/bin/env bash
# Compile LaFleurStudio et fabrique « LaFleurStudio.app » (signature locale, pour usage perso).
# Usage : ./construire-app.sh            → crée l'app dans ./dist
#         ./construire-app.sh --installer → la copie aussi dans /Applications
set -euo pipefail
cd "$(dirname "$0")"

# SwiftUI (macros) et XCTest ne sont livrés qu'avec Xcode, pas avec les seuls outils en ligne de commande.
if [[ "$(xcode-select -p 2>/dev/null)" != *Xcode*.app* ]]; then
  echo "✗ Il faut Xcode (App Store), puis : sudo xcode-select -s /Applications/Xcode.app" >&2
  echo "  (sinon, télécharge l'app compilée par GitHub : voir LISEZMOI.md, option A)" >&2
  exit 1
fi

swift build -c release
BIN="$(swift build -c release --show-bin-path)/LaFleurStudio"

APP="dist/LaFleurStudio.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/LaFleurStudio"

# Icône : la cassette pixel art de lafleurstudio.ch, dessinée net à chaque taille (pas de flou de réduction).
iconutil -c icns Ressources/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

# Polices libres (licences OFL et Apache jointes), chargées automatiquement par macOS au lancement.
cp -R Ressources/Polices "$APP/Contents/Resources/Polices"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>LaFleurStudio</string>
  <key>CFBundleDisplayName</key><string>LaFleurStudio</string>
  <key>CFBundleIdentifier</key><string>ch.lafleurstudio.app</string>
  <key>CFBundleExecutable</key><string>LaFleurStudio</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleDevelopmentRegion</key><string>fr</string>
  <key>CFBundleLocalizations</key><array><string>fr</string><string>en</string><string>ru</string><string>de</string></array>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.music</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>ATSApplicationFontsPath</key><string>Polices</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"
echo "✓ $APP"

if [[ "${1:-}" == "--installer" ]]; then
  rm -rf "/Applications/LaFleurStudio.app"
  cp -R "$APP" /Applications/
  echo "✓ Installée dans /Applications"
fi
