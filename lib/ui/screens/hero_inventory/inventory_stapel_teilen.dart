import 'package:flutter/material.dart';

/// Wahl im Dialog „Stapel teilen“.
class StapelTeilung {
  /// [anzahl] Stück kommen in einen neuen Stapel nach [woGetragen].
  const StapelTeilung({required this.anzahl, required this.woGetragen});

  /// Stückzahl des neuen Stapels.
  final int anzahl;

  /// Ort des neuen Stapels.
  final String woGetragen;
}

/// Fragt, wie viele Stück eines Stapels mit [menge] Stück abgespalten werden
/// und wohin.
///
/// Der Dialog schließt sich selbst und liefert die Wahl, bei Abbruch `null`.
Future<StapelTeilung?> zeigeStapelTeilenDialog(
  BuildContext context, {
  required String name,
  required int menge,
  required String woGetragen,
}) {
  return showDialog<StapelTeilung>(
    context: context,
    builder: (_) =>
        _StapelTeilenDialog(name: name, menge: menge, woGetragen: woGetragen),
  );
}

class _StapelTeilenDialog extends StatefulWidget {
  const _StapelTeilenDialog({
    required this.name,
    required this.menge,
    required this.woGetragen,
  });

  final String name;
  final int menge;
  final String woGetragen;

  @override
  State<_StapelTeilenDialog> createState() => _StapelTeilenDialogState();
}

class _StapelTeilenDialogState extends State<_StapelTeilenDialog> {
  late int _anzahl = widget.menge ~/ 2;
  late final TextEditingController _ort = TextEditingController(
    text: widget.woGetragen,
  );

  @override
  void dispose() {
    _ort.dispose();
    super.dispose();
  }

  void _setze(int wert) =>
      setState(() => _anzahl = wert.clamp(1, widget.menge - 1));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Stapel teilen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.name}: ${widget.menge} Stück'),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: Text('Neuer Stapel')),
              IconButton(
                key: const ValueKey<String>('stapel-teilen-minus'),
                tooltip: 'Ein Stück weniger',
                onPressed: _anzahl > 1 ? () => _setze(_anzahl - 1) : null,
                icon: const Icon(Icons.remove),
              ),
              Text(
                '$_anzahl',
                key: const ValueKey<String>('stapel-teilen-anzahl'),
                style: theme.textTheme.titleMedium,
              ),
              IconButton(
                key: const ValueKey<String>('stapel-teilen-plus'),
                tooltip: 'Ein Stück mehr',
                onPressed: _anzahl < widget.menge - 1
                    ? () => _setze(_anzahl + 1)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          Text(
            'Im bisherigen Stapel bleiben ${widget.menge - _anzahl} Stück.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey<String>('stapel-teilen-ort'),
            controller: _ort,
            decoration: const InputDecoration(
              labelText: 'Wo getragen (neuer Stapel)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ungespeicherte Änderungen im Editor gehen dabei verloren.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('stapel-teilen-ok'),
          onPressed: () => Navigator.of(
            context,
          ).pop(StapelTeilung(anzahl: _anzahl, woGetragen: _ort.text.trim())),
          child: const Text('Teilen'),
        ),
      ],
    );
  }
}
