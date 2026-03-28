// Nebenhand-Ausruestungstabelle als eigenstaendiges Widget.
//
// Zeigt Parierwaffen und Schilde in einer FlexibleTable an
// und bietet einen responsiven Editor fuer neue/bestehende Eintraege.
import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/combat_helpers.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/adaptive_table_columns.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/flexible_table.dart';

/// Verwaltet Nebenhand-Eintraege und oeffnet den Editor auf breiten Layouts rechts.
class CombatOffhandSection extends StatefulWidget {
  /// Erstellt die Nebenhand-Sektion fuer den Kampf-Tab.
  const CombatOffhandSection({
    super.key,
    required this.offhandEquipment,
    required this.onOffhandEquipmentChanged,
  });

  /// Aktuelle Nebenhand-Ausruestungsliste.
  final List<OffhandEquipmentEntry> offhandEquipment;

  /// Callback: gesamte Liste wurde geaendert (hinzufuegen/bearbeiten/entfernen).
  final void Function(List<OffhandEquipmentEntry>) onOffhandEquipmentChanged;

  @override
  State<CombatOffhandSection> createState() => _CombatOffhandSectionState();
}

class _CombatOffhandSectionState extends State<CombatOffhandSection> {
  static const double _wideLayoutBreakpoint = 1280;
  static const List<AdaptiveTableColumnSpec> _columnSpecs =
      <AdaptiveTableColumnSpec>[
        AdaptiveTableColumnSpec(minWidth: 150, maxWidth: 260, flex: 2),
        AdaptiveTableColumnSpec(minWidth: 110, maxWidth: 180, flex: 1),
        AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 84),
        AdaptiveTableColumnSpec(minWidth: 90, maxWidth: 150, flex: 1),
        AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 84),
        AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 84),
        AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 84),
        AdaptiveTableColumnSpec(minWidth: 70, maxWidth: 110),
        AdaptiveTableColumnSpec(minWidth: 180, maxWidth: 320, flex: 2),
        AdaptiveTableColumnSpec.fixed(56),
      ];

  int? _editingEntryIndex;
  OffhandEquipmentEntry? _editorSeedEntry;

  bool get _isWideLayout =>
      MediaQuery.sizeOf(context).width >= _wideLayoutBreakpoint;

  @override
  void didUpdateWidget(covariant CombatOffhandSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final editingIndex = _editingEntryIndex;
    if (editingIndex == null) {
      return;
    }
    if (editingIndex >= widget.offhandEquipment.length) {
      _closeWideEditor();
      return;
    }
    _editorSeedEntry ??= widget.offhandEquipment[editingIndex];
  }

  @override
  Widget build(BuildContext context) {
    final rows = <FlexibleTableRow>[
      for (var i = 0; i < widget.offhandEquipment.length; i++)
        FlexibleTableRow(
          cells: [
            _tappableNameCell(
              context,
              widget.offhandEquipment[i].name.trim().isEmpty
                  ? 'Eintrag ${i + 1}'
                  : widget.offhandEquipment[i].name,
              onTap: () => _openEditor(entryIndex: i),
            ),
            Text(
              widget.offhandEquipment[i].isShield ? 'Schild' : 'Parierwaffe',
            ),
            Text(widget.offhandEquipment[i].breakFactor.toString()),
            Text(
              widget.offhandEquipment[i].isShield
                  ? shieldSizeLabel(widget.offhandEquipment[i].shieldSize)
                  : '-',
            ),
            Text(widget.offhandEquipment[i].iniMod.toString()),
            Text(widget.offhandEquipment[i].atMod.toString()),
            Text(widget.offhandEquipment[i].paMod.toString()),
            Text(widget.offhandEquipment[i].isArtifact ? 'Ja' : 'Nein'),
            Text(_artifactDescriptionText(widget.offhandEquipment[i])),
            IconButton(
              key: ValueKey<String>('combat-offhand-remove-$i'),
              tooltip: 'Nebenhand-Ausrüstung entfernen',
              onPressed: () => _removeEntry(i),
              icon: const Icon(Icons.delete),
            ),
          ],
        ),
    ];

    final tableSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Parierwaffen & Schilde',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            FilledButton(
              key: const ValueKey<String>('combat-offhand-add'),
              onPressed: () => _openEditor(),
              child: const Text('+ Parierwaffe/Schild'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FlexibleTable(
          tableKey: const ValueKey<String>('combat-offhand-table'),
          columnSpecs: _columnSpecs,
          headerCells: [
            const Text('Name'),
            const Text('Typ'),
            const Text('BF'),
            const Text('Größe'),
            const Text('INI Mod'),
            const Text('AT Mod'),
            const Text('PA Mod'),
            const Text('Artefakt'),
            const Text('Artefaktbeschreibung'),
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
    );

    final tableCard = Card(
      key: const ValueKey<String>('combat-offhand-card'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: tableSection,
      ),
    );

    if (!_isWideLayout || _editorSeedEntry == null) {
      return tableCard;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: tableCard),
        const SizedBox(width: 12),
        SizedBox(
          width: 380,
          child: Card(
            key: const ValueKey<String>('combat-offhand-editor-card'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _OffhandEditorPanel(
                key: ValueKey<String>(
                  'combat-offhand-editor-${_editingEntryIndex ?? 'new'}',
                ),
                initialEntry: _editorSeedEntry!,
                isNew: _editingEntryIndex == null,
                onCancel: _closeWideEditor,
                onSave: _saveEntry,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _removeEntry(int index) {
    final entries = List<OffhandEquipmentEntry>.from(widget.offhandEquipment);
    if (index < 0 || index >= entries.length) {
      return;
    }
    entries.removeAt(index);
    widget.onOffhandEquipmentChanged(entries);
    if (_editingEntryIndex == null) {
      return;
    }
    if (_editingEntryIndex == index) {
      _closeWideEditor();
      return;
    }
    if (_editingEntryIndex! > index) {
      setState(() {
        _editingEntryIndex = _editingEntryIndex! - 1;
      });
    }
  }

  Future<void> _openEditor({int? entryIndex}) async {
    final source = entryIndex == null
        ? const OffhandEquipmentEntry()
        : widget.offhandEquipment[entryIndex];
    if (_isWideLayout) {
      setState(() {
        _editingEntryIndex = entryIndex;
        _editorSeedEntry = source;
      });
      return;
    }

    final result = await showAdaptiveDetailSheet<OffhandEquipmentEntry>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kDialogWidthMedium),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _OffhandEditorPanel(
                initialEntry: source,
                isNew: entryIndex == null,
                onCancel: () => Navigator.of(dialogContext).pop(),
                onSave: (entry) => Navigator.of(dialogContext).pop(entry),
              ),
            ),
          ),
        );
      },
    );
    if (result == null) {
      return;
    }
    _applyEntry(result, entryIndex: entryIndex);
  }

  void _closeWideEditor() {
    setState(() {
      _editingEntryIndex = null;
      _editorSeedEntry = null;
    });
  }

  void _saveEntry(OffhandEquipmentEntry entry) {
    _applyEntry(entry, entryIndex: _editingEntryIndex);
    _closeWideEditor();
  }

  void _applyEntry(OffhandEquipmentEntry entry, {required int? entryIndex}) {
    final nextEntries = List<OffhandEquipmentEntry>.from(
      widget.offhandEquipment,
    );
    if (entryIndex == null) {
      nextEntries.add(entry);
    } else if (entryIndex >= 0 && entryIndex < nextEntries.length) {
      nextEntries[entryIndex] = entry;
    }
    widget.onOffhandEquipmentChanged(nextEntries);
  }

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
}

/// Bearbeitet ein Schild oder eine Parierwaffe fuer Dialog- und Split-Ansichten.
class _OffhandEditorPanel extends StatefulWidget {
  /// Erstellt das Editor-Panel fuer Nebenhand-Ausrüstung.
  const _OffhandEditorPanel({
    super.key,
    required this.initialEntry,
    required this.isNew,
    required this.onCancel,
    required this.onSave,
  });

  final OffhandEquipmentEntry initialEntry;
  final bool isNew;
  final VoidCallback onCancel;
  final void Function(OffhandEquipmentEntry entry) onSave;

  @override
  State<_OffhandEditorPanel> createState() => _OffhandEditorPanelState();
}

class _OffhandEditorPanelState extends State<_OffhandEditorPanel> {
  late final TextEditingController _nameController;
  late final TextEditingController _bfController;
  late final TextEditingController _iniController;
  late final TextEditingController _atController;
  late final TextEditingController _paController;
  late final TextEditingController _artifactDescriptionController;
  late OffhandEquipmentType _type;
  late ShieldSize _shieldSize;
  late bool _isArtifact;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialEntry.name);
    _bfController = TextEditingController(
      text: widget.initialEntry.breakFactor.toString(),
    );
    _iniController = TextEditingController(
      text: widget.initialEntry.iniMod.toString(),
    );
    _atController = TextEditingController(
      text: widget.initialEntry.atMod.toString(),
    );
    _paController = TextEditingController(
      text: widget.initialEntry.paMod.toString(),
    );
    _artifactDescriptionController = TextEditingController(
      text: widget.initialEntry.artifactDescription,
    );
    _type = widget.initialEntry.type;
    _shieldSize = widget.initialEntry.shieldSize;
    _isArtifact = widget.initialEntry.isArtifact;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bfController.dispose();
    _iniController.dispose();
    _atController.dispose();
    _paController.dispose();
    _artifactDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        key: const ValueKey<String>('combat-offhand-editor-panel'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.isNew
                      ? 'Nebenhand-Ausrüstung hinzufügen'
                      : 'Nebenhand-Ausrüstung bearbeiten',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                key: const ValueKey<String>('combat-offhand-panel-close'),
                tooltip: 'Editor schließen',
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('combat-offhand-form-name'),
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Ausrüstungsname',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<OffhandEquipmentType>(
            key: const ValueKey<String>('combat-offhand-form-type'),
            initialValue: _type,
            decoration: const InputDecoration(
              labelText: 'Typ',
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
              setState(() {
                _type = value ?? OffhandEquipmentType.parryWeapon;
              });
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _numberField(
                controller: _bfController,
                keyName: 'combat-offhand-form-bf',
                label: 'BF',
              ),
              _numberField(
                controller: _iniController,
                keyName: 'combat-offhand-form-ini-mod',
                label: 'INI Mod',
              ),
              _numberField(
                controller: _atController,
                keyName: 'combat-offhand-form-at-mod',
                label: 'AT Mod',
              ),
              _numberField(
                controller: _paController,
                keyName: 'combat-offhand-form-pa-mod',
                label: 'PA Mod',
              ),
            ],
          ),
          if (_type == OffhandEquipmentType.shield) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<ShieldSize>(
              key: const ValueKey<String>('combat-offhand-form-shield-size'),
              initialValue: _shieldSize,
              decoration: const InputDecoration(
                labelText: 'Größe',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: ShieldSize.small, child: Text('Klein')),
                DropdownMenuItem(value: ShieldSize.large, child: Text('Groß')),
                DropdownMenuItem(
                  value: ShieldSize.veryLarge,
                  child: Text('Sehr groß'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _shieldSize = value ?? ShieldSize.small;
                });
              },
            ),
          ],
          const SizedBox(height: 12),
          SwitchListTile(
            key: const ValueKey<String>('combat-offhand-form-artifact'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Artefakt'),
            value: _isArtifact,
            onChanged: (value) {
              setState(() {
                _isArtifact = value;
              });
            },
          ),
          TextField(
            key: const ValueKey<String>(
              'combat-offhand-form-artifact-description',
            ),
            controller: _artifactDescriptionController,
            enabled: _isArtifact,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Artefaktbeschreibung',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                key: const ValueKey<String>('combat-offhand-form-save'),
                onPressed: _submit,
                child: const Text('Speichern'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _submit() {
    final parsedBreakFactor = int.tryParse(_bfController.text.trim()) ?? 0;
    final parsedIni = int.tryParse(_iniController.text.trim()) ?? 0;
    final parsedAt = int.tryParse(_atController.text.trim()) ?? 0;
    final parsedPa = int.tryParse(_paController.text.trim()) ?? 0;
    widget.onSave(
      OffhandEquipmentEntry(
        name: _nameController.text.trim(),
        type: _type,
        breakFactor: parsedBreakFactor < 0 ? 0 : parsedBreakFactor,
        shieldSize: _shieldSize,
        iniMod: parsedIni,
        atMod: parsedAt,
        paMod: parsedPa,
        isArtifact: _isArtifact,
        artifactDescription: _artifactDescriptionController.text.trim(),
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

String _artifactDescriptionText(OffhandEquipmentEntry entry) {
  if (!entry.isArtifact) {
    return '-';
  }
  final description = entry.artifactDescription.trim();
  if (description.isEmpty) {
    return '-';
  }
  return description;
}
