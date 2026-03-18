import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';

/// Eintrag fuer eine read-only Modifikatorquelle im Detail-Dialog.
typedef ModifierSourceEntry = ({String label, int value});

/// Oeffnet den kombinierten Detail- und Bearbeitungsdialog fuer Basiswert-
/// Modifikatoren.
///
/// [statLabel]: Anzeigename des Basiswerts (z.B. "LeP", "MR").
/// [namedModifiers]: Vom Benutzer gepflegte benannte Modifikatoren.
/// [parsedSources]: Read-only Quellen aus Text-Parsing, Level, Inventar etc.
/// [total]: Aktueller Gesamtmodifikator (fuer Anzeige).
///
/// Gibt die bearbeitete Liste zurueck, oder `null` bei Abbruch.
Future<List<HeroTalentModifier>?> showStatModifierDetailDialog({
  required BuildContext context,
  required String statLabel,
  required List<HeroTalentModifier> namedModifiers,
  required List<ModifierSourceEntry> parsedSources,
  required int total,
}) {
  return showAdaptiveDetailSheet<List<HeroTalentModifier>>(
    context: context,
    builder: (_) => _StatModifierDetailDialog(
      statLabel: statLabel,
      namedModifiers: namedModifiers,
      parsedSources: parsedSources,
      total: total,
    ),
  );
}

class _StatModifierDetailDialog extends StatefulWidget {
  const _StatModifierDetailDialog({
    required this.statLabel,
    required this.namedModifiers,
    required this.parsedSources,
    required this.total,
  });

  final String statLabel;
  final List<HeroTalentModifier> namedModifiers;
  final List<ModifierSourceEntry> parsedSources;
  final int total;

  @override
  State<_StatModifierDetailDialog> createState() =>
      _StatModifierDetailDialogState();
}

class _StatModifierDetailDialogState extends State<_StatModifierDetailDialog> {
  late List<TextEditingController> _modifierControllers;
  late List<TextEditingController> _descriptionControllers;

  @override
  void initState() {
    super.initState();
    _modifierControllers = widget.namedModifiers
        .map(
          (entry) => TextEditingController(text: entry.modifier.toString()),
        )
        .toList(growable: true);
    _descriptionControllers = widget.namedModifiers
        .map(
          (entry) => TextEditingController(text: entry.description),
        )
        .toList(growable: true);
  }

  @override
  void dispose() {
    for (final controller in _modifierControllers) {
      controller.dispose();
    }
    for (final controller in _descriptionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addModifierField() {
    setState(() {
      _modifierControllers = List<TextEditingController>.from(
        _modifierControllers,
      )..add(TextEditingController(text: '0'));
      _descriptionControllers = List<TextEditingController>.from(
        _descriptionControllers,
      )..add(TextEditingController());
    });
  }

  void _removeModifierField(int index) {
    final modifierController = _modifierControllers[index];
    final descriptionController = _descriptionControllers[index];
    setState(() {
      _modifierControllers = List<TextEditingController>.from(
        _modifierControllers,
      )..removeAt(index);
      _descriptionControllers = List<TextEditingController>.from(
        _descriptionControllers,
      )..removeAt(index);
    });
    modifierController.dispose();
    descriptionController.dispose();
  }

  List<HeroTalentModifier> _buildModifiers() {
    final modifiers = <HeroTalentModifier>[];
    for (var index = 0; index < _descriptionControllers.length; index++) {
      final description = _descriptionControllers[index].text.trim();
      if (description.isEmpty) {
        continue;
      }
      final modifier =
          int.tryParse(_modifierControllers[index].text.trim()) ?? 0;
      modifiers.add(
        HeroTalentModifier(modifier: modifier, description: description),
      );
    }
    return modifiers;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final modifierFields = <Widget>[];
    for (var index = 0; index < _modifierControllers.length; index++) {
      modifierFields.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: TextField(
                key: ValueKey<String>('stat-modifier-value-$index'),
                controller: _modifierControllers[index],
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'-?\d*')),
                ],
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  isDense: true,
                  labelText: 'Mod ${index + 1}',
                ),
              ),
            ),
            const SizedBox(width: kDialogInlineSpacing),
            Expanded(
              child: TextField(
                key: ValueKey<String>('stat-modifier-description-$index'),
                controller: _descriptionControllers[index],
                inputFormatters: <TextInputFormatter>[
                  LengthLimitingTextInputFormatter(60),
                ],
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  isDense: true,
                  labelText: 'Beschreibung ${index + 1}',
                ),
              ),
            ),
            const SizedBox(width: kDialogInlineSpacing),
            IconButton(
              onPressed: () => _removeModifierField(index),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Modifikator entfernen',
            ),
          ],
        ),
      );
      modifierFields.add(const SizedBox(height: kDialogInlineSpacing));
    }

    // Read-only Quellen (nur Nicht-Null-Werte anzeigen).
    final nonZeroSources =
        widget.parsedSources.where((entry) => entry.value != 0).toList();

    return AlertDialog(
      title: Text('Modifikatoren: ${widget.statLabel}'),
      content: SizedBox(
        width: kDialogWidthLarge,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(theme, 'Eigene Modifikatoren'),
              if (modifierFields.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: kDialogFieldSpacing),
                  child: Text('Keine eigenen Modifikatoren vorhanden.'),
                )
              else
                ...modifierFields,
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const ValueKey<String>('stat-modifiers-add'),
                  onPressed: _addModifierField,
                  icon: const Icon(Icons.add),
                  label: const Text('Modifikator hinzufuegen'),
                ),
              ),
              if (nonZeroSources.isNotEmpty) ...[
                const SizedBox(height: kDialogSectionSpacing),
                _sectionTitle(theme, 'Automatisch (nur Anzeige)'),
                ...nonZeroSources.map(
                  (entry) => _sourceRow(theme, entry.label, entry.value),
                ),
              ],
              const Divider(height: kDialogSectionSpacing * 2),
              _sourceRow(theme, 'Gesamt', widget.total, bold: true),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('stat-modifiers-save'),
          onPressed: () => Navigator.of(context).pop(_buildModifiers()),
          child: const Text('Speichern'),
        ),
      ],
    );
  }

  Widget _sectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _sourceRow(
    ThemeData theme,
    String label,
    int value, {
    bool bold = false,
  }) {
    final style = bold
        ? theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)
        : theme.textTheme.bodySmall;
    final labelStyle = bold
        ? style
        : style?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final sign = value >= 0 ? '+' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: labelStyle),
          ),
          Text('$sign$value', style: style),
        ],
      ),
    );
  }
}
