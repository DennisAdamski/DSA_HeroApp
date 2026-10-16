import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';

/// Karte mit den gespeicherten Werten eines Artefaktzaubers.
///
/// Zeigt Name, Repräsentation des Sprechers, ZfW, ZfP*, Kosten und die
/// festgelegte Wirkung (Variante, Reichweite, Dauer, Ziel, Spontane
/// Modifikation). Die Werte gehören dem Artefakt und lassen sich beim
/// Auslösen nicht ändern.
class ArtefaktZauberKarte extends StatelessWidget {
  /// Erstellt die Karte für [zauber].
  const ArtefaktZauberKarte({super.key, required this.zauber});

  /// Der gespeicherte Zauber.
  final ArtefaktZauber zauber;

  @override
  Widget build(BuildContext context) {
    final z = zauber;
    final texte = Theme.of(context).textTheme;
    final zeilen = [
      [
        if (z.repraesentation.isNotEmpty) 'Repräsentation ${z.repraesentation}',
        if (z.zfw != null) 'ZfW ${z.zfw}',
        if (z.zfpStern != null) 'ZfP* ${z.zfpStern}',
        if (z.kostenAsp != null) '${z.kostenAsp} AsP',
        if (z.pAsP != null) '${z.pAsP} pAsP',
      ].join(' · '),
      if (z.variante.isNotEmpty) 'Variante: ${z.variante}',
      if (z.reichweite.isNotEmpty) 'Reichweite: ${z.reichweite}',
      if (z.wirkungsdauer.isNotEmpty) 'Wirkungsdauer: ${z.wirkungsdauer}',
      if (z.zielHinweis.isNotEmpty) 'Zielvorgabe: ${z.zielHinweis}',
      if (z.spontaneModifikation.isNotEmpty)
        'Spontane Modifikation: ${z.spontaneModifikation}',
      if (z.notiz.isNotEmpty) z.notiz,
    ].where((t) => t.isNotEmpty);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(z.name.isEmpty ? 'Unbenannt' : z.name, style: texte.titleSmall),
          for (final zeile in zeilen) Text(zeile, style: texte.bodySmall),
        ],
      ),
    );
  }
}
