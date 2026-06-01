# Hexen- & Elfenzauber mit Kampfregel-Bezug — regelbasiert umsetzbar

Recherche-Stand: 2026-05-31. Reine Recherche, **kein Produktionscode geändert**.

## Zweck & Methode

Diese Liste sammelt **Hexen- und Elfenzauber, die Kampfregeln beeinflussen**, und
bewertet, wie aufwändig eine **regelbasierte** Umsetzung in der App wäre.

Datenquellen:

- **Regelmechanik:** DSA-Regel-MCP-Server (`mcp__dsa-rules__*`), v. a.
  *Liber Cantiones* (Quelle 7) und *Zauberei & Hexenwerk – Liber Cantiones Deluxe*
  (Quelle 19). Jede Mechanik unten ist per Volltext (`get_context`) belegt; die
  Seitenangabe steht jeweils dabei.
- **Spiel-Katalog:** [magie.json](../assets/catalogs/house_rules_v1/magie.json)
  (288 Zauber). Felder `availability`, `attributes` (Probe), `aspCost`, `range`,
  `duration`, `category`, `targetObject`, `source` liegen **im Klartext** vor.

### Zentrale Erkenntnis

Alle hier gelisteten Zauber **existieren bereits als Katalog-Einträge** — aber das
Feld `wirkung` (und `variants`) ist **v3-verschlüsselt** (AES-GCM, siehe
`docs/technical_overview.md` 5.3). Die eigentliche Spielmechanik ist also nicht
maschinenlesbar im Katalog hinterlegt; sie steht nur im verschlüsselten Klartext
bzw. im Regelbuch. „Regelbasiert implementieren" heißt daher konkret: die unten
belegte Mechanik **als ableitbare Werte/Effekte kodieren** (z. B. in
[lib/rules/derived/](../lib/rules/derived/)), verknüpft über die Zauber-`id` —
**nicht** durch Entschlüsseln des Katalogfelds.

### Architektur-Kontext (für die Machbarkeit)

Die App hat **keine aktive Kampf-/Effekt-Engine**. Die Helfer in
[lib/rules/derived/](../lib/rules/derived/) (`combat_rules.dart`,
`active_spell_rules.dart`, `magic_rules.dart`, `maneuver_rules.dart` …) sind reine
Wertberechnungen. Das prägt die Einstufung:

- **Einfach** — reine abgeleitete Berechnung/statischer Wert; passt direkt ins
  Muster `lib/rules/derived/` (z. B. Schadensformel, Selbst-Bonus, Tradition/AsP
  aus `availability`). Keine laufende Zustandshaltung nötig.
- **Mittel** — braucht ein neues Datenfeld bzw. einen laufenden Helden-/Zauber­
  zustand (Buff/Dauer). [active_spell_rules.dart](../lib/rules/derived/active_spell_rules.dart)
  wäre ggf. erweiterbar.
- **Schwer** — benötigt eine echte Kampf-/Effekt-Engine mit Gegnern, Zuständen
  (Furcht, Schlaf, Erstarrung) und Manipulation gegnerischer AT/PA/INI. Existiert
  nicht.

`availability`-Kürzel: **Hex** = Hexe, **Elf** = Elf (Zahl = Verbreitungsgrad;
`Hex(Dru)` = nur in druidischer Variante zugänglich).

---

## A. Schaden (Fernkampf-/Angriffszauber)

### Pfeil des Eises / Feuers / Wassers / Humus / Luft  *(Elf)*
- **Katalog-ids:** `spell_pfeil_des_eises` (Elf3), `spell_pfeil_des_feuers`
  (Mag2, Elf1), `spell_pfeil_des_wassers` (Ach3, Elf1), `spell_pfeil_des_humus`
  (Elf4, Ach3), `spell_pfeil_der_luft` (Elf5, Mag3)
- **Probe:** KL/IN/CH · **Zauberdauer:** 2 Aktionen · **Reichweite:** 7 Schritt
  pro Stufe · **Wirkungsdauer:** augenblicklich
- **Kampfmechanik:** 1W6+1 SP **pro investierter Stufe**; max. so viele Stufen wie
  ZfW (höchstens 7). Kosten **4 AsP pro Stufe**. Trifft bei gelungener Probe
  **automatisch** (kein Ausweichen/Parieren). Schaden **ignoriert Rüstung**
  (außer Pfeil des Erzes), Schadensart je Element. *(Liber Cantiones S. 160)*
- **Wirkungstyp:** Schadenszauber (Fernkampf)
- **Machbarkeit:** **Einfach** — geschlossener Schadensrechner: Eingabe ZfW →
  max. Stufen, Schadens-Spanne (Stufen·(1W6+1)), AsP-Gesamtkosten, effektive
  Reichweite. Reine Funktion, ideal für `lib/rules/derived/`.

### Fulminictus Donnerkeil  *(Elf7, Mag5, Hex(Mag)2)*
- **Katalog-id:** `spell_fulminictus_donnerkeil`
- **Probe:** IN/GE/KO · **Zauberdauer:** 2 Aktionen · **Reichweite:** 7 Schritt
  pro Stufe
- **Kampfmechanik:** 1W6+1 SP **pro Stufe** (max. ZfW, höchstens 7),
  **5 AsP/Stufe**. Schaden zählt als **Wuchtschaden, durch RS normal verringert**.
  Getroffener muss KK-Probe (erschwert um die Stufenzahl) bestehen oder wird
  niedergeworfen. *(Liber Cantiones S. 91)*
- **Wirkungstyp:** Schaden + Niederwerfen
- **Machbarkeit:** **Einfach** für den Schadensrechner (wie Pfeil-Zauber);
  der Niederwerfen-Effekt selbst ist nur als Hinweistext umsetzbar (kein
  Gegnerzustand) → die Berechnung ist Einfach, der Folgeeffekt **Schwer**.

### Hexengalle  *(Ach3, Hex3)*
- **Katalog-id:** `spell_hexengalle`
- **Probe:** MU/IN/CH · **Zauberdauer:** 2 Aktionen · **Reichweite:** 5 Schritt
  (Spuckweite) · **Wirkungsdauer:** augenblicklich
- **Kampfmechanik:** ätzender Speichel, **1 SP pro 2 ZfP\*** auf ungeschützte
  Stelle. Trifft er Rüstung, wird diese Stelle **ungeschützt (RS 0)**, bis die
  Rüstung gereinigt wird; kann auch Waffen anätzen. Kosten 6 AsP.
  *(Liber Cantiones Deluxe S. 114)*
- **Wirkungstyp:** Schaden + Ausrüstungs-Sabotage
- **Machbarkeit:** **Einfach** als Berechnung (SP aus ZfP\*); der „RS 0"-Effekt
  auf konkrete Rüstung ist ein Engine-Thema → **Mittel/Schwer**.

---

## B. Selbstverstärkung / natürliche Waffe

### Hexenkrallen  *(Hex3 — nur Katzen-, Raben-, Eulenhexen)*
- **Katalog-id:** `spell_hexenkrallen`
- **Probe:** MU/IN/KO · **Zauberdauer:** 3 Aktionen · **Reichweite:** selbst
- **Kampfmechanik:** Krallen richten im Nahkampf **1W6+1 TP** an; erleichtern
  Klettern um ZfP\*/2. Kosten **3 AsP (Verwandlung) + 1 AsP pro Spielrunde**,
  Wirkungsdauer max. ZfP\*/2 SR. Variante „Zwanzig Krallen" (+3): Klettern um
  ZfP\* erleichtert. *(Liber Cantiones S. 116)*
- **Wirkungstyp:** Selbst-Buff / natürliche Waffe (AT/TP)
- **Machbarkeit:** **Einfach** — natürliche Waffe mit festem TP-Wert (1W6+1) +
  AsP-Kosten über Dauer als abgeleiteter Wert. Signatur-Hexenzauber, guter
  Erstkandidat. Passt zum Muster der vorhandenen Waffen-/Kampfwertberechnung.

### Eiseskälte Kämpferherz  *(Ach3, Elf3)*
- **Katalog-id:** `spell_eiseskaelte_kaempferherz`
- **Probe:** MU/IN/KO · **Zauberdauer:** 2 Aktionen · **Reichweite/Ziel:** nur
  Zaubernder selbst · **Wirkungsdauer:** ZfP\* Spielrunden
- **Kampfmechanik:** macht **immun gegen Furcht** u. ä.; **+ZfP\*/3 (max. +3)** auf
  alle Proben gegen Furcht, Schmerz, Betäubung; gefeit gegen HORRIPHOBUS und den
  Blick des Basilisken. Kosten 4 AsP. *(Liber Cantiones S. 78)*
- **Wirkungstyp:** Selbst-Buff (Resistenz)
- **Machbarkeit:** **Einfach** — abgeleiteter Selbst-Bonus (+ZfP\*/3, Cap +3) als
  reine Funktion.

---

## C. Kontrolle / Beeinflussung (gegen Gegner)

### Horriphobus Schreckgestalt  *(Mag6, Bor4, Dru3, Hex(Dru)2, Srl1)*
- **Katalog-id:** `spell_horriphobus_schreckgestalt`
- **Probe:** MU/IN/CH (+MR) · **Zauberdauer:** 3 Aktionen · **Reichweite:**
  7 Schritt · **Wirkungsdauer:** ZfP\*/2 SR
- **Kampfmechanik (gestaffelt nach ZfP\*):**
  - 1 ZfP\*: Attacken gegen den Zaubernden nur nach MU-Probe (erschwert um ZfP\*).
  - 4 ZfP\*: Opfer weicht zurück / Rückzugsgefecht (MU, AT, INI-Basis je −1W6 bei
    misslungener MU-Probe).
  - 7 ZfP\*: bei misslungener MU-Probe Abzüge **je 1W6 auf MU, KL, CH, FF, AT, PA,
    FK, INI-Basis** (baut sich 1 Punkt/SR ab).
  - 10+ ZfP\*: Panik, Flucht.

  Wirkt nicht gegen Insekten, Elementare, Untote, Dämonen.
  *(Liber Cantiones S. 121f.)*
- **Wirkungstyp:** Kontrolle (Furcht) — manipuliert gegnerische AT/PA/FK/INI/MU…
- **Machbarkeit:** **Schwer** — braucht Gegnerzustand + Modifikation fremder
  Kampfwerte über Dauer.

### Somnigravis tiefer Schlaf  *(Elf6, Mag5, Ach3, Dru3, Geo3, Hex3, Sch3, Srl3)*
- **Katalog-id:** `spell_somnigravis_tiefer_schlaf`
- **Probe:** KL/CH/CH (+MR) · **Zauberdauer:** 2 Aktionen · **Reichweite:**
  7 Schritt
- **Kampfmechanik:** Schlaf tritt ein, wenn **ZfP\* ≥ aktuelle AuP / 4**
  (aufgerundet). Schlafendes Opfer ist **wehrlos** (mühelos zu töten/fesseln);
  gewaltsames Wecken erlaubt neue Probe. Kosten 8 AsP. *(Liber Cantiones S. 244)*
- **Wirkungstyp:** Kontrolle (Schlaf / handlungsunfähig)
- **Machbarkeit:** **Schwer** (Gegnerzustand). Die **Schwellen-Prüfung**
  (ZfP\* vs. AuP/4) ließe sich als **Einfach**er Hilfsrechner anbieten.

### Band und Fessel  *(Elf5, Hex4, Dru3, Mag3, Ach2, Bor2, Geo2)*
- **Katalog-id:** `spell_band_und_fessel`
- **Probe:** KL/CH/KK (+MR) · **Zauberdauer:** 3 Aktionen · **Reichweite:**
  7 Schritt · **Wirkungsdauer:** ZfP\* Kampfrunden
- **Kampfmechanik:** unsichtbare Fesseln; Opfer kann **weder kämpfen noch fliehen
  noch zaubern** und ist bei Angriff **wehrlos** (keine PA/kein Ausweichen).
  Befreiung: Kraftakt-Probe (erschwert um ZfP\*) pro KR. Kosten 8 AsP.
  *(Liber Cantiones S. 40)*
- **Wirkungstyp:** Kontrolle (Bewegungsunfähigkeit)
- **Machbarkeit:** **Schwer** (Gegnerzustand über Dauer).

### Vipernblick  *(Ach3, Hex3)*
- **Katalog-id:** `spell_vipernblick`
- **Probe:** MU/MU/CH (+MR) · **Zauberdauer:** 2 Aktionen · **Reichweite:**
  4 Schritt · **Wirkungsdauer:** ZfP\* Kampfrunden
- **Kampfmechanik:** Opfer **erstarrt**, ist **wehrlos** (keine AT/PA/Ausweichen);
  kann aber zaubern oder sich mit MU-Probe (erschwert um ZfP\*) lösen. **Angriff
  auf das Opfer beendet den Bann sofort.** Kosten 6 AsP.
  *(Liber Cantiones S. 288)*
- **Wirkungstyp:** Kontrolle (Erstarrung)
- **Machbarkeit:** **Schwer** (Gegnerzustand).

---

## D. Behinderung / Ausrüstung

### Plumbumbarum schwerer Arm  *(Mag7, Dru5, Geo5, Hex5, Ach4, Elf4, Sch4, Srl3)*
- **Katalog-id:** `spell_plumbumbarum_schwerer_arm`
- **Probe:** CH/GE/KK (+MR) · **Zauberdauer:** 3 Aktionen · **Reichweite:**
  7 Schritt · **Wirkungsdauer:** ZfP\* Kampfrunden
- **Kampfmechanik:** Waffenarm wird bleischwer; **AT und PA mit diesem Arm um
  ZfP\* erschwert**; Kraftakt-Probe (erschwert um ZfP\*) nötig, um die Waffe nicht
  fallen zu lassen. Kosten 8 AsP. *(Liber Cantiones S. 212)*
- **Wirkungstyp:** Behinderung (gegnerische AT/PA −ZfP\*)
- **Machbarkeit:** **Schwer** (Modifikation fremder Kampfwerte über Dauer).

---

## E. Weitere Kandidaten (Katalog bestätigt, Mechanik noch per MCP zu ziehen)

Verbreitung aus [magie.json](../assets/catalogs/house_rules_v1/magie.json)
verifiziert; Detail-Regeltext in einer Folge-Runde nachzutragen.

| Zauber | id | Verbreitung | erwarteter Wirkungstyp |
|---|---|---|---|
| Bannbaladin | `spell_bannbaladin` | Elf7, Hex3, Mag6, Dru3 | Kontrolle (Bezirzen) |
| Böser Blick | `spell_boeser_blick` | Hex(Dru)2, Mag2 … | Fluch (Proben-/Kampf-Mali) |
| Krabbelnder Schrecken | `spell_krabbelnder_schrecken` | Hex3, Bor2, Mag2 | Kontrolle (Furcht) |
| Corpofesso Gliederschmerz | `spell_corpofesso_gliederschmerz` | Hex(Mag)2, Elf(Mag)2, Mag4 | Behinderung (Schmerz-Mali) |
| Falkenauge Meisterschuss | `spell_falkenauge_meisterschuss` | Elf6 | Fernkampf-Buff (FK) |
| Bärenruhe Winterschlaf | `spell_baerenruhe_winterschlaf` | Elf4, Ach3 | Kontrolle (Schlaf) |
| Hexenknoten | `spell_hexenknoten` | Hex7 | Kontrolle (Furcht-/Illusionsbarriere) |
| Hexenholz | `spell_hexenholz` | Hex7 | Telekinese (Objekt/Waffe) |

Mobilitäts-Sprüche mit Kampfnähe (sekundär): Krötensprung (`spell_kroetensprung`,
Hex4/Elf3), Spinnenlauf (`spell_spinnenlauf`, Hex4/Elf2), Movimento
(`spell_movimento_dauerlauf`, Elf7), Axxeleratus (`spell_axxeleratus_blitzgeschwind`,
Elf6).

---

## Priorisierte Empfehlung (Machbarkeit × Nutzen)

Zuerst die **„Einfach"-Fälle** — geschlossene Berechnungen, die ohne Kampf-Engine
auskommen und gut ins Muster von [lib/rules/derived/](../lib/rules/derived/) passen:

1. **Pfeil-Zauber-Schadensrechner** (Elf) — 5 Sprüche teilen eine Formel
   (1W6+1·Stufe, 4 AsP/Stufe, RW 7/Stufe, Stufen-Cap = ZfW≤7). Höchster Nutzen
   bei geringstem Aufwand; eine Funktion deckt alle ab. Fulminictus folgt demselben
   Schema (5 AsP/Stufe, Wuchtschaden).
2. **Hexenkrallen** — natürliche Waffe 1W6+1 TP + AsP/Dauer (Signatur-Hexenzauber).
3. **Hexengalle** — SP aus ZfP\* (1 SP / 2 ZfP\*) als Rechner (RS-0-Effekt als
   Hinweis).
4. **Eiseskälte Kämpferherz** — Selbst-Bonus +ZfP\*/3 (Cap +3) als abgeleiteter Wert.
5. **Tradition- & Lernbarkeits-/AsP-Metadaten** aus `availability` — breit nutzbar
   für alle Zauber (Hex/Elf-Erlernbarkeit, Steigerungsspalte, AsP-Anzeige).

**Später / Engine-Thema (Mittel→Schwer):** Horriphobus, Somnigravis, Band und
Fessel, Vipernblick, Plumbumbarum. Diese wirken als **Zustände auf Gegner über eine
Dauer** (Furcht, Schlaf, Erstarrung, AT/PA-Mali) und setzen einen Kampf-/Effekt-
Tracker voraus, den die App noch nicht hat. Sinnvoller Zwischenschritt: einzelne
**Schwellen-/Wirkungsrechner** (z. B. Somnigravis: ZfP\* vs. AuP/4) als reine
Helfer bereitstellen, bevor eine Engine gebaut wird.

## Offene Punkte

- Detail-Regeltext für Abschnitt E nachziehen (`search_rules` → `get_context`).
- Entscheidung über die **Umsetzungstiefe** (statische Regel-Helfer vs. aktive
  Kampf-Engine) steht noch aus — diese Liste ist die Entscheidungsgrundlage.
