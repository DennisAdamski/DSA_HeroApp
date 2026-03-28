# Talente Such-Header Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Einen Such-Header oberhalb der Talentgruppen einführen, der live nach Gruppenname filtert und die Buttons „+ Talent" / „+ Meta-Talent" enthält; Aktionsleiste auf Bearbeiten + Settings-Icon reduzieren; globale Header-Actions für Talente entfernen.

**Architecture:** Suchzustand (`TextEditingController` + `String _talentGroupFilter`) liegt in `_HeroTalentTableTabState`. Die neue `_buildSearchHeader`-Methode sitzt in der bestehenden Extension `_HeroTalentsInfoCard` (hero_talents_info_card.dart). Die Filterung der Gruppenzeilen passiert direkt im `build()` von `hero_talents_tab.dart` vor dem `.map()`.

**Tech Stack:** Flutter, Dart, flutter_riverpod, part files

---

## Betroffene Dateien

| Datei | Art |
|---|---|
| `lib/ui/screens/hero_talents_tab.dart` | Modify — Suchzustand, initState/dispose, headerActions bereinigen, build() anpassen |
| `lib/ui/screens/hero_talents/hero_talents_info_card.dart` | Modify — `_buildTopActionBar` reduzieren, `_buildSearchHeader` hinzufügen |

---

## Task 1: Globale Header-Actions entfernen

**Files:**
- Modify: `lib/ui/screens/hero_talents_tab.dart:159-199`

- [ ] **Schritt 1: `_registerWithParent` anpassen**

  In `hero_talents_tab.dart`, Methode `_registerWithParent()` (Zeilen 159–199).
  Die gesamte `headerActions:`-Liste für `_TalentTabScope.nonCombat` (beide `WorkspaceHeaderAction`-Blöcke) entfernen. Nach der Änderung liefert `headerActions` **immer** eine leere Liste:

  ```dart
  void _registerWithParent() {
    _editController.emitCurrentState();
    widget.onRegisterDiscard(_discardChanges);
    widget.onRegisterEditActions(
      WorkspaceTabEditActions(
        startEdit: _startEdit,
        save: _saveChanges,
        cancel: _cancelChanges,
        headerActions: const <WorkspaceHeaderAction>[],
      ),
    );
  }
  ```

- [ ] **Schritt 2: `flutter analyze` prüfen**

  ```bash
  flutter analyze lib/ui/screens/hero_talents_tab.dart
  ```
  Erwartetes Ergebnis: keine neuen Fehler/Warnungen.

---

## Task 2: `_buildTopActionBar` vereinfachen

**Files:**
- Modify: `lib/ui/screens/hero_talents/hero_talents_info_card.dart:4-61`
- Modify: `lib/ui/screens/hero_talents_tab.dart:574-583` (Aufrufstelle)

- [ ] **Schritt 1: Methode `_buildTopActionBar` ersetzen**

  In `hero_talents_info_card.dart` die gesamte Methode `_buildTopActionBar` (Zeilen 4–61) durch folgende Version ersetzen. Nur noch zwei Elemente: `Bearbeiten`-Button + Settings-`IconButton` für BE-Konfiguration. Parameter `allTalents` und `allCatalogTalents` entfallen.

  ```dart
  Widget _buildTopActionBar({
    required String heroId,
    required int combatBaseBe,
    required int activeTalentBe,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            FilledButton.icon(
              key: const ValueKey<String>('talents-local-start-edit'),
              onPressed: _editController.isEditing
                  ? null
                  : () {
                      _startEdit();
                    },
              icon: const Icon(Icons.edit),
              label: const Text('Bearbeiten'),
            ),
            const SizedBox(width: 4),
            IconButton(
              key: const ValueKey<String>('talents-be-screen-open'),
              onPressed: () => _openTalentBeScreen(
                heroId: heroId,
                combatBaseBe: combatBaseBe,
              ),
              icon: const Icon(Icons.settings),
              tooltip: 'BE konfigurieren ($activeTalentBe)',
            ),
          ],
        ),
      ),
    );
  }
  ```

- [ ] **Schritt 2: Aufrufstelle in `hero_talents_tab.dart` anpassen**

  Die Aufrufstelle (Zeilen 574–582 im aktuellen Stand, `_buildTopActionBar(…)`) ohne die nicht mehr vorhandenen Parameter aufrufen:

  ```dart
  if (widget.scope == _TalentTabScope.nonCombat &&
      widget.showInlineActions)
    _buildTopActionBar(
      heroId: hero.id,
      combatBaseBe: combatBaseBe ?? 0,
      activeTalentBe: activeTalentBe,
    ),
  ```

- [ ] **Schritt 3: `flutter analyze` prüfen**

  ```bash
  flutter analyze lib/ui/screens/hero_talents_tab.dart lib/ui/screens/hero_talents/hero_talents_info_card.dart
  ```
  Erwartetes Ergebnis: keine Fehler.

---

## Task 3: Suchzustand in den State einbauen

**Files:**
- Modify: `lib/ui/screens/hero_talents_tab.dart`

- [ ] **Schritt 1: State-Felder ergänzen**

  In `_HeroTalentTableTabState` direkt nach `final ValueNotifier<int> _tableRevision = ValueNotifier<int>(0);` (Zeile 107) zwei neue Felder einfügen:

  ```dart
  final TextEditingController _searchController = TextEditingController();
  String _talentGroupFilter = '';
  ```

- [ ] **Schritt 2: Listener in `initState` registrieren**

  In `initState()` direkt nach `super.initState();` hinzufügen:

  ```dart
  _searchController.addListener(() {
    if (mounted) {
      setState(() {
        _talentGroupFilter = _searchController.text;
      });
    }
  });
  ```

- [ ] **Schritt 3: Controller in `dispose` freigeben**

  In `dispose()` vor dem `super.dispose();` ergänzen:

  ```dart
  _searchController.dispose();
  ```

- [ ] **Schritt 4: `flutter analyze` prüfen**

  ```bash
  flutter analyze lib/ui/screens/hero_talents_tab.dart
  ```
  Erwartetes Ergebnis: keine Fehler.

---

## Task 4: `_buildSearchHeader`-Methode hinzufügen

**Files:**
- Modify: `lib/ui/screens/hero_talents/hero_talents_info_card.dart`

- [ ] **Schritt 1: Methode am Ende der Extension `_HeroTalentsInfoCard` einfügen**

  Direkt vor der schließenden `}` der Extension (nach `_showTalentSpecialAbilityDialog`) folgende Methode einfügen:

  ```dart
  Widget _buildSearchHeader({
    required List<TalentDef> allTalents,
    required List<TalentDef> allCatalogTalents,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey<String>('talents-group-search'),
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Talentgruppen durchsuchen\u2026',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _talentGroupFilter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Suche löschen',
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            key: const ValueKey<String>('talents-catalog-open'),
            onPressed: () => _openTalentCatalogAction(allTalents),
            icon: const Icon(Icons.library_add),
            label: const Text('+ Talent'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            key: const ValueKey<String>('meta-talents-manage-open'),
            onPressed: () => _openMetaTalentManagerAction(allCatalogTalents),
            icon: const Icon(Icons.merge_type),
            label: const Text('+ Meta-Talent'),
          ),
        ],
      ),
    );
  }
  ```

  Hinweis: `\u2026` ist das Unicode-Auslassungszeichen `…` (Ellipsis), um ASCII-Umgehung zu vermeiden.

- [ ] **Schritt 2: `flutter analyze` prüfen**

  ```bash
  flutter analyze lib/ui/screens/hero_talents/hero_talents_info_card.dart
  ```
  Erwartetes Ergebnis: keine Fehler.

---

## Task 5: Such-Header in `build()` einbinden und Filter anwenden

**Files:**
- Modify: `lib/ui/screens/hero_talents_tab.dart:538-703`

- [ ] **Schritt 1: Such-Header in die `ListView.children` einbauen**

  Im `build()`, innerhalb des `ValueListenableBuilder`, in der `ListView`-`children`-Liste: direkt **nach** dem `TabBar`-Block und **vor** dem `if (widget.scope == _TalentTabScope.nonCombat && _subTabController!.index == 1)` den Such-Header einfügen.

  Aktuelle Reihenfolge (vereinfacht):
  ```dart
  if (widget.scope == _TalentTabScope.nonCombat)
    TabBar(...),
  if (widget.scope == _TalentTabScope.nonCombat && _subTabController!.index == 1)
    _buildSpecialAbilitiesTab(),
  ```

  Nach der Änderung:
  ```dart
  if (widget.scope == _TalentTabScope.nonCombat)
    TabBar(...),
  if (widget.scope == _TalentTabScope.nonCombat &&
      _subTabController?.index == 0)
    _buildSearchHeader(
      allTalents: relevantTalents,
      allCatalogTalents: catalog.talents,
    ),
  if (widget.scope == _TalentTabScope.nonCombat && _subTabController!.index == 1)
    _buildSpecialAbilitiesTab(),
  ```

- [ ] **Schritt 2: Gruppen-Filterliste vor dem `.map()` berechnen**

  Im selben `build()`, direkt **vor** dem `...groups.map((group) {` (aktuell Zeile ~655), die gefilterte Gruppen-Variable berechnen:

  ```dart
  final filterQuery = _talentGroupFilter.trim().toLowerCase();
  final filteredGroups = filterQuery.isEmpty
      ? groups
      : groups
            .where((g) => g.toLowerCase().contains(filterQuery))
            .toList(growable: false);
  ```

- [ ] **Schritt 3: `.map()` auf `filteredGroups` umstellen**

  Die Zeile `...groups.map((group) {` ersetzen durch:

  ```dart
  ...filteredGroups.map((group) {
  ```

- [ ] **Schritt 4: Meta-Talente-Abschnitt filtern**

  Der Meta-Talente-Block (aktuell Zeilen ~687–695):
  ```dart
  if (widget.scope == _TalentTabScope.nonCombat &&
      (_subTabController?.index == 0) &&
      _draftMetaTalents.isNotEmpty)
    _buildMetaTalentsCard(...),
  ```

  Filterquery-Bedingung ergänzen:

  ```dart
  if (widget.scope == _TalentTabScope.nonCombat &&
      (_subTabController?.index == 0) &&
      _draftMetaTalents.isNotEmpty &&
      (filterQuery.isEmpty ||
          'meta-talente'.contains(filterQuery)))
    _buildMetaTalentsCard(
      metaTalents: _draftMetaTalents,
      catalogTalents: catalog.talents,
      effectiveAttributes: effectiveAttributes!,
      activeBaseBe: activeTalentBe,
    ),
  ```

  Hinweis: `filterQuery` ist in Scope, da wir es in Schritt 2 desselben Builders definieren.

- [ ] **Schritt 5: `flutter analyze` + alle Tests**

  ```bash
  flutter analyze
  flutter test
  ```
  Erwartetes Ergebnis: keine Fehler, alle Tests grün.

---

## Task 6: LOC-Budget prüfen und committen

**Files:** keine Änderungen

- [ ] **Schritt 1: LOC-Budget prüfen**

  ```bash
  python tool/check_screen_loc_budget.py --max-lines 700
  ```
  Hinweis: `hero_talents_tab.dart` lag vor diesen Änderungen bereits bei 708 Zeilen. Task 1 entfernt ~18 Zeilen (die zwei `WorkspaceHeaderAction`-Blöcke); Task 2 entfernt ~14 Zeilen; Task 3 und 5 fügen ~12 Zeilen hinzu. Netto: ~706 → ~686 Zeilen, was unter dem Budget liegt.

- [ ] **Schritt 2: Commit**

  ```bash
  git add lib/ui/screens/hero_talents_tab.dart \
          lib/ui/screens/hero_talents/hero_talents_info_card.dart
  git commit -m "talente: Such-Header mit Gruppenfilter und +Talent/+Meta-Talent-Buttons"
  ```

---

## Verifikation (manuell)

1. App starten, Held öffnen → Talente-Tab öffnen
2. Über den Talentgruppen erscheint eine Suchzeile mit Suchfeld, „+ Talent"- und „+ Meta-Talent"-Buttons
3. Suchbegriff „Wissen" eingeben → nur „Wissenstalente"-Gruppe sichtbar, alle anderen ausgeblendet
4. Suchfeld leeren (X-Button) → alle Gruppen wieder sichtbar
5. „+ Talent" öffnet Katalog-Dialog; „+ Meta-Talent" öffnet Manager-Dialog
6. Aktionsleiste zeigt nur „Bearbeiten"-Button und Settings-Icon; Settings-Icon öffnet BE-Konfigurations-Dialog
7. Globaler AppBar-Header zeigt für Talente-Tab keine library_add/merge_type-Icons mehr
