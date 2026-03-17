part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

class _AtPaVerteilungDialog extends StatefulWidget {
  const _AtPaVerteilungDialog({
    required this.talentName,
    required this.delta,
    required this.currentAt,
    required this.currentPa,
    required this.neuerWert,
  });

  final String talentName;
  final int delta;
  final int currentAt;
  final int currentPa;
  final int neuerWert;

  @override
  State<_AtPaVerteilungDialog> createState() => _AtPaVerteilungDialogState();
}

class _AtPaVerteilungDialogState extends State<_AtPaVerteilungDialog> {
  late int _atDelta;

  @override
  void initState() {
    super.initState();
    _atDelta = widget.delta;
  }

  @override
  Widget build(BuildContext context) {
    final paDelta = widget.delta - _atDelta;
    return AlertDialog(
      title: Text('AT/PA-Verteilung: ${widget.talentName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Neuer TaW: ${widget.neuerWert}  '
            '(+${widget.delta} ${widget.delta == 1 ? 'Punkt' : 'Punkte'})',
          ),
          const SizedBox(height: 16),
          Slider(
            min: 0,
            max: widget.delta.toDouble(),
            divisions: widget.delta,
            value: _atDelta.toDouble(),
            label: 'AT +$_atDelta',
            onChanged: (v) => setState(() => _atDelta = v.round()),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Text('AT'),
                  Text(
                    '${widget.currentAt} \u2192 ${widget.currentAt + _atDelta}',
                  ),
                ],
              ),
              Column(
                children: [
                  const Text('PA'),
                  Text(
                    '${widget.currentPa} \u2192 ${widget.currentPa + paDelta}',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_atDelta),
          child: const Text('\u00dcbernehmen'),
        ),
      ],
    );
  }
}
