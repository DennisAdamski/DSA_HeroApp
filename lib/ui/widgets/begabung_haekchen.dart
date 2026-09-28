import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/rules/derived/hero_begabung_rules.dart';

/// Begabungs-Haekchen eines Talents oder Zaubers samt abgeleiteter Wirkung.
///
/// Greift eine Begabung aus Vor-/Nachteilen, steht das Haekchen gesetzt und
/// gesperrt; der Tooltip nennt die Quelle. Das gespeicherte Haekchen
/// (`gifted`) bleibt dabei unangetastet und wirkt wieder, sobald der Vorteil
/// entfernt ist. Eine Unfaehigkeit erscheint als Marke daneben.
class BegabungHaekchen extends StatelessWidget {
  /// Erstellt das Haekchen.
  const BegabungHaekchen({
    super.key,
    required this.checkboxKey,
    required this.value,
    required this.befund,
    this.onChanged,
  });

  /// Schluessel der Checkbox (Tests und Bestandsschluessel).
  final Key checkboxKey;

  /// Gespeichertes Haekchen.
  final bool value;

  /// Abgeleitete Begabungen und Unfaehigkeiten des Ziels.
  final LernspaltenBefund befund;

  /// Aendert das gespeicherte Haekchen; `null` sperrt es.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final abgeleitet = befund.abgeleitetBegabt;
    final aenderung = onChanged;
    Widget haekchen = Checkbox(
      key: checkboxKey,
      value: abgeleitet || value,
      onChanged: abgeleitet || aenderung == null
          ? null
          : (next) => aenderung(next ?? false),
    );
    if (abgeleitet) {
      haekchen = Tooltip(
        message: 'Aus Vorteil: ${befund.begabungsQuellen.join(', ')}',
        child: haekchen,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        haekchen,
        if (befund.unfaehig) UnfaehigkeitsMarke(befund: befund),
      ],
    );
  }
}

/// Kleine Marke fuer eine Unfaehigkeit mit ihrer Quelle als Tooltip.
class UnfaehigkeitsMarke extends StatelessWidget {
  /// Erstellt die Marke.
  const UnfaehigkeitsMarke({super.key, required this.befund});

  /// Befund mit mindestens einer Unfaehigkeit.
  final LernspaltenBefund befund;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Unfähigkeit: ${befund.unfaehigkeitsQuellen.join(', ')}',
      child: Icon(
        Icons.trending_down,
        size: 18,
        semanticLabel: 'Unfähigkeit',
        color: Theme.of(context).colorScheme.error,
      ),
    );
  }
}
