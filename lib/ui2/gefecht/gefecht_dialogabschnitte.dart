import 'package:flutter/material.dart';

/// Einklappbare Herleitung eines Gefechtsdialogs.
///
/// Zielwertanteile, Katalogtext und Quelle bleiben vollständig erreichbar,
/// stehen aber nicht mehr zwischen den eigentlichen Eingaben.
class GefechtBerechnung extends StatelessWidget {
  /// Zeigt [zeilen] erst nach dem Aufklappen.
  const GefechtBerechnung({super.key, required this.zeilen});

  /// Bereits fertig formulierte Zeilen aus Regelmodulen und Katalog.
  final List<String> zeilen;

  @override
  Widget build(BuildContext context) {
    final sichtbar = [
      for (final z in zeilen)
        if (z.trim().isNotEmpty) z,
    ];
    if (sichtbar.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      key: const ValueKey('gefecht-berechnung'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      title: const Text('Berechnung und Regeltext'),
      children: [for (final z in sichtbar) Text(z)],
    );
  }
}

/// Einzelentscheidungen bleiben nach dem Anhaken sichtbar und rücknehmbar.
class GefechtEntscheidungen extends StatelessWidget {
  /// [offen] stammen aus der Prüfung, [bestaetigt] aus dem Formular.
  const GefechtEntscheidungen({
    super.key,
    required this.offen,
    required this.bestaetigt,
    required this.onChanged,
  });

  /// Noch nicht bestätigte Entscheidungen der aktuellen Prüfung.
  final List<String> offen;

  /// Bereits bestätigte Entscheidungen dieses Formulars.
  final Set<String> bestaetigt;

  /// Meldet Bestätigung (`true`) oder Rücknahme (`false`).
  final void Function(String entscheidung, bool bestaetigt) onChanged;

  @override
  Widget build(BuildContext context) {
    final alle = <String>{...offen, ...bestaetigt};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in alle)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(e),
            value: bestaetigt.contains(e),
            onChanged: (v) => onChanged(e, v ?? false),
          ),
      ],
    );
  }
}
