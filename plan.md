# Plan: DailyHangul – iOS Vokabel-Lern-App (Koreanisch)

## Kontext

Du möchtest eine native iPhone-App zum Sprachenlernen (Fokus Koreanisch/Hangul),
die **komplett offline** funktioniert. Kernbedürfnisse:

- Eigene Vokabeln lokal speichern und wiederholen
- Frei benennbare, farbcodierte **Vokabelgruppen** (z.B. Verben, Essen …)
- **Status pro Vokabel** (4 Stufen, automatisch über einen "Geschafft-Counter" *oder* manuell)
- Mehrere **Lernmodi** (Multiple Choice, Durchgehen/Swipe, Schreiben, Mix)
- **Lock-Screen-Widget** mit rotierendem Wort + optionaler Bedeutung
- **Statistik**, **globale Suche**, **mehrsprachige UI** (DE/EN/KO, umschaltbar)
- Lokal am Mac (Simulator) testbar + auf dein iPhone ladbar
- Alles in `plan.md` dokumentiert und nach
  `github.com/DarlineFiedler/daily-lerning.git` gepusht

Zielumgebung ist vorhanden: **Xcode 26.6, Swift 6.3, Git**. Es fehlen `gh` und
`xcodegen` (Setup via Homebrew, siehe Phase 0).

---

## Technische Entscheidung (Tech-Stack)

| Bereich | Wahl | Begründung |
|---|---|---|
| UI | **SwiftUI** | Modern, deklarativ, native iOS-Feeling, Swipe/Animationen einfach |
| Persistenz | **SwiftData** (lokal) | Apple-natives ORM, 100% offline, ideal für iOS 17+ |
| Widget | **WidgetKit** (Accessory-Widget) | Einzige offizielle Lock-Screen-Widget-API |
| Daten-Sharing App↔Widget | **App Group** + JSON-Snapshot | Robust, entkoppelt Widget von SwiftData |
| i18n | **String Catalog (.xcstrings)** + Runtime-Sprachumschaltung | DE/EN/KO in den Einstellungen wählbar & gespeichert |
| Projektdefinition | **XcodeGen** (`project.yml`) | Textbasiert, versionierbar, reproduzierbar, saubere Git-Diffs |
| Externe Libs | **keine** | Reine Apple-Frameworks → schlank, offline, wartungsarm |

**Ziel-iOS:** iOS 17.0+ (SwiftData, interaktive/aktualisierbare Widgets, String Catalog).

---

## Architektur

```
DailyHangul/                 # Repo-Root (= daily-lerning)
├── project.yml              # XcodeGen-Definition (App + Widget-Target, App Group)
├── plan.md                  # Dieser Plan (Kopie im Repo)
├── README.md                # Setup-/Build-Anleitung
├── .gitignore               # Xcode/macOS
├── App/                     # Haupt-App-Target
│   ├── DailyHangulApp.swift
│   ├── Models/              # SwiftData @Model Klassen
│   │   ├── VocabGroup.swift
│   │   ├── Vocab.swift
│   │   └── LearningStatus.swift
│   ├── Persistence/
│   │   └── ModelContainer+Shared.swift   # App-Group-Container
│   ├── Features/
│   │   ├── Groups/          # Gruppen-Liste + CRUD (Name, Farbe)
│   │   ├── Vocab/           # Vokabel-CRUD, Karten-Editor
│   │   ├── Practice/        # Lern-Engine + 4 Modi
│   │   ├── Statistics/      # Statistik-Übersicht
│   │   ├── Search/          # globale Suche
│   │   └── Settings/        # Sprache, Widget-Einstellungen
│   ├── Localization/
│   │   ├── LocalizationManager.swift      # Runtime-Sprachwechsel
│   │   └── Localizable.xcstrings          # DE/EN/KO
│   └── WidgetSnapshot/
│       └── WidgetSnapshotWriter.swift     # schreibt JSON in App Group
└── Widget/                  # Widget-Extension-Target
    ├── DailyHangulWidget.swift            # accessoryRectangular
    ├── VocabTimelineProvider.swift        # Rotation alle X Min
    └── WidgetSnapshotReader.swift
```

### Datenmodell (SwiftData)

**VocabGroup**: `id`, `name`, `colorHex`, `sortOrder`, `createdAt`, `vocabs: [Vocab]` (cascade delete)

**Vocab**: `id`, `word` (Lernsprache), `meaning` (Muttersprache), `example: String?`,
`statusRaw: Int`, `successCounter: Int`, `includeInWidget: Bool`, `timesPracticed: Int`,
`lastPracticedAt: Date?`, `createdAt`, `group: VocabGroup?`

**LearningStatus** (enum, 4 Stufen — deine Wahl):
`neu (0)` · `amLernen (1)` · `fastGelernt (2)` · `gelernt (3)`

### Status-/Counter-Logik

- Neue / nie geübte Vokabel → **Neu**
- Nach erstem Bearbeiten in einem Lernvorgang → mind. **Am Lernen**
- **Geschafft-Counter** = Streak aufeinanderfolgender richtiger Antworten:
  - `0–2` richtig in Folge → **Am Lernen**
  - `3–4` → **Fast gelernt**
  - `≥ 5` → **Gelernt**
- **Falsche Antwort setzt den Counter auf 0 zurück** (Status wird neu berechnet).
- **Manuell** setzbar: direkte Statusänderung im Karten-Editor überschreibt den
  berechneten Wert (optional mit Counter-Reset).
- Zentrale Helper-Methode `Vocab.registerResult(correct: Bool)` kapselt Counter +
  Status-Neuberechnung, damit alle Modi identisch arbeiten.

---

## Feature-Umsetzung (Mapping zu deinen Anforderungen)

### Gruppen
- Liste aller Gruppen mit Farbpunkt + Vokabelanzahl
- CRUD: Name frei wählbar, **Farbauswahl** (ColorPicker → gespeichert als Hex)
- Tap → Gruppendetail mit Vokabelliste (nach Status filter-/sortierbar)

### Vokabeln
- Karten-Editor: **Wort**, **Bedeutung**, **Beispiel** (optionaler Freitext),
  Status, **Widget-Toggle** (Icon zum An/Aus-Schalten = "für Lock-Screen nutzen")
- Anlegen, Bearbeiten, Löschen, Gruppe zuweisen/verschieben

### Lern-Engine (Start je Gruppe)
Session-Konfiguration vor dem Start:
- **Status-Filter**: einer / mehrere / alle
- **Richtung**: Lernsprache→Muttersprache, umgekehrt, oder gemischt
- **Modus-Auswahl**

Modi:
1. **Multiple Choice** – Wort oben, 4 Antworten (3 Distraktoren aus dem Gruppen-Pool).
   Richtig → Counter +1, Falsch → Counter 0.
2. **Durchgehen (Swipe)** – "Weiß ich" (links / Button → +1), "Weiß ich nicht"
   (rechts / Button → Bedeutung einblenden, Counter 0).
3. **Schreiben** – Eingabe der Übersetzung, Vergleich mit hinterlegter Antwort.
   Richtig → +1. Bei Falsch: Button **"Trotzdem richtig"** (zählt als richtig, +1);
   sonst bei "Weiter" → Counter 0. (Vergleich normalisiert Groß/Klein & Leerzeichen.)
4. **Mix** – Auswahl von 1–n der Modi 1–3; pro Wort wird zufällig einer gewählt.
   Nur ein Modus gewählt = nur dieser wird genutzt.

### Statistik
- Global + pro Gruppe: Anzahl je Status (Neu / Am Lernen / Fast gelernt / Gelernt),
  Gesamtzahl, Fortschrittsbalken/Ring. "Kann ich" = Anzahl **Gelernt**.

### Globale Suche
- Sucht über **alle** Vokabeln in **allen** Gruppen
- Match auf **Wort** *oder* **Bedeutung** (case-/diakritika-insensitiv)
- Ergebnis zeigt Gruppenfarbe; Tap → Karten-Editor

### Mehrsprachige UI (DE / EN / KO)
- `String Catalog` mit DE/EN/KO-Übersetzungen
- `LocalizationManager`: gewählte Sprache in App-Group-`UserDefaults` gespeichert,
  Runtime-Umschaltung über Bundle-Override + `.environment(\.locale,…)`
- Umschaltbar in den **Einstellungen**, persistent; Default = Systemsprache

### Lock-Screen-Widget
- **accessoryRectangular**: Lernwort groß, Bedeutung klein darunter (kein Romaji)
- Datenquelle: App schreibt bei Änderung der aktivierten Wörter/Einstellungen einen
  **JSON-Snapshot** in den App-Group-Container (`WidgetSnapshotWriter`);
  Widget liest ihn (`WidgetSnapshotReader`) → keine SwiftData-Kopplung in der Extension
- **Rotation**: `VocabTimelineProvider` baut eine Timeline mit Einträgen alle
  X Minuten (Dropdown **10/15/30 min, 1h, 2h**), die durch die aktivierten Wörter
  rotieren; Fenster von ~24h, tägliche/änderungsbasierte Neuladung via `WidgetCenter`
- **Einstellungen** (in App, geteilt via App Group):
  - Wechsel-Intervall (Dropdown)
  - Toggle **"Bedeutung anzeigen"**
  - Toggle **"Show meaning on tap"**

> **⚠️ Bekannte iOS-Einschränkung – "Show meaning on tap":**
> Lock-Screen-Accessory-Widgets erlauben **kein echtes In-Place-Umschalten** durch
> Antippen. Umsetzung: Bei aktivem Toggle zeigt das Widget nur das Wort; **Tippen
> öffnet die App per Deep-Link** und zeigt dort Wort + Bedeutung.
> Ein experimenteller AppIntent-Toggle (In-Widget-Reveal) wird nur als optionaler
> Stretch getestet, da die Zuverlässigkeit auf dem Lock Screen nicht garantiert ist.
> → Wird auf dem Gerät verifiziert; Deep-Link ist der garantierte Fallback.

---

## Setup & Tooling (Phase 0 – teils interaktiv durch dich)

Da Homebrew fehlt, sind zwei Schritte **von dir** auszuführen (Passwort/Browser nötig).
Ich bereite alles vor und sage dir die exakten Befehle; du tippst sie mit `!`:

1. **Homebrew installieren** (einmalig, interaktiv):
   `! /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
2. **Tools installieren:** `! brew install gh xcodegen`
3. **GitHub-Login:** `! gh auth login` (Browser)
4. Ggf. **iOS-Simulator-Runtime** laden (falls keiner vorhanden):
   `! xcodebuild -downloadPlatform iOS`

Den Rest (Projektstruktur, Code, `project.yml`, Commits) erledige ich.

---

## GitHub-Workflow

- `git init`, `.gitignore` (Xcode/macOS), `plan.md` + `README.md` + Quellcode committen
- Remote `origin = github.com/DarlineFiedler/daily-lerning.git`
- Push nach `main`; danach lade ich in sinnvollen Commits pro Meilenstein hoch

---

## Lokales Testen

- **Simulator (kein Account nötig):** `xcodebuild build` / Öffnen in Xcode → Run.
  Alle Features inkl. Widget im Simulator testbar.
- **Eigenes iPhone ohne App Store:** Mit **kostenloser Apple-ID** (Personal Team) in
  Xcode signieren → App auf dein Gerät laden (**7-Tage-Ablauf**, danach neu laden).
  Ich richte "Automatic Signing" vor.

> **⚠️ Wichtige Einschränkung (kostenloser Account):** Die **App-Group-Berechtigung**
> (nötig für den Datenaustausch App↔Widget auf dem Gerät) ist bei kostenlosen
> Apple-IDs oft **nicht** verfügbar. Heißt: Die App läuft aufs Gerät, aber das
> **Widget zeigt evtl. keine Daten auf dem echten Gerät** ohne bezahlten
> Developer-Account (99 $/Jahr). Im **Simulator funktioniert alles**.
> → Wir starten Simulator-first; Gerät/Widget-Test entscheidest du später.

---

## Umsetzungs-Phasen (Meilensteine)

1. **Phase 0 – Setup:** Homebrew/gh/xcodegen (du), `project.yml`, App+Widget-Target,
   App Group, `.gitignore`, `README.md`, `plan.md`, Git-Init + erster Push
2. **Datenmodell:** SwiftData-Modelle + App-Group-Container + Seed-Testdaten
3. **Gruppen:** Liste + CRUD + Farbauswahl
4. **Vokabeln:** Karten-Editor (Wort/Bedeutung/Beispiel/Status/Widget-Toggle) + CRUD
5. **Status-Logik:** `registerResult`, 4-Stufen-Berechnung, manuelle Overrides
6. **Lern-Engine:** Session-Config + 4 Modi (MC, Swipe, Schreiben, Mix)
7. **Statistik:** Übersicht global + pro Gruppe
8. **Suche:** globale Suche über Wort/Bedeutung
9. **i18n:** String Catalog DE/EN/KO + Runtime-Umschaltung + Settings
10. **Widget:** Snapshot-Writer/Reader, TimelineProvider (Rotation), Widget-Settings,
    tap-to-reveal (Deep-Link) + Verifikation
11. **Politur:** leere Zustände, Fehlerbehandlung, finaler Commit/Push

---

## Verifikation (End-to-End)

- **Build:** `xcodebuild -scheme DailyHangul -destination 'platform=iOS Simulator,name=iPhone 16' build`
- **App-Flow im Simulator:** Gruppe anlegen (Farbe) → Vokabeln hinzufügen →
  jeden Lernmodus einmal durchlaufen → prüfen, dass Counter/Status korrekt wechseln
  (5× richtig ⇒ *Gelernt*, 1× falsch ⇒ Reset) → Statistik-Zahlen stimmen →
  globale Suche findet Wort & Bedeutung → Sprache in Settings auf EN/KO umschalten,
  UI ändert sich sofort und bleibt nach Neustart erhalten
- **Widget im Simulator:** Wörter per Toggle aktivieren → Widget auf Lock Screen legen
  → nach Intervall rotiert das Wort → "Bedeutung anzeigen"-Toggle wirkt →
  "show meaning on tap" öffnet App am richtigen Wort
- **Git:** `git log`/`gh repo view` zeigt Commits im Remote-Repo
- **(Optional) Gerät:** Free-Signing-Install; App-Group-Verhalten prüfen (s. Warnung)

---

## Offene Punkte / Risiken

- **App Group auf kostenlosem Account** evtl. eingeschränkt → Widget-Datentest ggf.
  erst mit bezahltem Account zuverlässig (Simulator unbetroffen).
- **"Show meaning on tap"** auf dem Lock Screen = Deep-Link-Öffnen statt In-Place
  (iOS-Limit); AppIntent-Reveal nur experimenteller Stretch.
- **Simulator-Runtime** muss ggf. erst geladen werden (Phase 0, Schritt 4).
