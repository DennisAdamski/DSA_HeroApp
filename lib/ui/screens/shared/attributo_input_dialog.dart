import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';

/// Oeffnet den Eingabedialog fuer Attributo-Boni.
///
/// Gibt die eingegebenen Eigenschaftsboni als [AttributeModifiers] zurueck,
/// oder `null` wenn der Benutzer abbricht.
Future<AttributeModifiers?> showAttributoInputDialog({
  required BuildContext context,
}) {
  return showAdaptiveInputDialog<AttributeModifiers>(
    context: context,
    builder: (_) => const _AttributoInputDialog(),
  );
}

class _AttributoInputDialog extends StatefulWidget {
  const _AttributoInputDialog();

  @override
  State<_AttributoInputDialog> createState() => _AttributoInputDialogState();
}

class _AttributoInputDialogState extends State<_AttributoInputDialog> {
  static const List<(String, String)> _attributes = [
    ('MU', 'Mut'),
    ('KL', 'Klugheit'),
    ('INN', 'Intuition'),
    ('CH', 'Charisma'),
    ('FF', 'Fingerfertigkeit'),
    ('GE', 'Gewandtheit'),
    ('KO', 'Konstitution'),
    ('KK', 'Körperkraft'),
  ];

  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      _attributes.length,
      (_) => TextEditingController(text: '0'),
      growable: false,
    );
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  int _readInt(int index) {
    final parsed = int.tryParse(_controllers[index].text.trim()) ?? 0;
    return parsed.clamp(-99, 99);
  }

  AttributeModifiers _buildResult() {
    return AttributeModifiers(
      mu: _readInt(0),
      kl: _readInt(1),
      inn: _readInt(2),
      ch: _readInt(3),
      ff: _readInt(4),
      ge: _readInt(5),
      ko: _readInt(6),
      kk: _readInt(7),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final rows = <Widget>[];
    for (var i = 0; i < _attributes.length; i++) {
      final (abbr, label) = _attributes[i];
      rows.add(
        Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(
                abbr,
                style: theme.textTheme.titleSmall,
              ),
            ),
            const SizedBox(width: kDialogInlineSpacing),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: kDialogInlineSpacing),
            SizedBox(
              width: 80,
              child: TextField(
                key: ValueKey<String>('attributo-input-$abbr'),
                controller: _controllers[i],
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'-?\d*')),
                ],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  labelText: 'Bonus',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
      if (i < _attributes.length - 1) {
        rows.add(const SizedBox(height: kDialogInlineSpacing));
      }
    }

    return AdaptiveInputDialog(
      title: 'Attributo – Boni eingeben',
      maxWidth: kDialogWidthSmall,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Gib die temporären Boni für jede Eigenschaft ein (0 für keine Änderung).',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: kDialogSectionSpacing),
          ...rows,
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('attributo-input-confirm'),
          onPressed: () => Navigator.of(context).pop(_buildResult()),
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}
