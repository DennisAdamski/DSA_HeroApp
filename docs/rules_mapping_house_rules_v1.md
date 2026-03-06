# House Rules v1 Mapping (DSA Excel)

Quelle: `Charaktersheet_DSA_mit_Hausregeln Hexe.xlsx`

## Implementierte Kernwerte

- LeP Max
  - Sheet: `Eigenschaften`
  - Excel-Hinweis: Formelbereich um `O20/P20`
  - App: `baseLeP = CEIL((KO + KO + KK) / 2)`, dann `+ mods.lep + bought.lep + min(level,21)`

- Au Max
  - Sheet: `Eigenschaften`
  - Excel-Hinweis: Formelbereich um `O21/P21`
  - App: `baseAu = CEIL((MU + KO + GE) / 2)`, dann `+ mods.au + bought.au + 2 * min(level,21)`

- AsP Max
  - Sheet: `Eigenschaften`
  - Excel-Hinweis: Formelbereich um `P22`
  - App: `baseAsp = CEIL((MU + IN + CH) / 2)`, dann `+ mods.asp + bought.asp + 2 * min(level,21)`

- KaP Max
  - Sheet: noch nicht eindeutig gemappt
  - App MVP: deterministischer Platzhalter `max(0, mods.kap + bought.kap)`

- MR
  - Sheet: `Eigenschaften` (MR-Berechnungsblock)
  - App: `baseMr = ROUND((MU + KL + KO) / 5)`, dann `+ mods.mr + bought.mr + ROUND(min(level,21) / 3)`

- Ini-Basis
  - Sheet: `Nahkampf`/`Rechner`-Bezug, Kernformel analog im Attributsatz
  - App: `CEIL((MU + MU + IN + GE) / 5) + mods.iniBase`

- GS, Ausweichen
  - MVP als Platzhalter mit Modifikator-Additionen (`base=0`) bis exakte Zellzuordnung fertig ist.

## Rundungsregeln

- Alle Formeln nutzen Dart-`ceil()`/`round()` entsprechend der aktuell gemappten Excel-Formeln.
- Negative Endwerte werden auf `0` geklemmt, wo es sich um Ressourcen-Maxima handelt.

## Magie-System

### Datenmodell

- **HeroSpellEntry**: Speichert ZfW (spellValue), Modifikator, Hauszauber-Flag und Varianten pro aktiviertem Zauber; technisch bleibt das Listenfeld `specializations` aus Kompatibilitaetsgruenden bestehen.
- **MagicSpecialAbility**: Name + optionale Notiz fuer magische Sonderfertigkeiten.
- **HeroSheet** (schemaVersion 5): Neue Felder `spells` (Map<String, HeroSpellEntry>), `representationen`, `merkmalskenntnisse`, `magicSpecialAbilities`.

### Regelfunktionen (`magic_rules.dart`)

- **Verfuegbarkeit parsen** (`parseSpellAvailability`): Parst Strings wie `"Mag6, Hex3, Dru(Elf)2"` in strukturierte `SpellAvailabilityEntry`-Objekte.
- **Traditions-Extraktion** (`extractTraditions`): Gibt die Haupttraditions-Kuerzel zurueck (z.B. `['Mag', 'Hex']`).
- **Verfuegbarkeitspruefung** (`spellAvailabilityForRepresentations`): Prueft, ob ein Zauber fuer die Repraesentationen des Helden verfuegbar ist. Gibt die beste (niedrigste) Verbreitungsstufe zurueck oder `null`. Sub-Traditionen (z.B. `Dru(Elf)`) erfordern, dass der Held beide Repraesentationen besitzt.
- **Effektive Steigerung** (`effectiveSteigerung`): Reduziert die Steigerungskategorie (A–F) um eine Stufe, wenn der Zauber Hauszauber ist ODER der Held passende Merkmalskenntnisse besitzt. Hauszauber und Merkmalskenntnisse werden nicht kumuliert — maximale Reduktion ist eine Stufe.
- **Merkmale parsen** (`parseSpellTraits`): Splittet Merkmale-Strings wie `"Eigenschaften, Elementar (Erz)"` in eine Liste.

### UI-Tab (Magie)

- **hero_magic_tab.dart**: Hauptdatei des Magie-Tabs im HeroWorkspaceScreen, aufgeteilt in Part-Files:
  - `magic_header_section.dart` — Repraesentationen und Merkmalskenntnisse bearbeiten
  - `magic_special_abilities_section.dart` — Magische Sonderfertigkeiten verwalten
  - `magic_active_spells_table.dart` — Tabelle aktivierter Zauber (ZfW, Mod, Steigerung, Katalog-Varianten)
  - `magic_spell_catalog_table.dart` — Katalog-Zauber filtern und aktivieren

### Katalog

- Zauber-Definitionen (`SpellDef`) kommen aus `magie.json` im Katalog.
- `SpellDef` enthaelt neben Grunddaten auch Detailfelder aus `Liber Cantiones` wie `source` (erste Zauberseite), `targetObject`, `wirkung`, `modifications` und `variants`.
- Die importierten Langtexte werden fuer die Laufzeitdarstellung whitespace-normalisiert; PDF-Zeilenumbrueche werden nicht layoutgetreu uebernommen.
- Konstanten `kRepresentationen` und `kMerkmale` in `rules_catalog.dart` definieren die verfuegbaren Repraesentationen und Merkmale.

## Wichtige Hinweise

- Farbmarkierungen (`B4C6E7`, `E7E6E6`) werden nicht allein fuer die Logik genutzt.
- Zellen werden explizit pro Formelbereich gemappt.
