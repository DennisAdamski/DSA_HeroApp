import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
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
  final TextEditingController _zfpController = TextEditingController();

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
    _zfpController.dispose();
    super.dispose();
  }

  int _readInt(int index) {
    final parsed = int.tryParse(_controllers[index].text.trim()) ?? 0;
    return parsed.clamp(-99, 99);
  }

  // Regelwert aus den ZfP*: ZfP*/3, aufgerundet (LC S. 30, Tischregel).
  String _zfpHinweis() {
    final zfp = int.tryParse(_zfpController.text.trim());
    if (zfp == null) {
      return 'Bonus laut Regelwerk: ZfP*/3 (aufgerundet) auf die gesteigerte '
          'Eigenschaft.';
    }
    return 'Bonus laut Regelwerk: ${attributoBonusAusZfp(zfp)} '
        '(ZfP*/3, aufgerundet).';
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
              child: Text(abbr, style: theme.textTheme.titleSmall),
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
          Row(
            children: [
              SizedBox(
                width: 80,
                child: TextField(
                  key: const ValueKey<String>('attributo-input-zfp'),
                  controller: _zfpController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    labelText: 'ZfP*',
                  ),
                  textAlign: TextAlign.center,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: kDialogInlineSpacing),
              Expanded(
                child: Text(
                  key: const ValueKey<String>('attributo-input-zfp-hint'),
                  _zfpHinweis(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
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
