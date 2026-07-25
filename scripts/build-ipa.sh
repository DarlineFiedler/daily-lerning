#!/usr/bin/env bash
#
# build-ipa.sh — Erzeugt eine sideload-fähige DailyHangul.ipa für SideStore.
#
# Die App wird für ein echtes Gerät gebaut, App + Widget-Extension werden ad-hoc
# MIT ihren Entitlements nachsigniert (damit die App-Group in der Signatur steht und
# SideStore sie beim Re-Signieren übernimmt) und anschließend als Payload/.ipa gepackt.
#
# Warum ad-hoc nachsignieren statt komplett unsigniert:
#   SideStore liest die einzubettenden Entitlements aus dem vorhandenen Signatur-Blob
#   der App. Ohne die App-Group-Entitlement im Bundle würde SideStore sie NICHT neu
#   registrieren → Widget sieht "No words". Siehe build-run-sim.sh (gleiches Muster).
#
# Datenerhalt: Der SwiftData-Store liegt IMMER lokal (applicationSupportDirectory/
# default.store, siehe PersistenceController.swift) und ist unabhängig von der App-Group.
# Solange SideStore RE-SIGNIERT (nicht deinstalliert + neu installiert), bleiben alle
# Vokabeln erhalten.
#
# Aufruf:
#   ./scripts/build-ipa.sh
#
# Ergebnis:
#   build/DailyHangul.ipa   → in SideStore importieren (bzw. per AirDrop aufs iPhone)
#
set -euo pipefail

# --- Konfiguration ---------------------------------------------------------
SCHEME="DailyHangul"
PROJECT="DailyHangul.xcodeproj"
CONFIGURATION="Release"

# Repo-Wurzel = Verzeichnis über diesem Skript.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DERIVED="$ROOT/build/DerivedData-ipa"
STAGE="$ROOT/build/ipa-stage"
IPA_OUT="$ROOT/build/DailyHangul.ipa"
APP_ENTITLEMENTS="$ROOT/App/DailyHangul.entitlements"
WIDGET_ENTITLEMENTS="$ROOT/Widget/DailyHangulWidget.entitlements"

# --- Toolchain (Homebrew liegt nicht im interaktiven PATH) ------------------
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

echo "▶︎ 1/6  Xcode-Projekt generieren (xcodegen)…"
xcodegen generate >/dev/null

echo "▶︎ 2/6  Für Gerät bauen ($CONFIGURATION, generic/iOS; Clean-Build dauert mehrere Minuten)…"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'generic/platform=iOS' \
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

# Kontrolle: App-Group muss jetzt in der Signatur der App stehen, sonst würde
# SideStore das Widget-Sharing nicht wiederherstellen.
if ! codesign -d --entitlements - "$APP" 2>/dev/null | grep -q 'application-groups'; then
  echo "✗ App-Group-Entitlement fehlt nach dem Signieren — Widget-Sharing würde brechen." >&2
  exit 1
fi
echo "  ✓ application-groups eingebettet."

echo "▶︎ 4/6  Payload zusammenstellen…"
rm -rf "$STAGE"
mkdir -p "$STAGE/Payload"
cp -R "$APP" "$STAGE/Payload/"

echo "▶︎ 5/6  Als .ipa packen…"
rm -f "$IPA_OUT"
(cd "$STAGE" && zip -qry "$IPA_OUT" Payload)
rm -rf "$STAGE"

echo "▶︎ 6/6  Fertig."
echo ""
echo "✓ IPA erstellt: $IPA_OUT"
echo "  Größe: $(du -h "$IPA_OUT" | cut -f1)"
echo ""
echo "Nächste Schritte (einmalig einrichten): siehe docs/sideloading.md"
echo "  1. IPA per AirDrop/Dateien aufs iPhone bringen (oder in SideStore auf dem Mac)."
echo "  2. In SideStore → '+' → DailyHangul.ipa wählen → installieren."
echo "  3. SideStore-Refresh aktivieren (Background-Refresh, alle 7 Tage automatisch)."
