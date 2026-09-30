#!/usr/bin/env bash
# Compile Kassette Recorder et fabrique « Kassette Recorder.app » (signature locale, pour ton Mac uniquement).
# Usage : ./construire-app.sh            → crée l'app dans ./dist
#         ./construire-app.sh --installer → la copie aussi dans /Applications
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/KassetteRecorder"

APP="dist/Kassette Recorder.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/KassetteRecorder"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Kassette Recorder</string>
  <key>CFBundleDisplayName</key><string>Kassette Recorder</string>
  <key>CFBundleIdentifier</key><string>com.lafleurstudio.kassette-recorder</string>
  <key>CFBundleExecutable</key><string>KassetteRecorder</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleDevelopmentRegion</key><string>fr</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>Kassette Recorder pilote l'app Spotify pour jouer chaque face de ta cassette dans l'ordre.</string>
</dict>
</plist>
PLIST

# Signature ad hoc : suffisant pour lancer l'app sur ce Mac et mémoriser l'autorisation d'automatisation.
codesign --force --deep --sign - "$APP"
echo "✓ $APP"

if [[ "${1:-}" == "--installer" ]]; then
  rm -rf "/Applications/Kassette Recorder.app"
  cp -R "$APP" /Applications/
  echo "✓ Installée dans /Applications"
fi
