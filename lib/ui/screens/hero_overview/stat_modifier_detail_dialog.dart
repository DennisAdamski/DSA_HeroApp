import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_fragment_text.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview/herleitung_abschnitt.dart';

/// Eintrag fuer eine read-only Modifikatorquelle im Detail-Dialog.
typedef ModifierSourceEntry = ({String label, int value});

/// Oeffnet den kombinierten Detail- und Bearbeitungsdialog fuer Basiswert-
/// Modifikatoren.
///
/// [statLabel]: Anzeigename des Basiswerts (z.B. "LeP", "MR").
/// [namedModifiers]: Vom Benutzer gepflegte benannte Modifikatoren.
/// [parsedSources]: Read-only Quellen, wenn keine [herleitung] vorliegt.
/// [total]: Aktueller Gesamtmodifikator (fuer Anzeige).
/// [herleitung]: Herleitung des Regelmoduls (ARCH-04); ersetzt die Quellen
/// und zeigt Rechenweg und Ergebnis des gespeicherten Stands.
///
/// Gibt die bearbeitete Liste zurueck, oder `null` bei Abbruch.
Future<List<HeroTalentModifier>?> showStatModifierDetailDialog({
  required BuildContext context,
  required String statLabel,
  required List<HeroTalentModifier> namedModifiers,
  List<ModifierSourceEntry> parsedSources = const <ModifierSourceEntry>[],
  required int total,
  Herleitung? herleitung,
}) {
  return showAdaptiveDetailSheet<List<HeroTalentModifier>>(
    context: context,
    builder: (_) => ModifierDetailDialog(
      label: statLabel,
      keyPrefix: 'stat',
      ergebnisBezeichnung: statLabel,
      zusammenfassung: [(label: 'Gesamt', value: total, fett: true)],
      namedModifiers: namedModifiers,
      parsedSources: parsedSources,
      herleitung: herleitung,
    ),
  );
}

/// Zeile der Zusammenfassung unter den Quellen, wenn keine Herleitung vorliegt.
typedef ModifierZusammenfassung = ({String label, int value, bool fett});

/// Gemeinsamer Detail- und Bearbeitungsdialog für benannte Modifikatoren von
/// Basiswerten und Eigenschaften.
///
/// [label] steht im Titel, [keyPrefix] ('stat' oder 'attr') bildet die
/// Schlüssel der Felder und Knöpfe, [ergebnisBezeichnung] beschriftet die
/// Ergebniszeile der Herleitung und [zusammenfassung] zeigt ohne Herleitung
/// die Summenzeilen.
class ModifierDetailDialog extends StatefulWidget {
  /// Erzeugt den Dialog; die Ergebnisse liefern die Aufrufer.
  const ModifierDetailDialog({
    super.key,
    required this.label,
    required this.keyPrefix,
    required this.ergebnisBezeichnung,
    required this.zusammenfassung,
    required this.namedModifiers,
    required this.parsedSources,
    required this.herleitung,
  });

  /// Anzeigename von Basiswert oder Eigenschaft.
  final String label;

  /// Präfix der Schlüssel ('stat' oder 'attr').
  final String keyPrefix;

  /// Beschriftung der Ergebniszeile der Herleitung.
  final String ergebnisBezeichnung;

  /// Summenzeilen, wenn keine [herleitung] vorliegt.
  final List<ModifierZusammenfassung> zusammenfassung;

  /// Vom Benutzer gepflegte benannte Modifikatoren.
  final List<HeroTalentModifier> namedModifiers;

  /// Read-only Quellen, wenn keine [herleitung] vorliegt.
  final List<ModifierSourceEntry> parsedSources;

  /// Herleitung des Regelmoduls (ARCH-04).
  final Herleitung? herleitung;

  @override
  State<ModifierDetailDialog> createState() => _ModifierDetailDialogState();
}

class _ModifierDetailDialogState extends State<ModifierDetailDialog> {
  late List<TextEditingController> _modifierControllers;
  late List<TextEditingController> _descriptionControllers;

  // Bearbeitete Eintraege je Zeile, `null` fuer neue; ueber sie bleiben
  // unbekannte Felder beim Speichern erhalten.
  late List<HeroTalentModifier?> _originale;

  @override
  void initState() {
    super.initState();
    _modifierControllers = widget.namedModifiers
        .map((entry) => TextEditingController(text: entry.modifier.toString()))
        .toList(growable: true);
    _descriptionControllers = widget.namedModifiers
        .map((entry) => TextEditingController(text: entry.description))
        .toList(growable: true);
    _originale = List<HeroTalentModifier?>.of(widget.namedModifiers);
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
      _originale = List<HeroTalentModifier?>.of(_originale)..add(null);
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
      _originale = List<HeroTalentModifier?>.of(_originale)..removeAt(index);
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
      final original = _originale[index];
      modifiers.add(
        original == null
            ? HeroTalentModifier(modifier: modifier, description: description)
            : original.copyWith(modifier: modifier, description: description),
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
                key: ValueKey<String>(
                  '${widget.keyPrefix}-modifier-value-$index',
                ),
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
                key: ValueKey<String>(
                  '${widget.keyPrefix}-modifier-description-$index',
                ),
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

    final herleitung = widget.herleitung;
    // Read-only Quellen (nur Nicht-Null-Werte anzeigen).
    final nonZeroSources = widget.parsedSources
        .where((entry) => entry.value != 0)
        .toList();

    return AlertDialog(
      title: Text('Modifikatoren: ${widget.label}'),
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
                  key: ValueKey<String>('${widget.keyPrefix}-modifiers-add'),
                  onPressed: _addModifierField,
                  icon: const Icon(Icons.add),
                  label: const Text('Modifikator hinzufuegen'),
                ),
              ),
              if (herleitung != null) ...[
                const SizedBox(height: kDialogSectionSpacing),
                HerleitungsAbschnitt(
                  herleitung: herleitung,
                  ergebnisBezeichnung: widget.ergebnisBezeichnung,
                  ergebnisKey: ValueKey<String>(
                    '${widget.keyPrefix}-herleitung-ergebnis',
                  ),
                ),
              ] else ...[
                if (nonZeroSources.isNotEmpty) ...[
                  const SizedBox(height: kDialogSectionSpacing),
                  _sectionTitle(theme, 'Automatisch (nur Anzeige)'),
                  ...nonZeroSources.map(
                    (entry) => _sourceRow(theme, entry.label, entry.value),
                  ),
                ],
                const Divider(height: kDialogSectionSpacing * 2),
                for (final zeile in widget.zusammenfassung)
                  _sourceRow(theme, zeile.label, zeile.value, bold: zeile.fett),
              ],
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
          key: ValueKey<String>('${widget.keyPrefix}-modifiers-save'),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: labelStyle)),
          Text(mitVorzeichen(value, nullText: '+0'), style: style),
        ],
      ),
    );
  }
}
