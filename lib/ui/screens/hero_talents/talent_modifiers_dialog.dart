part of 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';

/// Oeffnet den Dialog zur Bearbeitung mehrerer Talent-Modifikatorbausteine.
Future<List<HeroTalentModifier>?> _showTalentModifiersDialog({
  required BuildContext context,
  required String talentName,
  required List<HeroTalentModifier> initialModifiers,
}) {
  return showAdaptiveDetailSheet<List<HeroTalentModifier>>(
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
  late final ModifierListController _modifiers;

  @override
  void initState() {
    super.initState();
    _modifiers = ModifierListController(widget.initialModifiers);
  }

  @override
  void dispose() {
    _modifiers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Modifikatoren: ${widget.talentName}'),
      content: SizedBox(
        width: kDialogWidthLarge,
        child: SingleChildScrollView(
          child: ModifierListEditor(
            controller: _modifiers,
            keyPrefix: 'talent-modifier',
            addButtonKey: const ValueKey<String>('talent-modifiers-add'),
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
          onPressed: () =>
              Navigator.of(context).pop(_modifiers.buildModifiers()),
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
