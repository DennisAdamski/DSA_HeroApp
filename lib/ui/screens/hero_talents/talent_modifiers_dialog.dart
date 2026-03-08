part of 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';

/// Oeffnet den Dialog zur Bearbeitung mehrerer Talent-Modifikatorbausteine.
Future<List<HeroTalentModifier>?> _showTalentModifiersDialog({
  required BuildContext context,
  required String talentName,
  required List<HeroTalentModifier> initialModifiers,
}) {
  return showDialog<List<HeroTalentModifier>>(
    context: context,
    builder: (_) => _TalentModifiersDialog(
      talentName: talentName,
      initialModifiers: initialModifiers,
    ),
  );
}

/// Dialog fuer beliebig viele Talent-Modifikatorbausteine.
class _TalentModifiersDialog extends StatefulWidget {
  const _TalentModifiersDialog({
    required this.talentName,
    required this.initialModifiers,
  });

  final String talentName;
  final List<HeroTalentModifier> initialModifiers;

  @override
  State<_TalentModifiersDialog> createState() => _TalentModifiersDialogState();
}

class _TalentModifiersDialogState extends State<_TalentModifiersDialog> {
  late List<TextEditingController> _modifierControllers;
  late List<TextEditingController> _descriptionControllers;

  @override
  void initState() {
    super.initState();
    _modifierControllers = widget.initialModifiers
        .map(
          (entry) => TextEditingController(text: entry.modifier.toString()),
        )
        .toList(growable: true);
    _descriptionControllers = widget.initialModifiers
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
      final modifier = int.tryParse(_modifierControllers[index].text.trim()) ?? 0;
      modifiers.add(
        HeroTalentModifier(modifier: modifier, description: description),
      );
    }
    return modifiers;
  }

  @override
  Widget build(BuildContext context) {
    final modifierFields = <Widget>[];
    for (var index = 0; index < _modifierControllers.length; index++) {
      modifierFields.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: TextField(
                key: ValueKey<String>('talent-modifier-value-$index'),
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
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: ValueKey<String>('talent-modifier-description-$index'),
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
            const SizedBox(width: 8),
            IconButton(
              onPressed: () => _removeModifierField(index),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Modifikator entfernen',
            ),
          ],
        ),
      );
      modifierFields.add(const SizedBox(height: 8));
    }

    return AlertDialog(
      title: Text('Modifikatoren: ${widget.talentName}'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (modifierFields.isEmpty)
                const Text('Keine Modifikatoren vorhanden.')
              else
                ...modifierFields,
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const ValueKey<String>('talent-modifiers-add'),
                  onPressed: _addModifierField,
                  icon: const Icon(Icons.add),
                  label: const Text('Modifikator hinzufuegen'),
                ),
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
          key: const ValueKey<String>('talent-modifiers-save'),
          onPressed: () => Navigator.of(context).pop(_buildModifiers()),
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
