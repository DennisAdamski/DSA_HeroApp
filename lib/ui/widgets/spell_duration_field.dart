import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_duration_rules.dart';
import 'package:dsa_heldenverwaltung/ui/config/ui_spacing.dart';

/// Eingabefeld fuer die Wirkungsdauer eines Zaubers: Menge plus Zeiteinheit.
///
/// Bewusst effektunabhaengig gehalten, damit jeder aktive Zaubereffekt
/// dieselbe Eingabe bekommt. Eine Menge von 0 bedeutet "keine Wirkungsdauer
/// erfasst"; der Aufrufer bekommt dann `null` gemeldet.
class SpellDurationField extends StatefulWidget {
  /// Erstellt das Eingabefeld mit optionaler Vorbelegung.
  const SpellDurationField({
    super.key,
    required this.onChanged,
    this.initialDuration,
    this.defaultUnit = SpellDurationUnit.kampfrunden,
    this.fieldKeyPrefix = 'spell-duration',
    this.label = 'Wirkungsdauer',
  });

  /// Meldet die geaenderte Wirkungsdauer; `null` bei leerer Eingabe.
  final ValueChanged<SpellDuration?> onChanged;

  /// Vorbelegte Wirkungsdauer, z. B. beim Nachbearbeiten eines Effekts.
  final SpellDuration? initialDuration;

  /// Zeiteinheit, die ohne Vorbelegung ausgewaehlt ist.
  final SpellDurationUnit defaultUnit;

  /// Praefix fuer die Widget-Keys, damit mehrere Felder testbar bleiben.
  final String fieldKeyPrefix;

  /// Beschriftung des Mengenfelds.
  final String label;

  @override
  State<SpellDurationField> createState() => _SpellDurationFieldState();
}

class _SpellDurationFieldState extends State<SpellDurationField> {
  late final TextEditingController _amountController;
  late SpellDurationUnit _unit;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDuration;
    _amountController = TextEditingController(
      text: initial == null || initial.amount <= 0 ? '' : '${initial.amount}',
    );
    _unit = initial?.unit ?? widget.defaultUnit;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  /// Baut die aktuelle Eingabe zusammen und meldet sie nach oben.
  void _emit() {
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    // Permanente Wirkungsdauern brauchen keine Menge, alle anderen schon.
    final isPermanent = _unit == SpellDurationUnit.permanent;
    if (amount <= 0 && !isPermanent) {
      widget.onChanged(null);
      return;
    }
    widget.onChanged(
      SpellDuration(amount: isPermanent && amount <= 0 ? 1 : amount, unit: _unit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPermanent = _unit == SpellDurationUnit.permanent;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: TextField(
            key: ValueKey<String>('${widget.fieldKeyPrefix}-amount'),
            controller: _amountController,
            enabled: !isPermanent,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              isDense: true,
              labelText: widget.label,
            ),
            onChanged: (_) => _emit(),
          ),
        ),
        const SizedBox(width: kDialogInlineSpacing),
        Expanded(
          child: DropdownButtonFormField<SpellDurationUnit>(
            key: ValueKey<String>('${widget.fieldKeyPrefix}-unit'),
            initialValue: _unit,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              labelText: 'Zeiteinheit',
            ),
            items: [
              for (final unit in SpellDurationUnit.values)
                DropdownMenuItem<SpellDurationUnit>(
                  value: unit,
                  child: Text(spellDurationUnitLabel(unit)),
                ),
            ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() => _unit = value);
              _emit();
            },
          ),
        ),
      ],
    );
  }
}
