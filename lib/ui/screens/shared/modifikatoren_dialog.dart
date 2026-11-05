import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview/herleitung_abschnitt.dart';

/// Eintrag fuer eine read-only Modifikatorquelle im Detail-Dialog.
typedef ModifierSourceEntry = ({String label, int value});

/// Abschlusszeile unter den Quellen, wenn keine Herleitung vorliegt.
typedef ModifikatorSummenZeile = ({String label, int value, bool fett});

/// Gemeinsamer Bearbeitungsdialog fuer benannte Modifikatoren
/// (`HeroTalentModifier`) an Eigenschaften, Basiswerten und Talenten.
///
/// [schluesselPrefix] bildet die Widget-Keys (`<prefix>-modifier-value-<i>`,
/// `<prefix>-modifier-description-<i>`, `<prefix>-modifiers-add`,
/// `<prefix>-modifiers-save`, `<prefix>-herleitung-ergebnis`).
///
/// Ohne [herleitung] zeigt der Dialog die [quellen] (nur Nicht-Null-Werte)
/// und darunter die [summenZeilen]. [abschnittTitel] steht ueber der
/// bearbeitbaren Liste, wenn gesetzt.
///
/// Liefert die bearbeitete Liste oder `null` bei Abbruch. Bestehende
/// Eintraege werden per `copyWith` fortgeschrieben, damit unbekannte Felder
/// erhalten bleiben.
Future<List<HeroTalentModifier>?> showModifikatorenDialog({
  required BuildContext context,
  required String bezeichnung,
  required String schluesselPrefix,
  required List<HeroTalentModifier> modifikatoren,
  String? abschnittTitel,
  String leerText = 'Keine eigenen Modifikatoren vorhanden.',
  Herleitung? herleitung,
  String ergebnisBezeichnung = 'Ergebnis',
  List<ModifierSourceEntry> quellen = const <ModifierSourceEntry>[],
  List<ModifikatorSummenZeile> summenZeilen = const <ModifikatorSummenZeile>[],
}) {
  return showAdaptiveDetailSheet<List<HeroTalentModifier>>(
    context: context,
    builder: (_) => _ModifikatorenDialog(
      bezeichnung: bezeichnung,
      schluesselPrefix: schluesselPrefix,
      modifikatoren: modifikatoren,
      abschnittTitel: abschnittTitel,
      leerText: leerText,
      herleitung: herleitung,
      ergebnisBezeichnung: ergebnisBezeichnung,
      quellen: quellen,
      summenZeilen: summenZeilen,
    ),
  );
}

class _ModifikatorenDialog extends StatefulWidget {
  const _ModifikatorenDialog({
    required this.bezeichnung,
    required this.schluesselPrefix,
    required this.modifikatoren,
    required this.abschnittTitel,
    required this.leerText,
    required this.herleitung,
    required this.ergebnisBezeichnung,
    required this.quellen,
    required this.summenZeilen,
  });

  final String bezeichnung;
  final String schluesselPrefix;
  final List<HeroTalentModifier> modifikatoren;
  final String? abschnittTitel;
  final String leerText;
  final Herleitung? herleitung;
  final String ergebnisBezeichnung;
  final List<ModifierSourceEntry> quellen;
  final List<ModifikatorSummenZeile> summenZeilen;

  @override
  State<_ModifikatorenDialog> createState() => _ModifikatorenDialogState();
}

class _ModifikatorenDialogState extends State<_ModifikatorenDialog> {
  late List<TextEditingController> _modifierControllers;
  late List<TextEditingController> _descriptionControllers;

  // Bearbeitete Eintraege je Zeile, `null` fuer neue; ueber sie bleiben
  // unbekannte Felder beim Speichern erhalten.
  late List<HeroTalentModifier?> _originale;

  String get _p => widget.schluesselPrefix;

  @override
  void initState() {
    super.initState();
    _modifierControllers = widget.modifikatoren
        .map((entry) => TextEditingController(text: entry.modifier.toString()))
        .toList(growable: true);
    _descriptionControllers = widget.modifikatoren
        .map((entry) => TextEditingController(text: entry.description))
        .toList(growable: true);
    _originale = List<HeroTalentModifier?>.of(widget.modifikatoren);
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
                key: ValueKey<String>('$_p-modifier-value-$index'),
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
                key: ValueKey<String>('$_p-modifier-description-$index'),
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
    final nonZeroSources = widget.quellen
        .where((entry) => entry.value != 0)
        .toList();
    final abschnittTitel = widget.abschnittTitel;

    return AlertDialog(
      title: Text('Modifikatoren: ${widget.bezeichnung}'),
      content: SizedBox(
        width: kDialogWidthLarge,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (abschnittTitel != null) _sectionTitle(theme, abschnittTitel),
              if (modifierFields.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: kDialogFieldSpacing),
                  child: Text(widget.leerText),
                )
              else
                ...modifierFields,
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: ValueKey<String>('$_p-modifiers-add'),
                  onPressed: _addModifierField,
                  icon: const Icon(Icons.add),
                  label: const Text('Modifikator hinzufügen'),
                ),
              ),
              if (herleitung != null) ...[
                const SizedBox(height: kDialogSectionSpacing),
                HerleitungsAbschnitt(
                  herleitung: herleitung,
                  ergebnisBezeichnung: widget.ergebnisBezeichnung,
                  ergebnisKey: ValueKey<String>('$_p-herleitung-ergebnis'),
                ),
              ] else ...[
                if (nonZeroSources.isNotEmpty) ...[
                  const SizedBox(height: kDialogSectionSpacing),
                  _sectionTitle(theme, 'Automatisch (nur Anzeige)'),
                  ...nonZeroSources.map(
                    (entry) => _sourceRow(theme, entry.label, entry.value),
                  ),
                ],
                if (widget.summenZeilen.isNotEmpty) ...[
                  const Divider(height: kDialogSectionSpacing * 2),
                  for (final zeile in widget.summenZeilen)
                    _sourceRow(
                      theme,
                      zeile.label,
                      zeile.value,
                      bold: zeile.fett,
                    ),
                ],
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
          key: ValueKey<String>('$_p-modifiers-save'),
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
          SizedBox(width: 140, child: Text(label, style: labelStyle)),
          Text('$sign$value', style: style),
        ],
      ),
    );
  }
}
