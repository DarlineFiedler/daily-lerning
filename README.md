# DailyHangul 🇰🇷

Eine native iOS-App zum Vokabellernen (Fokus Koreanisch/Hangul), die **komplett
offline** funktioniert. Eigene Vokabeln in farbcodierten Gruppen anlegen, mit vier
Lernmodi wiederholen, Fortschritt über einen Status pro Vokabel verfolgen und das
aktuelle Lernwort auf dem **Lock-Screen-Widget** anzeigen.

## Features

- 📚 Vokabeln lokal speichern (SwiftData), 100 % offline
- 🎨 Frei benennbare, farbcodierte Vokabelgruppen
- 🏷️ Status pro Vokabel: **Neu · Am Lernen · Fast gelernt · Gelernt**
  (automatisch über einen „Geschafft-Counter“ oder manuell)
- 🧠 Vier Lernmodi: Multiple Choice · Durchgehen (Swipe) · Schreiben · Mix
- 🔒 Lock-Screen-Widget mit rotierendem Wort (+ optionaler Bedeutung)
- 📊 Statistik-Übersicht (global + pro Gruppe)
- 🔍 Globale Suche über alle Wörter/Bedeutungen
- 🌍 Mehrsprachige Oberfläche (Deutsch / Englisch / Koreanisch, umschaltbar)

## Tech-Stack

SwiftUI · SwiftData · WidgetKit · App Groups · String Catalog · keine externen
Abhängigkeiten. Ziel: **iOS 17+**. Projektdefinition via **XcodeGen** (`project.yml`).

## Setup

### Voraussetzungen

- macOS mit **Xcode 17+** (getestet mit Xcode 26)
- [Homebrew](https://brew.sh) und [XcodeGen](https://github.com/yonasstephen/XcodeGen)

```bash
# Homebrew (falls noch nicht vorhanden)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# XcodeGen installieren
brew install xcodegen
```

### Projekt generieren & öffnen

```bash
xcodegen generate     # erzeugt DailyHangul.xcodeproj aus project.yml
open DailyHangul.xcodeproj
```

> `DailyHangul.xcodeproj` ist bewusst **nicht** eingecheckt – immer aus
> `project.yml` neu generieren.

### Im Simulator bauen & starten

```bash
xcodegen generate
xcodebuild -project DailyHangul.xcodeproj -scheme DailyHangul \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Oder einfach in Xcode das Schema **DailyHangul** wählen und ▶︎ drücken.

### Auf dem eigenen iPhone (ohne App Store)

1. In Xcode → Target **DailyHangul** → *Signing & Capabilities* → dein
   Apple-Konto als *Team* wählen (kostenloses „Personal Team“ genügt).
2. iPhone per Kabel verbinden, als Ziel wählen, ▶︎.
3. Auf dem iPhone unter *Einstellungen → Allgemein → VPN & Geräteverwaltung* dem
   Entwickler vertrauen.

> ⚠️ Mit kostenlosem Apple-Konto läuft die App **7 Tage**, danach neu installieren.
> Die **App-Group** (Datenaustausch App↔Widget) ist auf kostenlosen Konten evtl.
> eingeschränkt – im Simulator funktioniert alles.

## Projektstruktur

```
App/        Haupt-App (SwiftUI + SwiftData)
Widget/     Lock-Screen-Widget (WidgetKit)
Shared/     Von App & Widget geteilter Code (App Group, Snapshot, Farben)
project.yml XcodeGen-Projektdefinition
plan.md     Detaillierter Umsetzungsplan
```

## Qualitätssicherung & CI

Jede PR gegen `main` durchläuft die GitHub-Actions-Pipelines mit drei parallelen,
**blockierenden** Jobs:

| Job | Prüft | Tool | Datei |
|-----|-------|------|-------|
| **Lint & Format** | Stil-/Fehlerregeln + einheitliche Formatierung | SwiftLint (`--strict`) + SwiftFormat (`--lint`) | `ci.yml` |
| **Build & Test** | Kompiliert, Unit- + UI-Tests, Coverage | `xcodebuild test` + Coverage-Gate | `ci.yml` |
| **Secret Scan** | Keine eingecheckten Keys/Tokens/Passwörter | gitleaks | `security.yml` |

Zusätzlich:
- **Compiler-Warnungen zählen als Fehler** (`SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`).
- **UI-Smoke-Test** (`UITests/`, XCUITest): App startet und zeigt die 5 Haupt-Tabs.
- **Coverage-Kommentar**: die Coverage-Zahl wird bei jeder PR als (aktualisierender)
  Kommentar gepostet – ohne externen Dienst, direkt über GitHub Actions.
- **[Dependabot](.github/dependabot.yml)** hält die verwendeten GitHub-Actions aktuell.
- **Branch Protection** auf `main`: die drei Checks oben sind als *required status
  checks* gesetzt – Merge erst, wenn alle grün sind.

### Lokal vor dem Push prüfen

> **Wichtig – Tool-Versionen:** Die CI pinnt feste Versionen (aktuell **SwiftLint
> 0.65.0** und **SwiftFormat 0.62.1**, siehe `ci.yml`). Ein neueres `brew`-Release
> kann lokal *andere* Verstöße melden als die CI. Version prüfen mit
> `swiftlint version` bzw. `swiftformat --version` – im Zweifel die in `ci.yml`
> gepinnte Version verwenden.

```bash
brew install swiftlint swiftformat   # einmalig

# 1) PRÜFEN – exakt das, was die CI ausführt (0 Verstöße erwartet)
swiftlint lint --strict
swiftformat . --lint

# 2) AUTOMATISCH FIXEN, wo möglich
swiftlint --fix        # behebt auto-korrigierbare Regeln (Kommas, Einrückung, …)
swiftformat .          # wendet die Formatierung an
```

Nach dem Fixen `swiftlint lint --strict` erneut laufen lassen, bis
`Found 0 violations` erscheint. **Nicht jede Regel ist auto-fixbar:** z. B.
`cyclomatic_complexity` (Funktion zu komplex) oder `function_parameter_count` (zu
viele Parameter) musst du von Hand auflösen – meist, indem du die Funktion in
kleinere Teilfunktionen zerlegst.

Konfiguration: [`.swiftlint.yml`](.swiftlint.yml) (idiomatische Kurznamen &
Fachbegriffe erlaubt) und [`.swiftformat`](.swiftformat) (bewusst konservative
Whitelist sicherer Regeln).

### Code-Coverage-Gate

`scripts/check-coverage.sh` wertet die **Line-Coverage der Logik-Schicht** aus dem
`xcresult`-Bundle aus und schlägt unter der Schwelle fehl. Bewusst
ausgeschlossen: Testdateien selbst, SwiftUI-Views und drei nicht unit-testbare
System-Framework-Wrapper (`SpeechService`, `NotificationScheduler`,
`VocabTimelineProvider`).

Aktuelle Schwelle: **75 %** (Ist ~76 %). Beim Ausbau der Tests schrittweise Richtung
80 % anheben – zentral in `.github/workflows/ci.yml` (`COVERAGE_THRESHOLD`).

## Widget-Hinweis

Lock-Screen-Widgets erlauben kein echtes In-Place-Umschalten per Tap. Ist
„Show meaning on tap“ aktiv, zeigt das Widget nur das Wort; **Tippen öffnet die
App** und zeigt dort Wort + Bedeutung.
