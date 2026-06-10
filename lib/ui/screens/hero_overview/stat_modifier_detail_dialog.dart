import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/modifier_list_editor.dart';

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
  late final ModifierListController _modifiers;

  @override
  void initState() {
    super.initState();
    _modifiers = ModifierListController(widget.namedModifiers);
  }

  @override
  void dispose() {
    _modifiers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Read-only Quellen (nur Nicht-Null-Werte anzeigen).
    final nonZeroSources = widget.parsedSources
        .where((entry) => entry.value != 0)
        .toList();

    return AlertDialog(
      title: Text('Modifikatoren: ${widget.statLabel}'),
      content: SizedBox(
        width: kDialogWidthLarge,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              modifierSectionTitle(theme, 'Eigene Modifikatoren'),
              ModifierListEditor(
                controller: _modifiers,
                keyPrefix: 'stat-modifier',
                addButtonKey: const ValueKey<String>('stat-modifiers-add'),
                emptyPlaceholder: const Padding(
                  padding: EdgeInsets.only(bottom: kDialogFieldSpacing),
                  child: Text('Keine eigenen Modifikatoren vorhanden.'),
                ),
              ),
              if (nonZeroSources.isNotEmpty) ...[
                const SizedBox(height: kDialogSectionSpacing),
                modifierSectionTitle(theme, 'Automatisch (nur Anzeige)'),
                ...nonZeroSources.map(
                  (entry) => modifierSourceRow(theme, entry.label, entry.value),
                ),
              ],
              const Divider(height: kDialogSectionSpacing * 2),
              modifierSourceRow(theme, 'Gesamt', widget.total, bold: true),
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
          onPressed: () =>
              Navigator.of(context).pop(_modifiers.buildModifiers()),
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

/// Abschnittstitel fuer die Modifikator-Detail-Dialoge.
Widget modifierSectionTitle(ThemeData theme, String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      title,
      style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
    ),
  );
}

/// Read-only Zeile mit Label und vorzeichenbehaftetem Wert.
Widget modifierSourceRow(
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
        SizedBox(width: 140, child: Text(label, style: labelStyle)),
        Text('$sign$value', style: style),
      ],
    ),
  );
}
