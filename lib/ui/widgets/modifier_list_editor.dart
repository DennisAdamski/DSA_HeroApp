import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';

/// Haelt die Eingabe-Controller fuer eine editierbare Modifikatorliste.
///
/// Der Besitzer (typischerweise der State eines Dialogs) erzeugt den
/// Controller in `initState`, ruft beim Speichern [buildModifiers] auf und
/// gibt ihn in `dispose` wieder frei.
class ModifierListController {
  ModifierListController(List<HeroTalentModifier> initialModifiers)
    : _modifierControllers = initialModifiers
          .map(
            (entry) => TextEditingController(text: entry.modifier.toString()),
          )
          .toList(growable: true),
      _descriptionControllers = initialModifiers
          .map((entry) => TextEditingController(text: entry.description))
          .toList(growable: true);

  List<TextEditingController> _modifierControllers;
  List<TextEditingController> _descriptionControllers;

  /// Anzahl der aktuell editierbaren Modifikatorzeilen.
  int get length => _modifierControllers.length;

  void _add() {
    _modifierControllers = List<TextEditingController>.from(
      _modifierControllers,
    )..add(TextEditingController(text: '0'));
    _descriptionControllers = List<TextEditingController>.from(
      _descriptionControllers,
    )..add(TextEditingController());
  }

  void _removeAt(int index) {
    final modifierController = _modifierControllers[index];
    final descriptionController = _descriptionControllers[index];
    _modifierControllers = List<TextEditingController>.from(
      _modifierControllers,
    )..removeAt(index);
    _descriptionControllers = List<TextEditingController>.from(
      _descriptionControllers,
    )..removeAt(index);
    modifierController.dispose();
    descriptionController.dispose();
  }

  /// Baut die Modifikatorliste aus den aktuellen Eingaben.
  ///
  /// Zeilen mit leerer Beschreibung werden verworfen; nicht parsebare
  /// Modifikatorwerte ergeben 0.
  List<HeroTalentModifier> buildModifiers() {
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

  /// Gibt alle Eingabe-Controller frei.
  void dispose() {
    for (final controller in _modifierControllers) {
      controller.dispose();
    }
    for (final controller in _descriptionControllers) {
      controller.dispose();
    }
  }
}

/// Editierbare Liste aus (Modifikator, Beschreibung)-Zeilen mit Add-Button.
///
/// Die Feld-Keys werden als `'<keyPrefix>-value-<index>'` bzw.
/// `'<keyPrefix>-description-<index>'` erzeugt und muessen pro Verwendung
/// stabil bleiben, da Widget-Tests sie referenzieren.
class ModifierListEditor extends StatefulWidget {
  const ModifierListEditor({
    super.key,
    required this.controller,
    required this.keyPrefix,
    required this.addButtonKey,
    this.emptyPlaceholder = const Text('Keine Modifikatoren vorhanden.'),
  });

  final ModifierListController controller;
  final String keyPrefix;
  final Key addButtonKey;
  final Widget emptyPlaceholder;

  @override
  State<ModifierListEditor> createState() => _ModifierListEditorState();
}

class _ModifierListEditorState extends State<ModifierListEditor> {
  void _addModifierField() {
    setState(() => widget.controller._add());
  }

  void _removeModifierField(int index) {
    setState(() => widget.controller._removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final modifierFields = <Widget>[];
    for (var index = 0; index < controller.length; index++) {
      modifierFields.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: TextField(
                key: ValueKey<String>('${widget.keyPrefix}-value-$index'),
                controller: controller._modifierControllers[index],
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
                key: ValueKey<String>('${widget.keyPrefix}-description-$index'),
                controller: controller._descriptionControllers[index],
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (modifierFields.isEmpty)
          widget.emptyPlaceholder
        else
          ...modifierFields,
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: widget.addButtonKey,
            onPressed: _addModifierField,
            icon: const Icon(Icons.add),
            label: const Text('Modifikator hinzufügen'),
          ),
        ),
      ],
    );
  }
}
