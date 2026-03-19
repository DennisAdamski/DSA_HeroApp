import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Leichtgewichtiger Dialog zum Wuerfeln oder manuellen Eingeben
/// des 2W6-INI-Malus bei einer neuen Kopfwunde.
///
/// Gibt den gewuerfelten oder eingegebenen Wert (2-12) zurueck,
/// oder `null` bei Abbruch.
Future<int?> showWundIniDialog(BuildContext context) {
  return showDialog<int>(
    context: context,
    builder: (_) => const _WundIniDialog(),
  );
}

class _WundIniDialog extends StatefulWidget {
  const _WundIniDialog();

  @override
  State<_WundIniDialog> createState() => _WundIniDialogState();
}

class _WundIniDialogState extends State<_WundIniDialog> {
  static final _rng = Random();

  int? _ergebnis;
  bool _manuell = false;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _wuerfeln() {
    final w1 = _rng.nextInt(6) + 1;
    final w2 = _rng.nextInt(6) + 1;
    setState(() {
      _ergebnis = w1 + w2;
      _manuell = false;
    });
  }

  void _aufManuellWechseln() {
    setState(() {
      _manuell = true;
      _ergebnis = null;
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kopfwunde: INI-Malus'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Wie hoch ist der INI-Malus (2W6)?'),
          const SizedBox(height: 16),
          if (!_manuell) ...[
            FilledButton.icon(
              onPressed: _wuerfeln,
              icon: const Icon(Icons.casino),
              label: const Text('Würfeln (2W6)'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _aufManuellWechseln,
              child: const Text('Manuell eingeben'),
            ),
            if (_ergebnis != null) ...[
              const SizedBox(height: 12),
              Text(
                '$_ergebnis',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ] else ...[
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'INI-Malus (2–12)',
                border: OutlineInputBorder(),
              ),
              onChanged: (raw) {
                final v = int.tryParse(raw.trim());
                setState(() {
                  _ergebnis = (v != null && v >= 2 && v <= 12) ? v : null;
                });
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _manuell = false),
              child: const Text('Zurück zum Würfeln'),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop<int>(null),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _ergebnis != null
              ? () => Navigator.of(context).pop<int>(_ergebnis)
              : null,
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}
