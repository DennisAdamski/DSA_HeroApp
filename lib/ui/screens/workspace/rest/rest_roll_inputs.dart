part of '../rest_dialog.dart';

enum _RestRollMode { digital, manual }

/// Eingabezustand eines Wurfs: digital gewürfelt oder von Hand eingetragen.
class _RestRollInput {
  _RestRollMode mode = _RestRollMode.digital;
  String manual = '';
  int? digital;

  /// Gültiger Wert des Wurfs oder `null`, solange keiner vorliegt.
  int? get value =>
      mode == _RestRollMode.digital ? digital : int.tryParse(manual.trim());
}

/// Umschalter Digital/Manuell samt Würfelknopf bzw. Eingabefeld.
class _RestRollModeInput extends StatelessWidget {
  const _RestRollModeInput({
    required this.input,
    required this.keyPrefix,
    required this.manualLabel,
    required this.onModeChanged,
    required this.onManualChanged,
    required this.onRoll,
  });

  final _RestRollInput input;
  final String keyPrefix;
  final String manualLabel;
  final ValueChanged<_RestRollMode> onModeChanged;
  final ValueChanged<String> onManualChanged;
  final VoidCallback onRoll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<_RestRollMode>(
          segments: const <ButtonSegment<_RestRollMode>>[
            ButtonSegment<_RestRollMode>(
              value: _RestRollMode.digital,
              label: Text('Digital'),
            ),
            ButtonSegment<_RestRollMode>(
              value: _RestRollMode.manual,
              label: Text('Manuell'),
            ),
          ],
          selected: <_RestRollMode>{input.mode},
          onSelectionChanged: (selection) => onModeChanged(selection.first),
        ),
        const SizedBox(height: 8),
        if (input.mode == _RestRollMode.digital)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: ValueKey<String>('$keyPrefix-digital-roll'),
                onPressed: onRoll,
                icon: const Icon(Icons.casino_outlined),
                label: const Text('Würfeln'),
              ),
              Text(
                input.digital == null ? 'Noch kein Wurf' : '${input.digital}',
                key: ValueKey<String>('$keyPrefix-digital-value'),
              ),
            ],
          )
        else
          TextFormField(
            key: ValueKey<String>('$keyPrefix-manual'),
            initialValue: input.manual,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: manualLabel,
              border: const OutlineInputBorder(),
            ),
            onChanged: onManualChanged,
          ),
      ],
    );
  }
}

/// Summenwurf mit Beschriftung, etwa 3W6 Ausdauer oder 1W6 LeP.
class _RestRollField extends StatelessWidget {
  const _RestRollField({
    required this.label,
    required this.helperText,
    required this.modeInput,
  });

  final String label;
  final String helperText;
  final _RestRollModeInput Function(String manualLabel) modeInput;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(label), const SizedBox(height: 6), modeInput(helperText)],
    );
  }
}

/// W20-Probe mit Zielwert und angezeigtem Ergebnis.
class _RestProbeField extends StatelessWidget {
  const _RestProbeField({
    required this.label,
    required this.targetValue,
    required this.succeeded,
    required this.modeInput,
  });

  final String label;
  final int targetValue;
  final bool succeeded;
  final _RestRollModeInput Function(String manualLabel) modeInput;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label (Zielwert $targetValue)'),
        const SizedBox(height: 6),
        modeInput('1W20'),
        const SizedBox(height: 4),
        Text(succeeded ? 'Probe gelungen' : 'Probe nicht gelungen'),
      ],
    );
  }
}
