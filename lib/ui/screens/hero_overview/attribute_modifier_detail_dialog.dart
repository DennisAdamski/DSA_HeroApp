import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview/stat_modifier_detail_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/modifier_list_editor.dart';

/// Oeffnet den kombinierten Detail- und Bearbeitungsdialog fuer Eigenschafts-
/// Modifikatoren.
///
/// [attributeLabel]: Anzeigename der Eigenschaft (z.B. "MU", "KL").
/// [baseValue]: Aktueller Basiswert der Eigenschaft.
/// [namedModifiers]: Vom Benutzer gepflegte benannte Modifikatoren.
/// [parsedSources]: Read-only Quellen (Vorteile, Nachteile, Inventar, etc.).
/// [effectiveValue]: Berechneter Endwert.
///
/// Gibt die bearbeitete Liste zurueck, oder `null` bei Abbruch.
Future<List<HeroTalentModifier>?> showAttributeModifierDetailDialog({
  required BuildContext context,
  required String attributeLabel,
  required int baseValue,
  required List<HeroTalentModifier> namedModifiers,
  required List<ModifierSourceEntry> parsedSources,
  required int effectiveValue,
}) {
  return showAdaptiveDetailSheet<List<HeroTalentModifier>>(
    context: context,
    builder: (_) => _AttributeModifierDetailDialog(
      attributeLabel: attributeLabel,
      baseValue: baseValue,
      namedModifiers: namedModifiers,
      parsedSources: parsedSources,
      effectiveValue: effectiveValue,
    ),
  );
}

class _AttributeModifierDetailDialog extends StatefulWidget {
  const _AttributeModifierDetailDialog({
    required this.attributeLabel,
    required this.baseValue,
    required this.namedModifiers,
    required this.parsedSources,
    required this.effectiveValue,
  });

  final String attributeLabel;
  final int baseValue;
  final List<HeroTalentModifier> namedModifiers;
  final List<ModifierSourceEntry> parsedSources;
  final int effectiveValue;

  @override
  State<_AttributeModifierDetailDialog> createState() =>
      _AttributeModifierDetailDialogState();
}

class _AttributeModifierDetailDialogState
    extends State<_AttributeModifierDetailDialog> {
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

    final nonZeroSources = widget.parsedSources
        .where((entry) => entry.value != 0)
        .toList();

    return AlertDialog(
      title: Text('Modifikatoren: ${widget.attributeLabel}'),
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
                keyPrefix: 'attr-modifier',
                addButtonKey: const ValueKey<String>('attr-modifiers-add'),
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
              modifierSourceRow(theme, 'Wert', widget.baseValue),
              modifierSourceRow(
                theme,
                'Aktuell',
                widget.effectiveValue,
                bold: true,
              ),
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
          key: const ValueKey<String>('attr-modifiers-save'),
          onPressed: () =>
              Navigator.of(context).pop(_modifiers.buildModifiers()),
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
