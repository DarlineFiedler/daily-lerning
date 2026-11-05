---
description: Nächstes Issue vorschlagen — alle offenen Issues sichten, schon laufende rausfiltern, priorisieren, dann an /issues bzw. /implement übergeben
allowed-tools: Bash, Read, Grep, Glob, Skill, AskUserQuestion
---

Du hilfst der Nutzerin zu entscheiden, **welches GitHub-Issue als Nächstes** umgesetzt wird — im Repo DailyHangul (`DarlineFiedler/daily-lerning`). Du setzt hier noch **nichts** um; du sichtest, priorisierst und übergibst am Ende an den Umsetzungs-Command.

Alle Shell-Befehle mit `eval "$(/opt/homebrew/bin/brew shellenv)"` prefixen, damit `gh` im PATH ist.

## 1. Alle offenen Issues holen
```
eval "$(/opt/homebrew/bin/brew shellenv)"
gh issue list --state open --limit 200 \
  --json number,title,labels,assignees,createdAt,updatedAt,comments
```
- Gibt es keine offenen Issues: melde das und stopp.

## 2. Herausfinden, was schon in Arbeit ist (nicht nochmal vorschlagen!)
Ein Issue gilt als **belegt**, wenn eines davon zutrifft. Sammle diese Signale:

**a) Issue ist zugewiesen** — aus dem JSON oben: alle Issues mit nicht-leerem `assignees`.

**b) Offener PR arbeitet daran** — alle offenen PRs holen und die Issue-Nummer herausziehen:
```
eval "$(/opt/homebrew/bin/brew shellenv)"
gh pr list --state open --limit 100 --json number,title,headRefName,body,author
```
  - **Branch-Name** trägt per Konvention die Issue-Nummer: `<typ>/<issue>-<slug>` (z. B. `perf/135-garden-home-snapshot`, `feature/sidestore-resigning-36`). Nummer aus `headRefName` parsen.
  - Zusätzlich `body` und `title` nach `Closes #N` / `Fixes #N` / `#N` durchsuchen.

**c) Branch existiert schon** (auch ohne PR):
```
eval "$(/opt/homebrew/bin/brew shellenv)"
git branch -a --format='%(refname:short)'
```
  - Branches im Muster `*/<issue>-*` → diese Issue-Nummer ist belegt.

Bilde die Menge der **belegten Issue-Nummern** aus a + b + c. Diese Issues sind **tabu** für die Empfehlung — führe sie höchstens getrennt als „schon in Arbeit" auf (mit Assignee/PR/Branch), damit transparent ist, warum sie nicht vorgeschlagen werden.

## 3. Freie Issues priorisieren
Aus den offenen Issues die belegten entfernen → **freie Kandidaten**. Diese bewerten und ordnen. Priorisierungs-Heuristik (in dieser Reihenfolge):
1. **Labels / Dringlichkeit:** explizite Prioritäts-Labels (`priority:*`, `P0/P1`, `urgent`) zuerst; dann `bug`/`fix` vor `feature`/`enhancement`; `chore`/`docs` eher nachrangig.
2. **Blocker & Abhängigkeiten:** Issues, die andere blockieren oder von bereits gemergter Arbeit abhängen, hoch. Issues, die auf noch offene PRs/Issues warten, runter.
3. **Aufwand/Nutzen:** kleiner, klar umrissener Scope mit hohem Nutzen schlägt großes, unscharfes Issue. Issues mit unklarem Body sind schlechtere Kandidaten.
4. **Alter/Aktivität:** bei Gleichstand ältere bzw. kürzlich diskutierte (viele `comments`) bevorzugen.

Lies bei den Top-Kandidaten bei Bedarf den Body genauer (`gh issue view <N>`), um Scope und Klarheit einzuschätzen.

## 4. Empfehlung ausgeben
Gib eine knappe **Rangliste der Top 3** freier Issues aus, jeweils mit:
- `#<nummer> — <titel>`
- relevante Labels
- 1 Satz **warum** (Priorität/Nutzen/Scope)

Darüber eine **klare #1-Empfehlung** mit kurzer Begründung. Darunter — falls vorhanden — eine kurze Liste „schon in Arbeit (übersprungen)" mit Nummer + wer/welcher PR.

## 5. Übergeben
Frage die Nutzerin (AskUserQuestion), ob das empfohlene Issue jetzt umgesetzt werden soll — mit den Top-Kandidaten als Optionen, damit sie auch ein anderes wählen kann.

Bei Bestätigung den Umsetzungs-Command mit der Issue-Nummer aufrufen. **Welcher Command existiert, bestimmt die Wahl** (PR 150 benennt `/issues` → `/implement` um):
```
eval "$(/opt/homebrew/bin/brew shellenv)"
ls .claude/commands/implement.md .claude/commands/issues.md 2>/dev/null
```
- Existiert `implement.md` → Skill `implement` mit der Nummer aufrufen.
- Sonst → Skill `issues` mit der Nummer aufrufen.

Will die Nutzerin (noch) nicht starten, lass es bei der Empfehlung bewenden.
