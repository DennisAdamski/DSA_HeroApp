import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';

/// Einmaliger Dialog zur Aktivierung des epischen Status.
///
/// Der Spieler verteilt 5 Punkte auf die acht Grundeigenschaften
/// (maximal +2 pro Eigenschaft). Das Ergebnis ist unveraenderlich.
class EpicActivationDialog extends StatefulWidget {
  const EpicActivationDialog({super.key});

  @override
  State<EpicActivationDialog> createState() => _EpicActivationDialogState();
}

class _EpicActivationDialogState extends State<EpicActivationDialog> {
  static const int _maxTotal = 5;
  static const int _maxPerAttr = 2;

  static const List<(String, String)> _attrs = [
    ('Mut', 'mu'),
    ('Klugheit', 'kl'),
    ('Intuition', 'inn'),
    ('Charisma', 'ch'),
    ('Fingerfertigkeit', 'ff'),
    ('Gewandtheit', 'ge'),
    ('Konstitution', 'ko'),
    ('Körperkraft', 'kk'),
  ];

  final Map<String, int> _bonus = {
    'mu': 0, 'kl': 0, 'inn': 0, 'ch': 0,
    'ff': 0, 'ge': 0, 'ko': 0, 'kk': 0,
  };

  int get _totalUsed => _bonus.values.fold(0, (a, b) => a + b);
  int get _remaining => _maxTotal - _totalUsed;

  void _adjust(String key, int delta) {
    final current = _bonus[key]!;
    final next = current + delta;
    if (next < 0 || next > _maxPerAttr) return;
    if (delta > 0 && _remaining <= 0) return;
    setState(() => _bonus[key] = next);
  }

  Attributes _buildResult() {
    return Attributes(
      mu: _bonus['mu']!,
      kl: _bonus['kl']!,
      inn: _bonus['inn']!,
      ch: _bonus['ch']!,
      ff: _bonus['ff']!,
      ge: _bonus['ge']!,
      ko: _bonus['ko']!,
      kk: _bonus['kk']!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = _remaining;

    return AlertDialog(
      title: const Text('Epischen Status aktivieren'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verteile $remaining von $_maxTotal Punkten auf die Eigenschafts-Obergrenzen '
              '(max. +$_maxPerAttr pro Eigenschaft). Diese Auswahl ist unveränderlich.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ..._attrs.map((entry) {
              final label = entry.$1;
              final key = entry.$2;
              final value = _bonus[key]!;
              final canIncrease = value < _maxPerAttr && remaining > 0;
              final canDecrease = value > 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(label, style: theme.textTheme.bodyMedium),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove),
                      iconSize: 18,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      onPressed: canDecrease ? () => _adjust(key, -1) : null,
                    ),
                    SizedBox(
                      width: 28,
                      child: Text(
                        '+$value',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: value > 0
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      iconSize: 18,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      onPressed: canIncrease ? () => _adjust(key, 1) : null,
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Text(
              'Vergeben: $_totalUsed / $_maxTotal Punkte',
              style: theme.textTheme.bodySmall?.copyWith(
                color: _remaining == 0
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_buildResult()),
          child: const Text('Aktivieren'),
        ),
      ],
    );
  }
}
