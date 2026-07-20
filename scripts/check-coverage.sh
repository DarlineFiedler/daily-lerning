#!/usr/bin/env bash
#
# check-coverage.sh – wertet die Line-Coverage der LOGIK-Schicht aus einem
# xcresult-Bundle aus und schlägt fehl, wenn eine Mindestschwelle unterschritten
# wird. Reine SwiftUI-View-Dateien werden bewusst ausgeklammert, weil sie ohne
# UI-Automation kaum unit-testbar sind und die Zahl sonst verwässern würden.
#
# Aufruf:  scripts/check-coverage.sh <pfad/zu/Result.xcresult> [schwelle_prozent]
# Beispiel: scripts/check-coverage.sh build/Test.xcresult 80
#
set -euo pipefail

RESULT_BUNDLE="${1:?Pfad zum .xcresult-Bundle fehlt}"
# Schwelle in Prozent Line-Coverage der Logik-Schicht. Startwert bewusst am
# aktuellen Ist-Stand (~76%) ausgerichtet, damit das Gate heute grün ist und
# Regressionen blockiert. Beim Ausbau der Tests schrittweise Richtung 80 anheben.
THRESHOLD="${2:-75}"

# Dateien, die NICHT in die Coverage-Wertung eingehen:
#  - Testdateien selbst (immer ~100%, würden die Zahl schönen)
#  - SwiftUI-Views, App-/Widget-Einstiegspunkte, Design-System
#  - drei System-Framework-Wrapper, die ohne UI-/Geräte-Automation nicht
#    unit-testbar sind: AVSpeechSynthesizer / UNUserNotificationCenter / WidgetKit
# Erweiterbar per ERE-Alternation.
EXCLUDE_REGEX='Tests\.swift$|/Tests/|/Features/|/DesignSystem/|View\.swift$|App\.swift$|WidgetBundle\.swift$|DailyHangulWidget\.swift$|SpeechService\.swift$|NotificationScheduler\.swift$|VocabTimelineProvider\.swift$'

if ! command -v xcrun >/dev/null 2>&1; then
  echo "xcrun nicht gefunden – läuft dieses Skript auf macOS?" >&2
  exit 1
fi

echo "Coverage-Bericht wird aus $RESULT_BUNDLE gelesen …"

# xccov liefert pro Datei executableLines/coveredLines als JSON. Wir summieren
# über alle nicht-ausgeschlossenen Dateien und rechnen die Line-Coverage aus.
xcrun xccov view --report --json "$RESULT_BUNDLE" \
  | EXCLUDE_REGEX="$EXCLUDE_REGEX" THRESHOLD="$THRESHOLD" python3 -c '
import json, os, re, sys

data = json.load(sys.stdin)
exclude = re.compile(os.environ["EXCLUDE_REGEX"])
threshold = float(os.environ["THRESHOLD"])

# Dieselbe Quelldatei kann in mehrere Targets kompiliert werden (z. B. Shared/
# in App + Widget) und taucht dann doppelt auf. Pro Datei nur EINMAL werten –
# der Eintrag mit den meisten abgedeckten Zeilen gewinnt.
best = {}
for target in data.get("targets", []):
    for f in target.get("files", []):
        path = f.get("path", "")
        if exclude.search(path):
            continue
        execu = f.get("executableLines", 0)
        cov = f.get("coveredLines", 0)
        if execu == 0:
            continue
        prev = best.get(path)
        if prev is None or cov > prev[1]:
            best[path] = (f.get("name", path), cov, execu)

total_exec = 0
total_cov = 0
rows = []
for _path, (name, cov, execu) in best.items():
    total_exec += execu
    total_cov += cov
    rows.append((100.0 * cov / execu, name, cov, execu))

if total_exec == 0:
    sys.exit("Keine wertbaren Logik-Dateien im Coverage-Bericht gefunden – Ausschluss zu breit?")

pct = 100.0 * total_cov / total_exec

rows.sort()
print("\nAbdeckung je Logik-Datei (niedrigste zuerst):")
for r_pct, name, cov, execu in rows:
    print(f"  {r_pct:6.1f}%  {name}  ({cov}/{execu})")

print(f"\nLogik-Schicht gesamt: {pct:.1f}% ({total_cov}/{total_exec} Zeilen)")
print(f"Geforderte Schwelle:  {threshold:.1f}%")

if pct + 1e-9 < threshold:
    print(f"\n❌ Coverage {pct:.1f}% liegt unter der Schwelle {threshold:.1f}%.")
    sys.exit(1)
print(f"\n✅ Coverage {pct:.1f}% erfüllt die Schwelle {threshold:.1f}%.")
'
