# Design: Talente-Tab Such-Header & Button-Umzug

**Datum:** 2026-03-28
**Status:** Genehmigt

---

## Kontext

Der Talente-Tab hat derzeit Buttons zum Verwalten von Talenten und Meta-Talenten sowohl im globalen AppBar-Header als auch in der lokalen Aktionsleiste. Das ist redundant. Außerdem fehlt eine Möglichkeit, Talentgruppen schnell zu filtern. Ziel: einen dedizierten Such-Header direkt oberhalb der Talentgruppen einführen, der Suche und die beiden Verwaltungs-Buttons an einem logischen Ort bündelt.

---

## Änderungen im Überblick

### 1. Neuer Such-Header (neu)

Eine neue Widget-Zeile wird **zwischen der lokalen Aktionsleiste und der ersten Talentgruppe** eingefügt. Sie enthält:

- **Suchfeld** (live, `TextEditingController`): Filtert Talentgruppen nach Gruppenname (case-insensitive substring match). Leeres Feld = alle Gruppen sichtbar.
- **`+ Talent`-Button** (`FilledButton.icon`, Icons.library_add): Öffnet den bestehenden Talent-Katalog-Dialog (`_openTalentCatalogAction`).
- **`+ Meta-Talent`-Button** (`FilledButton.icon`, Icons.merge_type): Öffnet den bestehenden Meta-Talent-Manager (`_openMetaTalentManagerAction`).

Button-Konvention: `FilledButton.icon`, Beschriftung `+ <Singular>` gemäß AGENTS.md.
Der Such-Header ist **nur für `_TalentTabScope.nonCombat`** sichtbar (Kampftalente und Sprachen bekommen ihn nicht).

### 2. Lokale Aktionsleiste (`_buildTopActionBar`, hero_talents_info_card.dart)

- **Bleibt:** `Bearbeiten`-Button (FilledButton)
- **Neu:** `BE konfigurieren` wird zu einem **Settings-IconButton** (`Icons.settings`, Tooltip: `BE konfigurieren`)
- **Entfernt:** `Talente verwalten`-Button
- **Entfernt:** `Meta-Talente verwalten`-Button

### 3. Globaler Header-Aktionen (`hero_talents_tab.dart`, `headerActions`)

- **Entfernt:** WorkspaceHeaderAction für `library_add` (Talente verwalten)
- **Entfernt:** WorkspaceHeaderAction für `merge_type` (Meta-Talente verwalten)

---

## Suchlogik

- State: `String _talentGroupFilter = ''` in `_HeroTalentTableTabState`
- `TextEditingController _searchController` mit `dispose()`
- Beim Build: Talentgruppen-Liste wird gefiltert — Gruppen, deren Anzeigename den Suchbegriff **nicht** enthält (case-insensitive), werden übersprungen
- Meta-Talente-Abschnitt ist ebenfalls filterbar (Gruppenname: `'Meta-Talente'`)
- Die `_searchController`-Werte triggern `setState` via `addListener`

---

## Betroffene Dateien

| Datei | Änderung |
|---|---|
| `lib/ui/screens/hero_talents_tab.dart` | Suchzustand, Filter-Logik, Such-Header in build() einbauen; headerActions bereinigen |
| `lib/ui/screens/hero_talents/hero_talents_info_card.dart` | `_buildTopActionBar` reduzieren: nur Bearbeiten + Settings-Icon |

---

## Verifikation

1. `flutter analyze` — keine neuen Warnungen
2. `flutter test` — alle bestehenden Tests grün
3. Manuell: Suchfeld eintippen → nur passende Gruppen sichtbar, andere ausgeblendet
4. Manuell: `+ Talent` öffnet Katalog-Dialog, `+ Meta-Talent` öffnet Manager
5. Manuell: Settings-Icon in Aktionsleiste öffnet BE-Konfigurations-Dialog
6. Manuell: Globaler Header zeigt für Talente-Tab keine Talente/Meta-Talente-Icons mehr
