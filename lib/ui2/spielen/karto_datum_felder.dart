import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/aventurian_date.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';

/// Eingabe eines aventurischen Datums als Tag, Monat und Jahr.
///
/// Gemeinsamer Baustein der Dialoge für Reisestationen, Notizen und Personen,
/// damit jedes Datum am Helden dieselbe Form hat ([HeroAdventureDateValue]).
/// Alle Teile sind optional; ein unbekannter Monat erscheint als „—“.
class KartoDatumFelder extends StatefulWidget {
  /// Felder mit der Vorbelegung [initial]; [kennung] stellt den Schlüsseln
  /// voran (`<kennung>-tag`, `-monat`, `-jahr`).
  const KartoDatumFelder({
    super.key,
    required this.initial,
    required this.kennung,
    required this.onChanged,
  });

  /// Vorbelegung; seine unbekannten Felder bleiben im Ergebnis erhalten.
  final HeroAdventureDateValue initial;

  /// Präfix der Feldschlüssel.
  final String kennung;

  /// Meldet jede Änderung als neues Datum (Teile ohne Randleerzeichen).
  final ValueChanged<HeroAdventureDateValue> onChanged;

  @override
  State<KartoDatumFelder> createState() => _KartoDatumFelderState();
}

class _KartoDatumFelderState extends State<KartoDatumFelder> {
  late final TextEditingController _tag = TextEditingController(
    text: widget.initial.day,
  );
  late final TextEditingController _jahr = TextEditingController(
    text: widget.initial.year,
  );
  late String _monat = normalizeAventurianMonth(widget.initial.month);

  @override
  void dispose() {
    _tag.dispose();
    _jahr.dispose();
    super.dispose();
  }

  void _melde() {
    // Per `copyWith`, damit unbekannte Felder erhalten bleiben.
    widget.onChanged(
      widget.initial.copyWith(
        day: _tag.text.trim(),
        month: _monat,
        year: _jahr.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: TextField(
            key: ValueKey<String>('${widget.kennung}-tag'),
            controller: _tag,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Tag'),
            onChanged: (_) => _melde(),
          ),
        ),
        const SizedBox(width: Abstand.normal),
        Expanded(
          child: DropdownButtonFormField<String>(
            key: ValueKey<String>('${widget.kennung}-monat'),
            initialValue: _monat,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Monat'),
            items: [
              const DropdownMenuItem(value: '', child: Text('—')),
              for (final monat in aventurianMonths)
                DropdownMenuItem(value: monat.value, child: Text(monat.label)),
            ],
            onChanged: (wert) {
              setState(() => _monat = wert ?? '');
              _melde();
            },
          ),
        ),
        const SizedBox(width: Abstand.normal),
        SizedBox(
          width: 96,
          child: TextField(
            key: ValueKey<String>('${widget.kennung}-jahr'),
            controller: _jahr,
            decoration: const InputDecoration(
              labelText: 'Jahr',
              suffixText: 'BF',
            ),
            onChanged: (_) => _melde(),
          ),
        ),
      ],
    );
  }
}
