import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/list_tile_material.dart';

/// Zeile für einen in ein Artefakt gesprochenen Zauber im Inventareditor.
///
/// Zeigt Name und Eckdaten des Sprechers; Tippen öffnet den Zauberdialog,
/// das Papierkorb-Symbol entfernt den Zauber.
class ArtefaktZauberZeile extends StatelessWidget {
  /// Erstellt die Zeile für [zauber].
  const ArtefaktZauberZeile({
    super.key,
    required this.zauber,
    required this.onAendern,
    required this.onEntfernen,
  });

  /// Der gespeicherte Zauber.
  final ArtefaktZauber zauber;

  /// Öffnet den Zauberdialog.
  final VoidCallback onAendern;

  /// Entfernt den Zauber.
  final VoidCallback onEntfernen;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (zauber.repraesentation.isNotEmpty) zauber.repraesentation,
      if (zauber.variante.isNotEmpty) 'Variante: ${zauber.variante}',
      if (zauber.zfw != null) 'ZfW ${zauber.zfw}',
      if (zauber.zfpStern != null) 'ZfP* ${zauber.zfpStern}',
      if (zauber.kostenAsp != null) '${zauber.kostenAsp} AsP',
      if (zauber.pAsP != null) '${zauber.pAsP} pAsP',
    ].join(' · ');
    return ListTileMaterial(
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(zauber.name.isEmpty ? 'Unbenannt' : zauber.name),
        subtitle: details.isEmpty ? null : Text(details),
        onTap: onAendern,
        trailing: IconButton(
          tooltip: 'Zauber entfernen',
          icon: const Icon(Icons.delete_outline),
          onPressed: onEntfernen,
        ),
      ),
    );
  }
}
