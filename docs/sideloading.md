# Sideloading & automatische 7-Tage-Neusignierung (SideStore)

> Betrifft [Issue #36](https://github.com/darlinefiedler/daily-lerning/issues/36).
> Ziel: DailyHangul mit dem **kostenlosen Apple-Account** (Personal Team) aufs iPhone
> laden und die 7-Tage-Signatur **automatisch** erneuern lassen — ohne wöchentlich
> Kabel + Xcode + ▶︎.

## Warum SideStore (und nicht AltStore)?

Beide re-signieren sideloadete Apps mit deinem Apple-Account. Der entscheidende
Unterschied für **diesen** Fall (Mac nur zum Einrichten verfügbar, danach nicht mehr):

| | **SideStore** ✅ | AltStore |
|---|---|---|
| 7-Tage-Refresh | **on-device** über eigenen WireGuard-Tunnel + Anisette | braucht **AltServer auf einem eingeschalteten Mac** im selben WLAN |
| Mac nach Einrichtung nötig? | **nein** | ja (sonst kein Refresh) |
| Free-Apple-Account | ja | ja |

Da der Mac nur **einmalig zum Einrichten** da ist, fällt AltStore praktisch aus:
sein Refresh würde jede Woche einen erreichbaren Mac brauchen. SideStore macht den
Refresh eigenständig auf dem iPhone → passt genau.

## Was automatisch läuft vs. was du selbst tun musst

- **Automatisch (nach Einrichtung):** SideStore erneuert die Signatur im Hintergrund,
  solange das iPhone im WLAN ist und der SideStore-WireGuard-Tunnel aktiv ist. Kein
  Kabel, kein Xcode, kein Mac.
- **Selbst (einmalig):** SideStore installieren, mit dem Apple-Account koppeln, IPA
  importieren, Background-Refresh einschalten (Schritte unten).
- **Selbst (alle ~90 Tage):** Das SideStore-Pairing/Apple-App-spezifische Passwort
  kann ablaufen; dann in SideStore neu anmelden. SideStore meldet das rechtzeitig.

---

## Teil A — IPA erzeugen (auf dem Mac, technisch)

```bash
./scripts/build-ipa.sh
# → build/DailyHangul.ipa
```

Das Skript baut die App fürs Gerät, signiert App **und** Widget-Extension ad-hoc mit
ihren Entitlements nach (damit die App-Group in der Signatur steht, sonst zeigt das
Widget später „No words") und packt alles als `.ipa`. Die ad-hoc-Signatur ist nur ein
Platzhalter — **SideStore ersetzt sie beim Import durch deine Apple-ID-Signatur.**

Bring die `build/DailyHangul.ipa` aufs iPhone: per **AirDrop**, über die **Dateien**-App
oder direkt aus der SideStore-Mac-App beim Pairing.

## Teil B — SideStore einrichten (einmalig)

Die genauen Klick-Schritte ändern sich mit den SideStore-Versionen; maßgeblich ist
immer die offizielle Anleitung: <https://docs.sidestore.io>. Grober Ablauf:

1. **Pairing-Datei erstellen** (Mac, einmalig): mit `Jitterbug`/`SideStore`-Anleitung
   die Geräte-Pairing-Datei erzeugen und aufs iPhone laden.
2. **SideStore installieren:** SideStore selbst wird wie eine sideloadete App
   installiert (die SideStore-Doku führt durch die erste Installation).
3. **Mit Apple-Account anmelden:** in SideStore mit `darline-fiedler@gmx.de`
   (Personal Team) anmelden. Ggf. ein **app-spezifisches Passwort** unter
   <https://account.apple.com> erstellen (2FA).
4. **WireGuard-Tunnel aktivieren:** SideStore richtet einen lokalen VPN/WireGuard-
   Tunnel ein — den bei Nachfrage **erlauben**. Er ist die Voraussetzung für den
   automatischen Refresh ohne Mac.
5. **DailyHangul importieren:** in SideStore `+` → `build/DailyHangul.ipa` wählen →
   installieren.
6. **Entwickler vertrauen:** iPhone → *Einstellungen → Allgemein → VPN &
   Geräteverwaltung* → dem Entwickler-Zertifikat vertrauen.
7. **Background-Refresh einschalten:** in SideStore für DailyHangul den automatischen
   Refresh aktivieren (Standard). SideStore erneuert die 7-Tage-Signatur dann selbst.

## Teil C — Verifizieren (den 7-Tage-Zyklus wirklich prüfen)

- **App-Group / Widget:** Nach der Installation ein DailyHangul-Widget auf den
  Home-/Lock-Screen legen. Zeigt es ein Wort (nicht „No words"), hat SideStore die
  App-Group korrekt re-registriert. Falls „No words": siehe *Bekannte Risiken* unten.
- **Datenerhalt:** Vor dem Umstieg **einmal ein Backup exportieren**
  (*Einstellungen → Sicherung*). Nach dem ersten SideStore-Refresh prüfen, dass alle
  Vokabeln + Lernstand noch da sind.
- **Echter Zyklus:** SideStore einmal über einen vollen 7-Tage-Zeitraum laufen lassen
  und bestätigen, dass die App **nach** Tag 7 noch startet, ohne dass du etwas tun
  musstest.

---

## Datenerhalt — technischer Hintergrund

Die Vokabeldaten sind gegen den 7-Tage-Wechsel bewusst abgesichert:

- Der **SwiftData-Store liegt immer lokal** unter
  `applicationSupportDirectory/default.store` (`App/Persistence/PersistenceController.swift`)
  — unabhängig davon, ob die App-Group beim jeweiligen Build/Signatur erreichbar ist.
- Deshalb überleben die Wörter jedes **Re-Signieren**. Gefährlich wäre nur ein
  **Deinstallieren + Neu-Installieren** (löscht die Sandbox). SideStore re-signiert
  in-place → Daten bleiben.
- Die **App-Group** wird nur noch fürs **Widget** gebraucht (JSON-Snapshot + geteilte
  Settings, siehe `Shared/AppGroup.swift`). Bricht sie, verliert man **keine Daten** —
  nur das Widget aktualisiert dann nicht mehr.

## Bekannte Risiken

- **App-Group auf Free-Accounts:** Ob SideStore die App-Group
  (`group.com.darlinefiedler.dailyhangul`) beim Re-Signieren mit dem kostenlosen
  Account durchgehend korrekt registriert, muss on-device verifiziert werden
  (Widget-Test oben). Falls das Widget dauerhaft „No words" zeigt, funktioniert die
  **App selbst inkl. aller Daten trotzdem** — nur das Widget nicht.
- **3-App-Limit:** Kostenlose Accounts erlauben nur **3 gleichzeitig** sideloadete
  Apps. SideStore + DailyHangul belegen zwei Slots.
- **Fallback:** Der manuelle Weg (iPhone per Kabel an den Mac, in Xcode ▶︎) bleibt
  jederzeit als Notlösung möglich (siehe [README](../README.md#auf-dem-eigenen-iphone-ohne-app-store)).
