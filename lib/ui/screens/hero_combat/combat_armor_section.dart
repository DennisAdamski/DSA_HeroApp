// Ruestungstabelle als eigenstaendiges Widget.
//
// Zeigt Ruestungsstuecke in einer FlexibleTable an, bietet einen
// responsiven Editor und eine Berechnungsvorschau (RS, BE, eBE).
import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/debug/ui_rebuild_observer.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/adaptive_table_columns.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/flexible_table.dart';

/// Verwaltet Ruestungsstuecke und oeffnet den Editor auf breiten Layouts rechts.
class CombatArmorSection extends StatefulWidget {
  /// Erstellt die Ruestungs-Sektion fuer den Kampf-Tab.
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

  @override
  State<CombatArmorSection> createState() => _CombatArmorSectionState();
}

class _CombatArmorSectionState extends State<CombatArmorSection> {
  static const double _wideLayoutBreakpoint = 1280;
  int? _editingPieceIndex;
  ArmorPiece? _editorSeedPiece;

  bool get _isWideLayout =>
      MediaQuery.sizeOf(context).width >= _wideLayoutBreakpoint;

  @override
  void didUpdateWidget(covariant CombatArmorSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final editingIndex = _editingPieceIndex;
    if (editingIndex == null) {
      return;
    }
    if (editingIndex >= widget.armor.pieces.length) {
      _closeWideEditor();
      return;
    }
    _editorSeedPiece ??= widget.armor.pieces[editingIndex];
  }

  @override
  Widget build(BuildContext context) {
    UiRebuildObserver.bump('combat_armor_section');
    final sectionContent = _buildSectionContent(context);
    final tableCard = Card(
      key: const ValueKey<String>('combat-armor-card'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: sectionContent,
      ),
    );
    if (!_isWideLayout || _editorSeedPiece == null) {
      return tableCard;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: tableCard),
        const SizedBox(width: 12),
        SizedBox(
          width: 360,
          child: Card(
            key: const ValueKey<String>('combat-armor-editor-card'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _ArmorPieceEditorPanel(
                key: ValueKey<String>(
                  'combat-armor-editor-${_editingPieceIndex ?? 'new'}',
                ),
                initialPiece: _editorSeedPiece!,
                showRg1Toggle: widget.armor.globalArmorTrainingLevel == 1,
                isNew: _editingPieceIndex == null,
                onCancel: _closeWideEditor,
                onSave: _savePiece,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionContent(BuildContext context) {
    const armorDetailsBreakpoint = 760.0;
    final showPieceRg1 = widget.armor.globalArmorTrainingLevel == 1;
    final armorRows = <FlexibleTableRow>[
      for (var i = 0; i < widget.armor.pieces.length; i++)
        FlexibleTableRow(
          cells: [
            _tappableNameCell(
              context,
              widget.armor.pieces[i].name.trim().isEmpty
                  ? 'Rüstung ${i + 1}'
                  : widget.armor.pieces[i].name,
              onTap: () => _openEditor(pieceIndex: i),
            ),
            Text(widget.armor.pieces[i].rs.toString()),
            Text(widget.armor.pieces[i].be.toString()),
            Text(widget.armor.pieces[i].isActive ? 'Ja' : 'Nein'),
            Text(widget.armor.pieces[i].isArtifact ? 'Ja' : 'Nein'),
            Text(_artifactDescriptionText(widget.armor.pieces[i])),
            Text(widget.armor.pieces[i].isGeweiht ? 'Ja' : 'Nein'),
            Text(_geweihtDescriptionText(widget.armor.pieces[i])),
            if (showPieceRg1)
              Text(widget.armor.pieces[i].rg1Active ? 'Ja' : 'Nein'),
            IconButton(
              key: ValueKey<String>('combat-armor-remove-$i'),
              tooltip: 'Rüstung entfernen',
              onPressed: () => _removePiece(i),
              icon: const Icon(Icons.delete),
            ),
          ],
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Rüstung',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            FilledButton(
              key: const ValueKey<String>('combat-armor-add'),
              onPressed: () => _openEditor(),
              child: const Text('+ Rüstung'),
            ),
          ],
        ),
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
                    const Text('Name'),
                    const Text('RS'),
                    const Text('BE'),
                    const Text('Aktiv'),
                    const Text('Artefakt'),
                    const Text('Artefaktbeschreibung'),
                    const Text('Geweiht'),
                    const Text('Beschreibung (geweiht)'),
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
              key: const ValueKey<String>('combat-armor-calculation-section'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RS gesamt = Summe aktiver RS = ${widget.previewRsTotal}'),
                Text(
                  'BE (Kampf) = BE Roh (${widget.previewBeTotalRaw}) - RG (${widget.previewRgReduction}) = ${widget.previewBeKampf}',
                ),
                Text(
                  'eBE = min(0, -BE(Kampf) (${widget.previewBeKampf}) - BE Mod (${widget.previewBeMod})) = ${widget.previewEbe}',
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
    );
  }

  static List<AdaptiveTableColumnSpec> _columnSpecs({
    required bool showPieceRg1,
  }) {
    return <AdaptiveTableColumnSpec>[
      const AdaptiveTableColumnSpec(minWidth: 150, maxWidth: 260, flex: 2), // Name
      const AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 80),             // RS
      const AdaptiveTableColumnSpec(minWidth: 56, maxWidth: 80),             // BE
      const AdaptiveTableColumnSpec(minWidth: 68, maxWidth: 100),            // Aktiv
      const AdaptiveTableColumnSpec(minWidth: 70, maxWidth: 110),            // Artefakt
      const AdaptiveTableColumnSpec(minWidth: 180, maxWidth: 320, flex: 2), // Artefaktbeschreibung
      const AdaptiveTableColumnSpec(minWidth: 70, maxWidth: 110),            // Geweiht
      const AdaptiveTableColumnSpec(minWidth: 180, maxWidth: 320, flex: 2), // Beschreibung (geweiht)
      if (showPieceRg1)
        const AdaptiveTableColumnSpec(minWidth: 68, maxWidth: 100),          // RG I aktiv
      const AdaptiveTableColumnSpec.fixed(56),                               // Aktion
    ];
  }

  void _removePiece(int index) {
    final pieces = List<ArmorPiece>.from(widget.armor.pieces);
    if (index < 0 || index >= pieces.length) {
      return;
    }
    pieces.removeAt(index);
    widget.onArmorChanged(
      widget.armor.copyWith(pieces: List<ArmorPiece>.unmodifiable(pieces)),
    );
    if (_editingPieceIndex == null) {
      return;
    }
    if (_editingPieceIndex == index) {
      _closeWideEditor();
      return;
    }
    if (_editingPieceIndex! > index) {
      setState(() {
        _editingPieceIndex = _editingPieceIndex! - 1;
      });
    }
  }

  Future<void> _openEditor({int? pieceIndex}) async {
    final sourcePiece = pieceIndex == null
        ? const ArmorPiece()
        : widget.armor.pieces[pieceIndex];
    if (_isWideLayout) {
      setState(() {
        _editingPieceIndex = pieceIndex;
        _editorSeedPiece = sourcePiece;
      });
      return;
    }

    final result = await showAdaptiveDetailSheet<ArmorPiece>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kDialogWidthMedium),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _ArmorPieceEditorPanel(
                initialPiece: sourcePiece,
                showRg1Toggle: widget.armor.globalArmorTrainingLevel == 1,
                isNew: pieceIndex == null,
                onCancel: () => Navigator.of(dialogContext).pop(),
                onSave: (piece) => Navigator.of(dialogContext).pop(piece),
              ),
            ),
          ),
        );
      },
    );
    if (result == null) {
      return;
    }
    _applyPiece(result, pieceIndex: pieceIndex);
  }

  void _closeWideEditor() {
    setState(() {
      _editingPieceIndex = null;
      _editorSeedPiece = null;
    });
  }

  void _savePiece(ArmorPiece piece) {
    _applyPiece(piece, pieceIndex: _editingPieceIndex);
    _closeWideEditor();
  }

  void _applyPiece(ArmorPiece piece, {required int? pieceIndex}) {
    final updatedPieces = List<ArmorPiece>.from(widget.armor.pieces);
    if (pieceIndex == null) {
      updatedPieces.add(piece);
    } else if (pieceIndex >= 0 && pieceIndex < updatedPieces.length) {
      updatedPieces[pieceIndex] = piece;
    }
    widget.onArmorChanged(
      widget.armor.copyWith(
        pieces: List<ArmorPiece>.unmodifiable(updatedPieces),
      ),
    );
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

/// Bearbeitet ein einzelnes Ruestungsstueck fuer Dialog- und Split-Ansichten.
class _ArmorPieceEditorPanel extends StatefulWidget {
  /// Erstellt das Editor-Panel fuer ein Ruestungsstueck.
  const _ArmorPieceEditorPanel({
    super.key,
    required this.initialPiece,
    required this.showRg1Toggle,
    required this.isNew,
    required this.onCancel,
    required this.onSave,
  });

  final ArmorPiece initialPiece;
  final bool showRg1Toggle;
  final bool isNew;
  final VoidCallback onCancel;
  final void Function(ArmorPiece piece) onSave;

  @override
  State<_ArmorPieceEditorPanel> createState() => _ArmorPieceEditorPanelState();
}

class _ArmorPieceEditorPanelState extends State<_ArmorPieceEditorPanel> {
  late final TextEditingController _nameController;
  late final TextEditingController _rsController;
  late final TextEditingController _beController;
  late final TextEditingController _artifactDescriptionController;
  late final TextEditingController _geweihtDescriptionController;
  late bool _isActive;
  late bool _rg1Active;
  late bool _isArtifact;
  late bool _isGeweiht;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialPiece.name);
    _rsController = TextEditingController(
      text: widget.initialPiece.rs.toString(),
    );
    _beController = TextEditingController(
      text: widget.initialPiece.be.toString(),
    );
    _artifactDescriptionController = TextEditingController(
      text: widget.initialPiece.artifactDescription,
    );
    _geweihtDescriptionController = TextEditingController(
      text: widget.initialPiece.geweihtDescription,
    );
    _isActive = widget.initialPiece.isActive;
    _rg1Active = widget.initialPiece.rg1Active;
    _isArtifact = widget.initialPiece.isArtifact;
    _isGeweiht = widget.initialPiece.isGeweiht;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rsController.dispose();
    _beController.dispose();
    _artifactDescriptionController.dispose();
    _geweihtDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        key: const ValueKey<String>('combat-armor-editor-panel'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.isNew ? 'Rüstung hinzufügen' : 'Rüstung bearbeiten',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                key: const ValueKey<String>('combat-armor-panel-close'),
                tooltip: 'Editor schließen',
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('combat-armor-form-name'),
            controller: _nameController,
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
                controller: _rsController,
                keyName: 'combat-armor-form-rs',
                label: 'RS',
              ),
              _numberField(
                controller: _beController,
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
            value: _isActive,
            onChanged: (value) {
              setState(() {
                _isActive = value;
              });
            },
          ),
          SwitchListTile(
            key: const ValueKey<String>('combat-armor-form-artifact'),
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
              'combat-armor-form-artifact-description',
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
          SwitchListTile(
            key: const ValueKey<String>('combat-armor-form-geweiht'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Geweiht'),
            value: _isGeweiht,
            onChanged: (value) {
              setState(() {
                _isGeweiht = value;
              });
            },
          ),
          TextField(
            key: const ValueKey<String>(
              'combat-armor-form-geweiht-description',
            ),
            controller: _geweihtDescriptionController,
            enabled: _isGeweiht,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Beschreibung (geweiht)',
              border: OutlineInputBorder(),
            ),
          ),
          if (widget.showRg1Toggle)
            SwitchListTile(
              key: const ValueKey<String>('combat-armor-form-rg1'),
              contentPadding: EdgeInsets.zero,
              title: const Text('RG I aktiv'),
              value: _rg1Active,
              onChanged: (value) {
                setState(() {
                  _rg1Active = value;
                });
              },
            ),
          if (_validationMessage != null &&
              _validationMessage!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _validationMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                key: const ValueKey<String>('combat-armor-form-save'),
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
    final name = _nameController.text.trim();
    final parsedRs = int.tryParse(_rsController.text.trim()) ?? 0;
    final parsedBe = int.tryParse(_beController.text.trim()) ?? 0;
    if (name.isEmpty) {
      setState(() {
        _validationMessage = 'Name ist ein Pflichtfeld.';
      });
      return;
    }
    widget.onSave(
      widget.initialPiece.copyWith(
        name: name,
        isActive: _isActive,
        rg1Active: _rg1Active,
        rs: parsedRs < 0 ? 0 : parsedRs,
        be: parsedBe < 0 ? 0 : parsedBe,
        isArtifact: _isArtifact,
        artifactDescription: _artifactDescriptionController.text.trim(),
        isGeweiht: _isGeweiht,
        geweihtDescription: _geweihtDescriptionController.text.trim(),
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

String _artifactDescriptionText(ArmorPiece piece) {
  if (!piece.isArtifact) {
    return '-';
  }
  final description = piece.artifactDescription.trim();
  if (description.isEmpty) {
    return '-';
  }
  return description;
}

String _geweihtDescriptionText(ArmorPiece piece) {
  if (!piece.isGeweiht) {
    return '-';
  }
  final description = piece.geweihtDescription.trim();
  if (description.isEmpty) {
    return '-';
  }
  return description;
}
