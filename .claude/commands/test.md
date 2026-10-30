---
description: Komplette App einmal testen (Unit + Integration + E2E) und eine priorisierte Findings-Tabelle + Test-Abdeckungs-Matrix ausgeben
allowed-tools: Bash, Read, Grep, Glob, Skill, AskUserQuestion, TaskCreate, TaskGet
---

Du machst einen **Test-Gesundheitscheck** der gesamten App DailyHangul (`DarlineFiedler/daily-lerning`): einmal alles bauen & testen, Lücken finden, und eine **priorisierte Tabelle aller Findings** sowie eine **Abdeckungs-Matrix (Unit / Integration / E2E)** ausgeben. Du **änderst hier keinen Code** — du diagnostizierst, priorisierst und übergibst am Ende optional an den Umsetzungs-Command.

Alle Shell-Befehle mit `eval "$(/opt/homebrew/bin/brew shellenv)"` prefixen (PATH für `gh`, `xcodegen`, `xcodebuild`, `xcrun`).

## 1. Projekt generieren & Gesamt-Testlauf (Hintergrund)
Das Scheme `DailyHangul` führt **beide** Bundles aus — `DailyHangulTests` (Unit + Integration) **und** `DailyHangulUITests` (E2E).
```
eval "$(/opt/homebrew/bin/brew shellenv)"
xcodegen generate
xcodebuild test \
  -project DailyHangul.xcodeproj -scheme DailyHangul \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -enableCodeCoverage YES -resultBundlePath build/Test.xcresult
```
- **Bewusst OHNE** `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` laufen lassen — so bricht der Build nicht an der ersten Warnung ab und du kannst **alle Warnungen** einsammeln (als eigene Findings).
- Erster Build dauert lange (>8 Min): **im Hintergrund mit Log** laufen lassen, nicht im Vordergrund blockieren. Log beobachten, bis `TEST SUCCEEDED`/`TEST FAILED` erscheint.
- Bricht der Build komplett ab (Compile-Fehler): das ist Finding **P0** — Fehler samt Datei/Zeile aufnehmen und trotzdem mit Schritt 3 (statische Analyse) weitermachen, soweit möglich.

## 2. Ergebnisse einsammeln
- **Fehlgeschlagene Tests:** aus dem Log (`Test Case '-[… ]' failed`) oder aus dem Bundle:
  `xcrun xcresulttool get test-results tests --path build/Test.xcresult` (Fallback: Log nach `failed`/`error:` grep).
- **Compiler-Warnungen:** im Build-Log nach `warning:` grep — pro Datei/Regel zusammenfassen (nicht jede Zeile einzeln).
- **Coverage je Logik-Datei:** `scripts/check-coverage.sh build/Test.xcresult` — gibt die Pro-Datei-Liste „niedrigste zuerst" + Gesamtwert + ob die Schwelle (75 %) gehalten wird.

## 3. Abdeckungs-Lücken bestimmen (Unit / Integration / E2E)
Quelldateien vs. Tests gegenüberstellen. Wichtig: dieselbe Ausschluss-Logik wie das Coverage-Gate verwenden, damit keine bewusst ausgeklammerten Dateien als „Lücke" gemeldet werden. Ausgeschlossen sind (siehe `scripts/check-coverage.sh`): Testdateien, `Features/`, `DesignSystem/`, `*View.swift`, App-/Widget-Einstiegspunkte sowie System-Wrapper (`SpeechService`, `NotificationScheduler`, `BadgeUpdater`, Timeline-Provider, `DemoSeed`).

**a) Unit** — reine Logik in `Shared/` und `App/` (nicht ausgeschlossen):
```
eval "$(/opt/homebrew/bin/brew shellenv)"
ls Tests/*.swift | wc -l
find Shared App -name '*.swift' | wc -l
```
  - Logik-Dateien **ohne** zugehörige `…Tests.swift` bzw. mit **0 %/unter Schwelle** Coverage → Lücke. Typ/Funktionsname nennen.

**b) Integration** — Tests, die mehrere Komponenten / IO / Persistenz / Sync zusammen prüfen (in diesem Repo im selben `Tests/`-Bundle, erkennbar an Namen wie `*StoreIO*`, `*Importer*`, `*Persistence*`, `*Reconciler*`, `*Backup*`, `AppContentRefresh*`). Prüfen, ob die kritischen Pfade — CSV-Import/-Export, SwiftData-Persistenz (App-Group!), Widget-Result-Sync, Deep-Links, Notification-Scheduling — je **mindestens einen** Integrationstest haben. Fehlt einer → Lücke.

**c) E2E** — `UITests/` (XCUITest). Für jeden Haupt-User-Flow prüfen, ob ein UI-Test existiert (Onboarding, Vokabel anlegen/lernen, Practice-Session, Garten, Statistiken). Aktuell nur `DailyHangulUITests.swift` → die meisten Flows sind E2E **nicht** abgedeckt; die wichtigsten ungetesteten Flows als Findings aufnehmen.

## 4. Findings priorisieren & als Tabelle ausgeben
Alles aus 2+3 zu einer Liste zusammenführen, mit Priorität:
- **P0** — Build bricht ab / Tests schlagen fehl / Flaky-Crash. Blockiert alles.
- **P1** — Kern-Logik ohne Test oder unter der Coverage-Schwelle; fehlender Integrationstest auf einem kritischen Datenpfad (Import/Persistenz/Sync).
- **P2** — Compiler-Warnungen; wichtiger User-Flow ohne E2E-Test; spröde/langsame Tests.
- **P3** — Kleinkram: Randfälle, Komfort, Aufräumen.

Ausgabe als **Markdown-Tabelle**, P0 zuerst:

| Prio | Bereich | Finding | Datei/Flow | Empfehlung |
|------|---------|---------|------------|------------|
| P0 | Test | `XYZTests.foo` schlägt fehl | Tests/XYZTests.swift:42 | … |
| P1 | Unit | Keine Tests für `ReviewScheduler.next()` | Shared/ReviewScheduler.swift | Unit-Test ergänzen |
| P2 | E2E | Practice-Session nicht E2E-abgedeckt | UITests/ | UITest-Flow ergänzen |

Darunter die **Abdeckungs-Matrix** als zweite Tabelle:

| Ebene | Status | Kennzahl | Größte Lücke |
|-------|--------|----------|--------------|
| Unit | … | Logik-Coverage X % (Gate 75 %) | … |
| Integration | … | N kritische Pfade, davon M abgedeckt | … |
| E2E | … | K Flows, davon J als UITest | … |

Abschließend eine **Zusammenfassung in 2–3 Sätzen**: Gesamtzustand (grün/gelb/rot), die 1–3 dringendsten Baustellen. Faktentreu — schlägt etwas fehl oder wurde ein Schritt übersprungen, klar sagen.

## 5. Übergeben (optional)
Frag die Nutzerin (AskUserQuestion), ob aus dem Top-Finding gleich Arbeit werden soll:
- **Issue(s) anlegen** für die dringendsten Findings (`gh issue create` mit passenden Labels), oder
- direkt umsetzen → Umsetzungs-Command mit der Nummer aufrufen. Welcher existiert, bestimmt die Wahl (siehe #150):
```
eval "$(/opt/homebrew/bin/brew shellenv)"
ls .claude/commands/implement.md .claude/commands/issues.md 2>/dev/null
```
  - `implement.md` vorhanden → Skill `implement`, sonst Skill `issues`.

Will sie nichts starten, bleibt es beim Report.
