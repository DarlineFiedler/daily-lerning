---
description: GitHub-Issue bearbeiten — Plan, Branch von frischem main, umsetzen, testen, linten, committen, pushen, PR aufmachen
argument-hint: <issue-nummer>
allowed-tools: Bash, Read, Edit, Write, Grep, Glob, Skill, TaskCreate, TaskGet, EnterPlanMode, ExitPlanMode
---

Du bearbeitest GitHub-Issue **#$1** im Repo DailyHangul (`DarlineFiedler/daily-lerning`).

Arbeite die folgenden Phasen der Reihe nach ab. Springe nicht voraus. Alle Shell-Befehle mit `eval "$(/opt/homebrew/bin/brew shellenv)"` prefixen, damit `gh`, `xcodegen`, `swiftlint`, `swiftformat` im PATH sind.

## 1. Issue verstehen
- `gh issue view $1` lesen (Titel, Body, Kommentare, Labels).
- Falls das Issue nicht existiert oder unklar ist: stopp und frag die Nutzerin, statt zu raten.

## 2. Plan machen (zuerst!)
- Geh in den **Plan-Modus** (EnterPlanMode) und erarbeite einen konkreten Umsetzungsplan: betroffene Dateien, Vorgehen, wie getestet wird.
- Lass den Plan von der Nutzerin bestätigen (ExitPlanMode), bevor du Code änderst.

## 3. Frischen Branch von main
Erst NACH bestätigtem Plan:
```
eval "$(/opt/homebrew/bin/brew shellenv)"
git switch main
git pull --ff-only origin main
git switch -c <typ>/$1-<kurzer-slug>
```
`<typ>` = `feat` / `fix` / `perf` / `refactor` passend zum Issue. Der Slug beschreibt die Änderung kurz.

## 4. Umsetzen
- Änderungen umsetzen. Bestehenden Code-Stil, Namensgebung und Idiome der Umgebung übernehmen.
- **Version hochzählen** (Pflicht bei jeder Änderung): in `project.yml` unter `settings.base` `CURRENT_PROJECT_VERSION` +1; bei sichtbaren Feature-/Verhaltensänderungen zusätzlich `MARKETING_VERSION` Minor +1. Danach `xcodegen generate` (die `.xcodeproj` ist gitignored).

## 5. Tests
- Für jede neue/geänderte Logik Tests schreiben oder erweitern. Reine SwiftUI-Views sind vom Coverage-Gate ausgenommen — testbare Logik nicht.
- Testlauf muss grün sein (warnings-as-errors ist an):
```
eval "$(/opt/homebrew/bin/brew shellenv)"
xcodegen generate
xcodebuild -project DailyHangul.xcodeproj -scheme DailyHangul \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -enableCodeCoverage YES -resultBundlePath build/Test.xcresult \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES test
```
- Danach das **Coverage-Gate** prüfen: `scripts/check-coverage.sh` — muss die Schwelle halten. Reißt die Änderung die Coverage unter den Floor, Tests nachziehen.
- Langer Build (>8 Min beim ersten Mal): im Hintergrund mit Log laufen lassen, nicht im Vordergrund warten.

## 6. Lint & Format (muss sauber durchlaufen)
Genau wie der CI-Job, sonst blockiert der PR:
```
eval "$(/opt/homebrew/bin/brew shellenv)"
swiftlint lint --strict
swiftformat . --lint
```
- **Erst** `swiftformat .` (ohne `--lint`) zum Autofixen, danach nochmal beide im Lint-Modus, bis beide fehlerfrei sind.
- Achtung Falle: `trailingCommas` ist bewusst NICHT in der SwiftFormat-Whitelist — SwiftLint entfernt trailing commas, SwiftFormat würde sie hinzufügen. Nicht gegeneinander arbeiten.

## 7. Committen & pushen
- Erst committen, wenn Tests grün sind UND Lint/Format sauber ist.
- Commit-Message im Stil der Repo-History (deutsch, prägnant, mit `(#$1)` am Ende der Betreffzeile). Fußzeile:
```
Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
```
- `git push -u origin <branch>`

## 8. PR aufmachen
```
gh pr create --base main --title "<titel> (#$1)" --body "<body>"
```
Body: kurze Zusammenfassung, was gelöst wurde, `Closes #$1`, Hinweis auf Tests/Coverage. Fußzeile:
```
🤖 Generated with [Claude Code](https://claude.com/claude-code)
```
- Danach die CI-Checks im Auge behalten (`gh pr checks`) — **lint**, **test**, **gitleaks** müssen grün werden. Rote Checks sofort fixen, nicht liegen lassen.

## Abschluss
Der Nutzerin melden: Branch, PR-Link, Test-/Coverage-Ergebnis und Status der CI-Checks. Faktentreu — wenn etwas übersprungen wurde oder rot ist, sag es klar.
