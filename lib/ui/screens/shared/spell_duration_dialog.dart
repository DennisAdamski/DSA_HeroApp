import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/spell_duration_field.dart';

/// Ergebnis der Wirkungsdauer-Eingabe.
///
/// Ein eigener Typ ist noetig, weil `null` als Rueckgabewert bereits "Dialog
/// abgebrochen" bedeutet und davon unterschieden werden muss, dass der Nutzer
/// die Wirkungsdauer bewusst entfernt hat.
class SpellDurationDialogResult {
  /// Erstellt ein Ergebnis; [duration] ist `null`, wenn keine erfasst wurde.
  const SpellDurationDialogResult(this.duration);

  /// Die eingegebene Wirkungsdauer oder `null`.
  final SpellDuration? duration;
}

/// Fragt die Wirkungsdauer eines laufenden Zaubereffekts ab.
///
/// [spellLabel] benennt den Zauber im Titel, [defaultUnit] belegt die
/// Zeiteinheit passend zur Zauberbeschreibung vor.
Future<SpellDurationDialogResult?> showSpellDurationDialog({
  required BuildContext context,
  required String spellLabel,
  SpellDuration? initialDuration,
  SpellDurationUnit defaultUnit = SpellDurationUnit.kampfrunden,
}) {
  return showAdaptiveInputDialog<SpellDurationDialogResult>(
    context: context,
    builder: (_) => _SpellDurationDialog(
      spellLabel: spellLabel,
      initialDuration: initialDuration,
      defaultUnit: defaultUnit,
    ),
  );
}

class _SpellDurationDialog extends StatefulWidget {
  const _SpellDurationDialog({
    required this.spellLabel,
    required this.defaultUnit,
    this.initialDuration,
  });

  final String spellLabel;
  final SpellDurationUnit defaultUnit;
  final SpellDuration? initialDuration;

  @override
  State<_SpellDurationDialog> createState() => _SpellDurationDialogState();
}

class _SpellDurationDialogState extends State<_SpellDurationDialog> {
  late SpellDuration? _duration = widget.initialDuration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdaptiveInputDialog(
      title: '${widget.spellLabel} – Wirkungsdauer',
      maxWidth: kDialogWidthSmall,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Trage die Wirkungsdauer so ein, wie der Zauber sie angibt. '
            'Ohne Menge läuft der Effekt ohne festes Ende weiter.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: kDialogSectionSpacing),
          SpellDurationField(
            fieldKeyPrefix: 'spell-duration-dialog',
            initialDuration: _duration,
            defaultUnit: widget.defaultUnit,
            onChanged: (value) => _duration = value,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('spell-duration-dialog-confirm'),
          onPressed: () =>
              Navigator.of(context).pop(SpellDurationDialogResult(_duration)),
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}
