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

## Widget-Hinweis

Lock-Screen-Widgets erlauben kein echtes In-Place-Umschalten per Tap. Ist
„Show meaning on tap“ aktiv, zeigt das Widget nur das Wort; **Tippen öffnet die
App** und zeigt dort Wort + Bedeutung.
