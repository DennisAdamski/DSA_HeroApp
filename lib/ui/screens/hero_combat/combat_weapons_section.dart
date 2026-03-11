// Waffen-Uebersichtstabelle als eigenstaendiges Widget.
//
// Zeigt alle konfigurierten Waffen-Slots in einer FlexibleTable an,
// inklusive Filtern, Inline-Bearbeitung und Katalog-Zugriff.
import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/combat_helpers.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/adaptive_table_columns.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/flexible_table.dart';

/// Callback-Typ fuer Inline-Aenderungen an einem Waffen-Slot.
typedef WeaponSlotUpdater = void Function(
  int index,
  MainWeaponSlot Function(MainWeaponSlot current) update,
);

/// Callback-Typ fuer Filter-Aenderungen.
typedef WeaponFilterChanged = void Function({
  String? talentId,
  String? combatType,
  String? weaponType,
  String? distanceClass,
});

class CombatWeaponsSection extends StatelessWidget {
  const CombatWeaponsSection({
    super.key,
    required this.weapons,
    required this.selectedWeaponIndex,
    required this.combatTalents,
    required this.catalog,
    required this.hero,
    required this.heroState,
    required this.draftCombatConfig,
    required this.draftTalents,
    required this.weaponFilterTalentId,
    required this.weaponFilterCombatType,
    required this.weaponFilterType,
    required this.weaponFilterDistanceClass,
    required this.onWeaponEdit,
    required this.onWeaponAdd,
    required this.onWeaponCatalog,
    required this.onWeaponRemove,
    required this.onWeaponSlotUpdate,
    required this.onFilterChanged,
  });

  /// Aktuelle Waffenliste (aus Draft-Config).
  final List<MainWeaponSlot> weapons;

  /// Index der aktuell selektierten Waffe (-1 = keine).
  final int selectedWeaponIndex;

  /// Sortierte Kampftalente aus dem Katalog.
  final List<TalentDef> combatTalents;

  /// Der gesamte Regelkatalog.
  final RulesCatalog catalog;

  /// Der aktuelle Held.
  final HeroSheet hero;

  /// Der aktuelle Laufzeit-Zustand des Helden.
  final HeroState heroState;

  /// Die aktuelle Draft-CombatConfig (fuer Preview-Berechnung).
  final CombatConfig draftCombatConfig;

  /// Die aktuellen Draft-Talente (fuer Preview-Berechnung).
  final Map<String, HeroTalentEntry> draftTalents;

  /// Aktuelle Filter-Werte.
  final String weaponFilterTalentId;
  final String weaponFilterCombatType;
  final String weaponFilterType;
  final String weaponFilterDistanceClass;

  /// Callback: Waffen-Editor oeffnen fuer Slot [index].
  final void Function(int index) onWeaponEdit;

  /// Callback: Leere Waffe hinzufuegen.
  final VoidCallback onWeaponAdd;

  /// Callback: Waffe aus Katalog hinzufuegen.
  final VoidCallback onWeaponCatalog;

  /// Callback: Waffe an [index] entfernen.
  final void Function(int index) onWeaponRemove;

  /// Callback: Inline-Update an einem Waffen-Slot.
  final WeaponSlotUpdater onWeaponSlotUpdate;

  /// Callback: Filter-Werte geaendert.
  final WeaponFilterChanged onFilterChanged;

  // ---------------------------------------------------------------------------
  // Konstanten
  // ---------------------------------------------------------------------------

  static const List<AdaptiveTableColumnSpec> _columnSpecs =
      <AdaptiveTableColumnSpec>[
    AdaptiveTableColumnSpec(minWidth: 180, maxWidth: 300, flex: 3),
    AdaptiveTableColumnSpec(minWidth: 100, maxWidth: 180, flex: 2),
    AdaptiveTableColumnSpec(minWidth: 140, maxWidth: 260, flex: 2),
    AdaptiveTableColumnSpec(minWidth: 110, maxWidth: 220, flex: 2),
    AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 96),
    AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 84),
    AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 84),
    AdaptiveTableColumnSpec(minWidth: 70, maxWidth: 110),
    AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 84),
    AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 84),
    AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 84),
    AdaptiveTableColumnSpec(minWidth: 86, maxWidth: 120),
    AdaptiveTableColumnSpec(minWidth: 150, maxWidth: 320, flex: 3),
    AdaptiveTableColumnSpec.fixed(56),
  ];

  static const List<String> _headers = <String>[
    'Name',
    'Typ',
    'Waffentalent',
    'Waffenart',
    'DK',
    'AT',
    'PA',
    'TP',
    'INI',
    'BF',
    'eBE',
    'Artefakt',
    'Artefaktbeschreibung',
    'Aktion',
  ];

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final sortedTalents = sortedCombatTalents(combatTalents);
    final overviewRows = _buildOverviewRows(
      context,
      sortedTalents: sortedTalents,
    );
    final hasVisibleRows = overviewRows.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Waffen', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            FlexibleTable(
              tableKey: const ValueKey<String>(
                'combat-weapons-overview-table',
              ),
              columnSpecs: _columnSpecs,
              headerCells: _buildHeaderCells(sortedTalents),
              preHeaderRows: [
                _buildFilterRow(sortedTalents: sortedTalents),
              ],
              rows: overviewRows,
            ),
            if (!hasVisibleRows)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Keine Waffen für den aktuellen Filter vorhanden.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header-Zeile
  // ---------------------------------------------------------------------------

  List<Widget> _buildHeaderCells(List<TalentDef> sortedTalents) {
    final cells = <Widget>[
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Name'),
          IconButton(
            key: const ValueKey<String>('combat-weapon-add'),
            tooltip: 'Leere Waffe hinzufuegen',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            onPressed: onWeaponAdd,
            icon: const Icon(Icons.add, size: 18),
          ),
          IconButton(
            key: const ValueKey<String>('combat-weapon-from-catalog'),
            tooltip: 'Waffe aus Katalog hinzufuegen',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            onPressed: onWeaponCatalog,
            icon: const Icon(Icons.library_add, size: 18),
          ),
        ],
      ),
      for (final header in _headers.skip(1)) Text(header),
    ];
    return cells;
  }

  // ---------------------------------------------------------------------------
  // Filter-Zeile
  // ---------------------------------------------------------------------------

  List<Widget> _buildFilterRow({
    required List<TalentDef> sortedTalents,
  }) {
    final combatTypeValues = weapons
        .map((slot) => slot.combatType)
        .toSet()
        .toList(growable: false);
    final weaponTypeValues =
        weapons
            .map((slot) => slot.weaponType.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final distanceClassValues =
        weapons
            .map((slot) => slot.distanceClass.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final filteredTalentValue =
        sortedTalents.any((talent) => talent.id == weaponFilterTalentId)
        ? weaponFilterTalentId
        : '';
    final filteredCombatTypeValue =
        combatTypeValues.any(
          (value) => weaponCombatTypeToJson(value) == weaponFilterCombatType,
        )
        ? weaponFilterCombatType
        : '';
    final filteredTypeValue = weaponTypeValues.contains(weaponFilterType)
        ? weaponFilterType
        : '';
    final filteredDkValue =
        distanceClassValues.contains(weaponFilterDistanceClass)
        ? weaponFilterDistanceClass
        : '';
    final cells = List<Widget>.filled(
      _headers.length,
      const SizedBox.shrink(),
      growable: false,
    );
    cells[1] = DropdownButtonFormField<String>(
      key: const ValueKey<String>('combat-weapons-filter-combat-type'),
      initialValue: filteredCombatTypeValue,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Filter Typ',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem<String>(value: '', child: Text('Alle')),
        ...combatTypeValues.map(
          (ct) => DropdownMenuItem<String>(
            value: weaponCombatTypeToJson(ct),
            child: Text(combatTypeLabel(ct)),
          ),
        ),
      ],
      onChanged: (value) {
        onFilterChanged(combatType: value ?? '');
      },
    );
    cells[2] = DropdownButtonFormField<String>(
      key: const ValueKey<String>('combat-weapons-filter-talent'),
      initialValue: filteredTalentValue,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Filter Talent',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem<String>(value: '', child: Text('Alle')),
        ...sortedTalents.map(
          (talent) => DropdownMenuItem<String>(
            value: talent.id,
            child: Text(
              talent.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: (value) {
        onFilterChanged(talentId: value ?? '');
      },
    );
    cells[3] = DropdownButtonFormField<String>(
      key: const ValueKey<String>('combat-weapons-filter-weapon-type'),
      initialValue: filteredTypeValue,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Filter Waffenart',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem<String>(value: '', child: Text('Alle')),
        ...weaponTypeValues.map(
          (weaponType) => DropdownMenuItem<String>(
            value: weaponType,
            child: Text(
              weaponType,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: (value) {
        onFilterChanged(weaponType: value ?? '');
      },
    );
    cells[4] = DropdownButtonFormField<String>(
      key: const ValueKey<String>('combat-weapons-filter-dk'),
      initialValue: filteredDkValue,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Filter DK',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem<String>(value: '', child: Text('Alle')),
        ...distanceClassValues.map(
          (distanceClass) => DropdownMenuItem<String>(
            value: distanceClass,
            child: Text(
              distanceClass,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: (value) {
        onFilterChanged(distanceClass: value ?? '');
      },
    );
    return cells;
  }

  // ---------------------------------------------------------------------------
  // Uebersichts-Zeilen
  // ---------------------------------------------------------------------------

  List<FlexibleTableRow> _buildOverviewRows(
    BuildContext context, {
    required List<TalentDef> sortedTalents,
  }) {
    final talentById = <String, TalentDef>{
      for (final talent in sortedTalents) talent.id: talent,
    };
    final availableTypes = weapons
        .map((slot) => slot.weaponType.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final availableCombatTypes = weapons
        .map((slot) => weaponCombatTypeToJson(slot.combatType))
        .toSet();
    final availableDistanceClasses = weapons
        .map((slot) => slot.distanceClass.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final activeTalentFilter =
        sortedTalents.any((talent) => talent.id == weaponFilterTalentId)
        ? weaponFilterTalentId
        : '';
    final activeCombatTypeFilter =
        availableCombatTypes.contains(weaponFilterCombatType)
        ? weaponFilterCombatType
        : '';
    final activeTypeFilter = availableTypes.contains(weaponFilterType)
        ? weaponFilterType
        : '';
    final activeDistanceClassFilter =
        availableDistanceClasses.contains(weaponFilterDistanceClass)
        ? weaponFilterDistanceClass
        : '';
    final indexed = <({int index, MainWeaponSlot slot})>[
      for (var i = 0; i < weapons.length; i++)
        (index: i, slot: weapons[i]),
    ];
    final ordered = <({int index, MainWeaponSlot slot})>[
      ...indexed.where((entry) => entry.index == selectedWeaponIndex),
      ...indexed.where((entry) => entry.index != selectedWeaponIndex),
    ];
    final filtered = ordered
        .where((entry) {
          final slot = entry.slot;
          if (activeCombatTypeFilter.isNotEmpty &&
              weaponCombatTypeToJson(slot.combatType) !=
                  activeCombatTypeFilter) {
            return false;
          }
          if (activeTalentFilter.isNotEmpty &&
              slot.talentId.trim() != activeTalentFilter) {
            return false;
          }
          if (activeTypeFilter.isNotEmpty &&
              slot.weaponType.trim() != activeTypeFilter) {
            return false;
          }
          if (activeDistanceClassFilter.isNotEmpty &&
              slot.distanceClass.trim() != activeDistanceClassFilter) {
            return false;
          }
          return true;
        })
        .toList(growable: false);

    return filtered
        .map((entry) => _buildOverviewRow(
              context,
              entry: entry,
              sortedTalents: sortedTalents,
              talentById: talentById,
            ))
        .toList(growable: false);
  }

  FlexibleTableRow _buildOverviewRow(
    BuildContext context, {
    required ({int index, MainWeaponSlot slot}) entry,
    required List<TalentDef> sortedTalents,
    required Map<String, TalentDef> talentById,
  }) {
    final slot = entry.slot;
    final talentOptions = sortedCombatTalentsForType(
      sortedTalents,
      slot.combatType,
    );
    final preview = _previewForSlot(entry.index, slot);
    final artifactDescription = slot.isArtifact
        ? (slot.artifactDescription.trim().isEmpty
              ? '-'
              : slot.artifactDescription.trim())
        : '-';
    final cells = <Widget>[
      _tappableWeaponNameCell(
        context,
        slot.name,
        onTap: () => onWeaponEdit(entry.index),
      ),
      Text(combatTypeLabel(slot.combatType)),
      DropdownButtonFormField<String>(
        key: ValueKey<String>('combat-weapon-cell-talent-${entry.index}'),
        initialValue:
            talentById.containsKey(slot.talentId.trim()) &&
                talentOptions.any(
                  (talent) => talent.id == slot.talentId.trim(),
                )
            ? slot.talentId.trim()
            : '',
        isExpanded: true,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          const DropdownMenuItem<String>(value: '', child: Text('-')),
          ...talentOptions.map(
            (talent) => DropdownMenuItem<String>(
              value: talent.id,
              child: Text(
                talent.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
        onChanged: (value) {
          final nextTalentId = value ?? '';
          final nextTalent = findTalentById(talentOptions, nextTalentId);
          final allowedWeaponTypes = _weaponTypeOptionsForTalent(
            talent: nextTalent,
            combatType: slot.combatType,
          );
          final nextWeaponType =
              allowedWeaponTypes.contains(slot.weaponType.trim())
              ? slot.weaponType.trim()
              : '';
          final nextName =
              slot.name.trim().isEmpty && nextWeaponType.isNotEmpty
              ? nextWeaponType
              : slot.name;
          onWeaponSlotUpdate(
            entry.index,
            (current) => current.copyWith(
              talentId: nextTalentId,
              weaponType: nextWeaponType,
              name: nextName,
            ),
          );
        },
      ),
      Text(slot.weaponType.trim().isEmpty ? '-' : slot.weaponType.trim()),
      Text(
        slot.isRanged
            ? (slot.rangedProfile.selectedDistanceBand.label
                      .trim()
                      .isEmpty
                  ? '-'
                  : slot.rangedProfile.selectedDistanceBand.label.trim())
            : (slot.distanceClass.trim().isEmpty
                  ? '-'
                  : slot.distanceClass.trim()),
      ),
      Text(preview.at.toString()),
      Text(slot.isRanged ? '-' : preview.pa.toString()),
      Text(preview.tpExpression),
      Text(
        preview.kombinierteHeldenWaffenIni.toString(),
        key: ValueKey<String>('combat-weapon-cell-ini-${entry.index}'),
      ),
      FlexibleTableCommitField(
        key: ValueKey<String>('combat-weapon-cell-bf-${entry.index}'),
        value: slot.breakFactor.toString(),
        keyboardType: TextInputType.number,
        onCommit: (raw) {
          final parsed = int.tryParse(raw.trim()) ?? slot.breakFactor;
          onWeaponSlotUpdate(
            entry.index,
            (current) =>
                current.copyWith(breakFactor: parsed < 0 ? 0 : parsed),
          );
        },
      ),
      Text(preview.ebe.toString()),
      Text(slot.isArtifact ? 'Ja' : 'Nein'),
      Text(
        artifactDescription,
        key: ValueKey<String>(
          'combat-weapon-cell-artifact-description-${entry.index}',
        ),
      ),
      IconButton(
        key: ValueKey<String>('combat-weapon-remove-${entry.index}'),
        tooltip: 'Waffe entfernen',
        onPressed: weapons.length <= 1
            ? null
            : () => onWeaponRemove(entry.index),
        icon: const Icon(Icons.delete),
      ),
    ];

    final isSelected =
        selectedWeaponIndex >= 0 && entry.index == selectedWeaponIndex;
    return FlexibleTableRow(
      key: ValueKey<String>('combat-weapons-row-${entry.index}'),
      backgroundColor: isSelected
          ? Theme.of(context).colorScheme.secondaryContainer
          : null,
      cells: cells,
    );
  }

  // ---------------------------------------------------------------------------
  // Preview-Berechnung
  // ---------------------------------------------------------------------------

  CombatPreviewStats _previewForSlot(int slotIndex, MainWeaponSlot slot) {
    return computeCombatPreviewStats(
      hero,
      heroState,
      overrideConfig: draftCombatConfig.copyWith(
        selectedWeaponIndex: slotIndex,
        mainWeapon: slot,
        manualMods: draftCombatConfig.manualMods.copyWith(
          iniWurf: _effectiveIniRoll(),
        ),
      ),
      overrideTalents: draftTalents,
      catalogTalents: catalog.talents,
    );
  }

  int _effectiveIniRoll() {
    final maxRoll = draftCombatConfig.specialRules.klingentaenzer ? 12 : 6;
    if (draftCombatConfig.specialRules.aufmerksamkeit) {
      return maxRoll;
    }
    final raw = draftCombatConfig.manualMods.iniWurf;
    if (raw < 0) return 0;
    if (raw > maxRoll) return maxRoll;
    return raw;
  }

  // ---------------------------------------------------------------------------
  // Helfer
  // ---------------------------------------------------------------------------

  Widget _tappableWeaponNameCell(
    BuildContext context,
    String text, {
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final display = text.trim().isEmpty ? '-' : text.trim();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Text(
        display,
        style: TextStyle(
          color: theme.colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  List<String> _weaponTypeOptionsForTalent({
    required TalentDef? talent,
    required WeaponCombatType combatType,
  }) {
    return weaponTypeOptionsForTalent(
      talent: talent,
      catalog: catalog,
      combatType: combatType,
    );
  }
}
