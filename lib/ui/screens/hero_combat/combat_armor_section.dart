// Ruestungstabelle als eigenstaendiges Widget.
//
// Zeigt Ruestungsstuecke in einer FlexibleTable an, bietet einen
// Editor-Dialog und eine Berechnungsvorschau (RS, BE, eBE).
import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/adaptive_table_columns.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/flexible_table.dart';

class CombatArmorSection extends StatelessWidget {
  const CombatArmorSection({
    super.key,
    required this.armor,
    required this.onArmorChanged,
    required this.previewRsTotal,
    required this.previewBeTotalRaw,
    required this.previewRgReduction,
    required this.previewBeKampf,
    required this.previewBeMod,
    required this.previewEbe,
  });

  /// Aktuelle Ruestungskonfiguration.
  final ArmorConfig armor;

  /// Callback: Ruestung wurde geaendert.
  final void Function(ArmorConfig) onArmorChanged;

  /// Preview-Werte fuer die Berechnungsvorschau.
  final int previewRsTotal;
  final int previewBeTotalRaw;
  final int previewRgReduction;
  final int previewBeKampf;
  final int previewBeMod;
  final int previewEbe;

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    const armorDetailsBreakpoint = 760.0;
    final showPieceRg1 = armor.globalArmorTrainingLevel == 1;
    final armorRows = <FlexibleTableRow>[
      for (var i = 0; i < armor.pieces.length; i++)
        FlexibleTableRow(
          cells: [
            _tappableNameCell(
              context,
              armor.pieces[i].name.trim().isEmpty
                  ? 'Rüstung ${i + 1}'
                  : armor.pieces[i].name,
              onTap: () => _openEditor(context, pieceIndex: i),
            ),
            Text(armor.pieces[i].rs.toString()),
            Text(armor.pieces[i].be.toString()),
            Text(armor.pieces[i].isActive ? 'Ja' : 'Nein'),
            if (showPieceRg1) Text(armor.pieces[i].rg1Active ? 'Ja' : 'Nein'),
            IconButton(
              key: ValueKey<String>('combat-armor-remove-$i'),
              tooltip: 'Rüstung entfernen',
              onPressed: () => _removePiece(i),
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
            Text('Rüstung', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final armorTableSection = Column(
                  key: const ValueKey<String>('combat-armor-table-section'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FlexibleTable(
                      tableKey: const ValueKey<String>('combat-armor-table'),
                      columnSpecs: _columnSpecs(showPieceRg1: showPieceRg1),
                      headerCells: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Name'),
                            IconButton(
                              key: const ValueKey<String>('combat-armor-add'),
                              tooltip: 'Rüstung hinzufügen',
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
                        const Text('RS'),
                        const Text('BE'),
                        const Text('Aktiv'),
                        if (showPieceRg1) const Text('RG I'),
                        const Text('Aktion'),
                      ],
                      rows: armorRows,
                    ),
                    if (armorRows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('Keine Rüstungsstücke erfasst.'),
                      ),
                  ],
                );
                final armorCalculationSection = Column(
                  key: const ValueKey<String>(
                    'combat-armor-calculation-section',
                  ),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RS gesamt = Summe aktiver RS = $previewRsTotal'),
                    Text(
                      'BE (Kampf) = BE Roh ($previewBeTotalRaw) - RG ($previewRgReduction) = $previewBeKampf',
                    ),
                    Text(
                      'eBE = min(0, -BE(Kampf) ($previewBeKampf) - BE Mod ($previewBeMod)) = $previewEbe',
                    ),
                  ],
                );
                if (constraints.maxWidth < armorDetailsBreakpoint) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      armorTableSection,
                      const SizedBox(height: 8),
                      armorCalculationSection,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: armorTableSection),
                    const SizedBox(width: 16),
                    Expanded(child: armorCalculationSection),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Spalten-Specs
  // ---------------------------------------------------------------------------

  static List<AdaptiveTableColumnSpec> _columnSpecs({
    required bool showPieceRg1,
  }) {
    return <AdaptiveTableColumnSpec>[
      const AdaptiveTableColumnSpec(minWidth: 150, maxWidth: 260, flex: 2),
      const AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 80),
      const AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 80),
      const AdaptiveTableColumnSpec(minWidth: 68, maxWidth: 100),
      if (showPieceRg1)
        const AdaptiveTableColumnSpec(minWidth: 68, maxWidth: 100),
      const AdaptiveTableColumnSpec.fixed(56),
    ];
  }

  // ---------------------------------------------------------------------------
  // Aktionen
  // ---------------------------------------------------------------------------

  void _removePiece(int index) {
    final pieces = List<ArmorPiece>.from(armor.pieces);
    if (index < 0 || index >= pieces.length) {
      return;
    }
    pieces.removeAt(index);
    onArmorChanged(armor.copyWith(
      pieces: List<ArmorPiece>.unmodifiable(pieces),
    ));
  }

  Future<void> _openEditor(
    BuildContext context, {
    int? pieceIndex,
  }) async {
    final isNew = pieceIndex == null;
    final sourcePiece = isNew ? const ArmorPiece() : armor.pieces[pieceIndex];
    final nameController = TextEditingController(text: sourcePiece.name);
    final rsController = TextEditingController(text: sourcePiece.rs.toString());
    final beController = TextEditingController(text: sourcePiece.be.toString());
    var isActive = sourcePiece.isActive;
    var rg1Active = sourcePiece.rg1Active;
    final canSelectPieceRg1 = armor.globalArmorTrainingLevel == 1;
    String? validationMessage;

    final result = await showDialog<ArmorPiece>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(isNew ? 'Rüstung hinzufügen' : 'Rüstung bearbeiten'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        key: const ValueKey<String>('combat-armor-form-name'),
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _numberField(
                            controller: rsController,
                            keyName: 'combat-armor-form-rs',
                            label: 'RS',
                          ),
                          _numberField(
                            controller: beController,
                            keyName: 'combat-armor-form-be',
                            label: 'BE',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        key: const ValueKey<String>('combat-armor-form-active'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Aktiv'),
                        value: isActive,
                        onChanged: (value) {
                          setDialogState(() {
                            isActive = value;
                          });
                        },
                      ),
                      if (canSelectPieceRg1)
                        SwitchListTile(
                          key: const ValueKey<String>('combat-armor-form-rg1'),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('RG I aktiv'),
                          value: rg1Active,
                          onChanged: (value) {
                            setDialogState(() {
                              rg1Active = value;
                            });
                          },
                        ),
                      if (validationMessage != null &&
                          validationMessage!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            validationMessage!,
                            style: TextStyle(
                              color: Theme.of(dialogContext).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  key: const ValueKey<String>('combat-armor-form-save'),
                  onPressed: () {
                    final name = nameController.text.trim();
                    final parsedRs =
                        int.tryParse(rsController.text.trim()) ?? 0;
                    final parsedBe =
                        int.tryParse(beController.text.trim()) ?? 0;
                    if (name.isEmpty) {
                      setDialogState(() {
                        validationMessage = 'Name ist ein Pflichtfeld.';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(
                      sourcePiece.copyWith(
                        name: name,
                        isActive: isActive,
                        rg1Active: rg1Active,
                        rs: parsedRs < 0 ? 0 : parsedRs,
                        be: parsedBe < 0 ? 0 : parsedBe,
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
    final updatedPieces = List<ArmorPiece>.from(armor.pieces);
    if (isNew) {
      updatedPieces.add(result);
    } else {
      updatedPieces[pieceIndex] = result;
    }
    onArmorChanged(armor.copyWith(
      pieces: List<ArmorPiece>.unmodifiable(updatedPieces),
    ));
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
