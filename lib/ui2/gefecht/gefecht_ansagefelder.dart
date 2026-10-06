import 'package:flutter/material.dart';

import 'gefecht_zahlfeld.dart';

/// Unabhängige Ansagen bleiben von freien situativen Erschwernissen getrennt.
class GefechtAnsagefelder extends StatelessWidget {
  /// Die Auftragsprüfung liefert die wirksamen TP-/Abwehranteile.
  const GefechtAnsagefelder({
    super.key,
    required this.finte,
    required this.wuchtschlag,
    required this.fernkampfansage,
    required this.fernkampf,
    required this.abwehrmalus,
    required this.tpBonus,
    required this.onChanged,
  });
  final TextEditingController finte, wuchtschlag, fernkampfansage;
  final bool fernkampf;
  final int abwehrmalus, tpBonus;
  final VoidCallback onChanged;

  /// Das Formular rechnet keine Regeln und zeigt getrennte Auswirkungen.
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (fernkampf)
        _feld(fernkampfansage, 'Fernkampfansage', 'fk-ansage')
      else ...[
        _feld(finte, 'Finte', 'finte'),
        _feld(wuchtschlag, 'Wuchtschlag', 'wuchtschlag'),
      ],
      Text('Bei erfolgreichem Angriff: Abwehr +$abwehrmalus · TP +$tpBonus.'),
      if (!fernkampf)
        const Text(
          'Ohne erlernte Finte/Wuchtschlag wirkt die aufgerundete halbe Ansage. Weitere Erschwernisse erzeugen keinen Bonus.',
        ),
    ],
  );

  // Ein gemeinsamer Eingabeweg lässt alle Pflichtprüfungen erneut ausführen.
  Widget _feld(TextEditingController c, String name, String key) =>
      GefechtZahlfeld(
        key: ObjectKey(c),
        controller: c,
        label: name,
        feldKey: ValueKey('gefecht-$key'),
        minimum: 0,
        onChanged: onChanged,
      );
}
