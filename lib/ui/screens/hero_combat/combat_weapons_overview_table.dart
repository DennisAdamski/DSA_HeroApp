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

typedef WeaponSlotUpdater =
    void Function(
      int index,
      MainWeaponSlot Function(MainWeaponSlot current) update,
    );

typedef WeaponFilterChanged =
    void Function({
      String? talentId,
      String? combatType,
      String? weaponType,
      String? distanceClass,
    });

/// Rendert die Waffen-Uebersichtstabelle inklusive Filter und Inline-Feldern.
class CombatWeaponsOverviewTable extends StatelessWidget {
  /// Erstellt die Tabellenkarte fuer Waffenverwaltung.
  const CombatWeaponsOverviewTable({
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

  final List<MainWeaponSlot> weapons;
  final int selectedWeaponIndex;
  final List<TalentDef> combatTalents;
  final RulesCatalog catalog;
  final HeroSheet hero;
  final HeroState heroState;
  final CombatConfig draftCombatConfig;
  final Map<String, HeroTalentEntry> draftTalents;
  final String weaponFilterTalentId;
  final String weaponFilterCombatType;
  final String weaponFilterType;
  final String weaponFilterDistanceClass;
  final void Function(int index) onWeaponEdit;
  final VoidCallback onWeaponAdd;
  final VoidCallback onWeaponCatalog;
  final void Function(int index) onWeaponRemove;
  final WeaponSlotUpdater onWeaponSlotUpdate;
  final WeaponFilterChanged onFilterChanged;

  static const List<AdaptiveTableColumnSpec> _columnSpecs =
      <AdaptiveTableColumnSpec>[
        AdaptiveTableColumnSpec(minWidth: 180, maxWidth: 320, flex: 3), // Name
        AdaptiveTableColumnSpec(minWidth: 110, maxWidth: 180, flex: 1), // Typ
        AdaptiveTableColumnSpec(minWidth: 150, maxWidth: 260, flex: 2), // Waffentalent
        AdaptiveTableColumnSpec(minWidth: 120, maxWidth: 240, flex: 2), // Waffenart
        AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 96),             // DK
        AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 84),             // AT
        AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 84),             // PA
        AdaptiveTableColumnSpec(minWidth: 70, maxWidth: 110),            // TP
        AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 84),             // INI
        AdaptiveTableColumnSpec(minWidth: 68, maxWidth: 92),             // BF
        AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 84),             // eBE
        AdaptiveTableColumnSpec(minWidth: 86, maxWidth: 120),            // Artefakt
        AdaptiveTableColumnSpec(minWidth: 180, maxWidth: 420, flex: 4), // Artefaktbeschreibung
        AdaptiveTableColumnSpec.fixed(72),                               // Aktion
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

  @override
  Widget build(BuildContext context) {
    final sortedTalents = sortedCombatTalents(combatTalents);
    final overviewRows = _buildOverviewRows(
      context,
      sortedTalents: sortedTalents,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Waffen',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      key: const ValueKey<String>('combat-weapon-add'),
                      onPressed: onWeaponAdd,
                      child: const Text('+ Leere Waffe'),
                    ),
                    OutlinedButton(
                      key: const ValueKey<String>('combat-weapon-from-catalog'),
                      onPressed: onWeaponCatalog,
                      child: const Text('+ Katalogwaffe'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                primary: false,
                child: FlexibleTable(
                  tableKey: const ValueKey<String>(
                    'combat-weapons-overview-table',
                  ),
                  columnSpecs: _columnSpecs,
                  headerCells: _buildHeaderCells(),
                  preHeaderRows: [
                    _buildFilterRow(sortedTalents: sortedTalents),
                  ],
                  rows: overviewRows,
                ),
              ),
            ),
            if (overviewRows.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Keine Waffen für den aktuellen Filter vorhanden.'),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildHeaderCells() {
    return <Widget>[
      const Text('Name'),
      for (final header in _headers.skip(1)) Text(header),
    ];
  }

  List<Widget> _buildFilterRow({required List<TalentDef> sortedTalents}) {
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
    final cells = List<Widget>.filled(
      _headers.length,
      const SizedBox.shrink(),
      growable: false,
    );
    cells[1] = DropdownButtonFormField<String>(
      key: const ValueKey<String>('combat-weapons-filter-combat-type'),
      initialValue:
          combatTypeValues.any(
            (value) => weaponCombatTypeToJson(value) == weaponFilterCombatType,
          )
          ? weaponFilterCombatType
          : '',
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
      onChanged: (value) => onFilterChanged(combatType: value ?? ''),
    );
    cells[2] = DropdownButtonFormField<String>(
      key: const ValueKey<String>('combat-weapons-filter-talent'),
      initialValue:
          sortedTalents.any((talent) => talent.id == weaponFilterTalentId)
          ? weaponFilterTalentId
          : '',
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
      onChanged: (value) => onFilterChanged(talentId: value ?? ''),
    );
    cells[3] = DropdownButtonFormField<String>(
      key: const ValueKey<String>('combat-weapons-filter-weapon-type'),
      initialValue: weaponTypeValues.contains(weaponFilterType)
          ? weaponFilterType
          : '',
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
      onChanged: (value) => onFilterChanged(weaponType: value ?? ''),
    );
    cells[4] = DropdownButtonFormField<String>(
      key: const ValueKey<String>('combat-weapons-filter-dk'),
      initialValue: distanceClassValues.contains(weaponFilterDistanceClass)
          ? weaponFilterDistanceClass
          : '',
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
      onChanged: (value) => onFilterChanged(distanceClass: value ?? ''),
    );
    return cells;
  }

  List<FlexibleTableRow> _buildOverviewRows(
    BuildContext context, {
    required List<TalentDef> sortedTalents,
  }) {
    final talentById = <String, TalentDef>{
      for (final talent in sortedTalents) talent.id: talent,
    };
    final ordered = <({int index, MainWeaponSlot slot})>[
      for (var i = 0; i < weapons.length; i++) (index: i, slot: weapons[i]),
    ];
    final visible =
        [
          ...ordered.where((entry) => entry.index == selectedWeaponIndex),
          ...ordered.where((entry) => entry.index != selectedWeaponIndex),
        ].where((entry) {
          final slot = entry.slot;
          if (weaponFilterCombatType.isNotEmpty &&
              weaponCombatTypeToJson(slot.combatType) !=
                  weaponFilterCombatType) {
            return false;
          }
          if (weaponFilterTalentId.isNotEmpty &&
              slot.talentId.trim() != weaponFilterTalentId) {
            return false;
          }
          if (weaponFilterType.isNotEmpty &&
              slot.weaponType.trim() != weaponFilterType) {
            return false;
          }
          if (weaponFilterDistanceClass.isNotEmpty &&
              slot.distanceClass.trim() != weaponFilterDistanceClass) {
            return false;
          }
          return true;
        });

    return visible
        .map((entry) {
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
          return FlexibleTableRow(
            key: ValueKey<String>('combat-weapons-row-${entry.index}'),
            backgroundColor:
                selectedWeaponIndex >= 0 && entry.index == selectedWeaponIndex
                ? Theme.of(context).colorScheme.secondaryContainer
                : null,
            cells: [
              _tappableWeaponNameCell(
                context,
                slot.name,
                onTap: () => onWeaponEdit(entry.index),
              ),
              Text(combatTypeLabel(slot.combatType)),
              DropdownButtonFormField<String>(
                key: ValueKey<String>(
                  'combat-weapon-cell-talent-${entry.index}',
                ),
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
                  final nextTalent = findTalentById(
                    talentOptions,
                    nextTalentId,
                  );
                  final allowedWeaponTypes = weaponTypeOptionsForTalent(
                    talent: nextTalent,
                    catalog: catalog,
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
              Text(
                slot.weaponType.trim().isEmpty ? '-' : slot.weaponType.trim(),
              ),
              Text(
                slot.isRanged
                    ? (slot.rangedProfile.selectedDistanceBand.label
                              .trim()
                              .isEmpty
                          ? '-'
                          : slot.rangedProfile.selectedDistanceBand.label
                                .trim())
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
            ],
          );
        })
        .toList(growable: false);
  }

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
      catalogManeuvers: catalog.maneuvers,
      catalogCombatSpecialAbilities: catalog.combatSpecialAbilities,
    );
  }

  int _effectiveIniRoll() {
    final maxRoll = draftCombatConfig.specialRules.klingentaenzer ? 12 : 6;
    if (draftCombatConfig.specialRules.aufmerksamkeit) {
      return maxRoll;
    }
    final raw = draftCombatConfig.manualMods.iniWurf;
    if (raw < 0) {
      return 0;
    }
    if (raw > maxRoll) {
      return maxRoll;
    }
    return raw;
  }

  Widget _tappableWeaponNameCell(
    BuildContext context,
    String text, {
    required VoidCallback onTap,
  }) {
    final display = text.trim().isEmpty ? '-' : text.trim();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Text(
        display,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
