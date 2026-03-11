// Nebenhand-Ausruestungstabelle als eigenstaendiges Widget.
//
// Zeigt Parierwaffen und Schilde in einer FlexibleTable an
// und bietet einen Inline-Editor-Dialog fuer neue/bestehende Eintraege.
import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/combat_helpers.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/adaptive_table_columns.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/flexible_table.dart';

class CombatOffhandSection extends StatelessWidget {
  const CombatOffhandSection({
    super.key,
    required this.offhandEquipment,
    required this.onOffhandEquipmentChanged,
  });

  /// Aktuelle Nebenhand-Ausruestungsliste.
  final List<OffhandEquipmentEntry> offhandEquipment;

  /// Callback: gesamte Liste wurde geaendert (hinzufuegen/bearbeiten/entfernen).
  final void Function(List<OffhandEquipmentEntry>) onOffhandEquipmentChanged;

  // ---------------------------------------------------------------------------
  // Konstanten
  // ---------------------------------------------------------------------------

  static const List<AdaptiveTableColumnSpec> _columnSpecs =
      <AdaptiveTableColumnSpec>[
    AdaptiveTableColumnSpec(minWidth: 150, maxWidth: 260, flex: 2),
    AdaptiveTableColumnSpec(minWidth: 110, maxWidth: 180, flex: 1),
    AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 84),
    AdaptiveTableColumnSpec(minWidth: 90, maxWidth: 150, flex: 1),
    AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 84),
    AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 84),
    AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 84),
    AdaptiveTableColumnSpec.fixed(56),
  ];

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final rows = <FlexibleTableRow>[
      for (var i = 0; i < offhandEquipment.length; i++)
        FlexibleTableRow(
          cells: [
            _tappableNameCell(
              context,
              offhandEquipment[i].name.trim().isEmpty
                  ? 'Eintrag ${i + 1}'
                  : offhandEquipment[i].name,
              onTap: () => _openEditor(context, entryIndex: i),
            ),
            Text(offhandEquipment[i].isShield ? 'Schild' : 'Parierwaffe'),
            Text(offhandEquipment[i].breakFactor.toString()),
            Text(
              offhandEquipment[i].isShield
                  ? shieldSizeLabel(offhandEquipment[i].shieldSize)
                  : '-',
            ),
            Text(offhandEquipment[i].iniMod.toString()),
            Text(offhandEquipment[i].atMod.toString()),
            Text(offhandEquipment[i].paMod.toString()),
            IconButton(
              key: ValueKey<String>('combat-offhand-remove-$i'),
              tooltip: 'Nebenhand-Ausrüstung entfernen',
              onPressed: () => _removeEntry(i),
              icon: const Icon(Icons.delete),
            ),
          ],
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Parierwaffen & Schilde',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            FlexibleTable(
              tableKey: const ValueKey<String>('combat-offhand-table'),
              columnSpecs: _columnSpecs,
              headerCells: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Name'),
                    IconButton(
                      key: const ValueKey<String>('combat-offhand-add'),
                      tooltip: 'Nebenhand-Ausrüstung hinzufügen',
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 30,
                        height: 30,
                      ),
                      onPressed: () => _openEditor(context),
                      icon: const Icon(Icons.add, size: 18),
                    ),
                  ],
                ),
                const Text('Typ'),
                const Text('BF'),
                const Text('Groesse'),
                const Text('INI Mod'),
                const Text('AT Mod'),
                const Text('PA Mod'),
                const Text('Aktion'),
              ],
              rows: rows,
            ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Keine Parierwaffen oder Schilde erfasst.'),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Aktionen
  // ---------------------------------------------------------------------------

  void _removeEntry(int index) {
    final entries = List<OffhandEquipmentEntry>.from(offhandEquipment);
    if (index < 0 || index >= entries.length) {
      return;
    }
    entries.removeAt(index);
    onOffhandEquipmentChanged(entries);
  }

  Future<void> _openEditor(
    BuildContext context, {
    int? entryIndex,
  }) async {
    final isNew = entryIndex == null;
    final source = isNew
        ? const OffhandEquipmentEntry()
        : offhandEquipment[entryIndex];
    final nameController = TextEditingController(text: source.name);
    final bfController = TextEditingController(
      text: source.breakFactor.toString(),
    );
    final iniController = TextEditingController(text: source.iniMod.toString());
    final atController = TextEditingController(text: source.atMod.toString());
    final paController = TextEditingController(text: source.paMod.toString());
    var type = source.type;
    var shieldSize = source.shieldSize;

    final result = await showDialog<OffhandEquipmentEntry>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(
                isNew
                    ? 'Nebenhand-Ausrüstung hinzufügen'
                    : 'Nebenhand-Ausrüstung bearbeiten',
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        key: const ValueKey<String>(
                          'combat-offhand-form-name',
                        ),
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Ausrüstungsname',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<OffhandEquipmentType>(
                        key: const ValueKey<String>(
                          'combat-offhand-form-type',
                        ),
                        initialValue: type,
                        decoration: const InputDecoration(
                          labelText: 'Waffentalent',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: OffhandEquipmentType.parryWeapon,
                            child: Text('Parierwaffe'),
                          ),
                          DropdownMenuItem(
                            value: OffhandEquipmentType.shield,
                            child: Text('Schild'),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            type = value ?? OffhandEquipmentType.parryWeapon;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _numberField(
                            controller: bfController,
                            keyName: 'combat-offhand-form-bf',
                            label: 'BF',
                          ),
                          _numberField(
                            controller: iniController,
                            keyName: 'combat-offhand-form-ini-mod',
                            label: 'INI Mod',
                          ),
                          _numberField(
                            controller: atController,
                            keyName: 'combat-offhand-form-at-mod',
                            label: 'AT Mod',
                          ),
                          _numberField(
                            controller: paController,
                            keyName: 'combat-offhand-form-pa-mod',
                            label: 'PA Mod',
                          ),
                        ],
                      ),
                      if (type == OffhandEquipmentType.shield) ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<ShieldSize>(
                          key: const ValueKey<String>(
                            'combat-offhand-form-shield-size',
                          ),
                          initialValue: shieldSize,
                          decoration: const InputDecoration(
                            labelText: 'Größe',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: ShieldSize.small,
                              child: Text('Klein'),
                            ),
                            DropdownMenuItem(
                              value: ShieldSize.large,
                              child: Text('Groß'),
                            ),
                            DropdownMenuItem(
                              value: ShieldSize.veryLarge,
                              child: Text('Sehr groß'),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              shieldSize = value ?? ShieldSize.small;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  key: const ValueKey<String>('combat-offhand-form-save'),
                  onPressed: () {
                    final parsedBreakFactor =
                        int.tryParse(bfController.text.trim()) ?? 0;
                    final parsedIni =
                        int.tryParse(iniController.text.trim()) ?? 0;
                    final parsedAt =
                        int.tryParse(atController.text.trim()) ?? 0;
                    final parsedPa =
                        int.tryParse(paController.text.trim()) ?? 0;
                    Navigator.of(dialogContext).pop(
                      OffhandEquipmentEntry(
                        name: nameController.text.trim(),
                        type: type,
                        breakFactor: parsedBreakFactor < 0
                            ? 0
                            : parsedBreakFactor,
                        shieldSize: shieldSize,
                        iniMod: parsedIni,
                        atMod: parsedAt,
                        paMod: parsedPa,
                      ),
                    );
                  },
                  child: const Text('Speichern'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == null) {
      return;
    }
    final nextEntries = List<OffhandEquipmentEntry>.from(offhandEquipment);
    if (isNew) {
      nextEntries.add(result);
    } else {
      nextEntries[entryIndex] = result;
    }
    onOffhandEquipmentChanged(nextEntries);
  }

  // ---------------------------------------------------------------------------
  // Helfer
  // ---------------------------------------------------------------------------

  Widget _tappableNameCell(
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

  static Widget _numberField({
    required TextEditingController controller,
    required String keyName,
    required String label,
  }) {
    return SizedBox(
      width: 130,
      child: TextField(
        key: ValueKey<String>(keyName),
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}
