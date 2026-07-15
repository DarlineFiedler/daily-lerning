#!/usr/bin/env bash
#
# build-run-sim.sh — Baut DailyHangul, signiert App + Widget-Extension ad-hoc mit
# ihren Entitlements nach (damit der App-Group-Container im Simulator funktioniert
# und das Widget Daten der App sieht) und installiert/startet auf dem Simulator.
#
# Ohne das Nachsignieren embeddet der Build keine App-Group-Entitlement → das
# Widget zeigt "No words". Details siehe README / Memory.
#
# Aufruf:
#   ./scripts/build-run-sim.sh                 # Standardgerät (iPhone 17)
#   SIM_NAME="iPhone 17 Pro" ./scripts/build-run-sim.sh
#
set -euo pipefail

# --- Konfiguration ---------------------------------------------------------
SIM_NAME="${SIM_NAME:-iPhone 17}"
SCHEME="DailyHangul"
APP_BUNDLE_ID="com.darlinefiedler.DailyHangul"
PROJECT="DailyHangul.xcodeproj"

# Repo-Wurzel = Verzeichnis über diesem Skript.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DERIVED="$ROOT/build/DerivedData"
APP_ENTITLEMENTS="$ROOT/App/DailyHangul.entitlements"
WIDGET_ENTITLEMENTS="$ROOT/Widget/DailyHangulWidget.entitlements"

# --- Toolchain (Homebrew liegt nicht im interaktiven PATH) ------------------
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

echo "▶︎ 1/6  Xcode-Projekt generieren (xcodegen)…"
xcodegen generate >/dev/null

echo "▶︎ 2/6  Bauen für Simulator '$SIM_NAME' (erster Clean-Build dauert mehrere Minuten)…"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$SIM_NAME" \
  -derivedDataPath "$DERIVED" \
  build CODE_SIGNING_ALLOWED=NO >/dev/null

APP="$(find "$DERIVED/Build/Products" -maxdepth 2 -name "$SCHEME.app" | head -1)"
if [ -z "$APP" ] || [ ! -d "$APP" ]; then
  echo "✗ Gebaute App nicht gefunden unter $DERIVED/Build/Products" >&2
  exit 1
fi
WIDGET="$(find "$APP" -name '*.appex' | head -1)"

echo "▶︎ 3/6  Ad-hoc-Nachsignieren mit Entitlements (Widget zuerst, dann App)…"
codesign --force --sign - --entitlements "$WIDGET_ENTITLEMENTS" "$WIDGET"
codesign --force --sign - --entitlements "$APP_ENTITLEMENTS" "$APP"

# Kontrolle: App-Group muss jetzt in der Signatur stehen.
if ! codesign -d --entitlements - "$APP" 2>/dev/null | grep -q 'application-groups'; then
  echo "✗ App-Group-Entitlement fehlt nach dem Signieren — Sharing würde nicht funktionieren." >&2
  exit 1
fi
echo "  ✓ application-groups eingebettet."

echo "▶︎ 4/6  Simulator '$SIM_NAME' booten (falls nötig)…"
UDID="$(xcrun simctl list devices available | grep -m1 "$SIM_NAME (" | grep -Eo '[0-9A-F-]{36}')"
if [ -z "$UDID" ]; then
  echo "✗ Simulator '$SIM_NAME' nicht gefunden." >&2
  exit 1
fi
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
open -a Simulator >/dev/null 2>&1 || true

echo "▶︎ 5/6  Installieren…"
xcrun simctl install "$UDID" "$APP"

echo "▶︎ 6/6  Starten…"
xcrun simctl launch "$UDID" "$APP_BUNDLE_ID" >/dev/null

echo ""
echo "✓ Fertig. App läuft auf '$SIM_NAME' ($UDID)."
echo "  Widget hinzufügen: Home-Bildschirm lange drücken → '+' → DailyHangul."
echo "  Lock-Screen testen: im Simulator ⌘L, dann Widget unter der Uhr platzieren."
