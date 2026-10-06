import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/inventory_kampf_uebernehmen.dart';

/// Aktionen am gespeicherten Inventareintrag im Editor (ARCH-03): Stapel
/// teilen, zusammenführen, verkaufen und in den Kampfbereich übernehmen.
///
/// Jede Aktion erscheint nur mit Rückruf; `null` heißt „hier nicht
/// möglich“. [gesperrt] sperrt alle Knöpfe, etwa während des Speicherns.
class InventoryEintragAktionen extends StatelessWidget {
  /// Erstellt die Aktionen für [entry].
  const InventoryEintragAktionen({
    super.key,
    required this.entry,
    required this.gesperrt,
    this.onTeilen,
    this.onZusammenfuehren,
    this.onVerkaufen,
    this.onKampfUebernehmen,
  });

  /// Der gespeicherte Eintrag, mit dem der Editor geöffnet wurde.
  final HeroInventoryEntry entry;

  /// Ob gerade geschrieben wird.
  final bool gesperrt;

  /// Spaltet einen Stapel ab.
  final VoidCallback? onTeilen;

  /// Führt den Stapel in einen gleichen zusammen.
  final VoidCallback? onZusammenfuehren;

  /// Verkauft den Gegenstand oder einen Teil des Stapels.
  final VoidCallback? onVerkaufen;

  /// Holt einen abgelegten Gegenstand in den Kampfbereich zurück.
  final VoidCallback? onKampfUebernehmen;

  @override
  Widget build(BuildContext context) {
    VoidCallback? frei(VoidCallback? aktion) => gesperrt ? null : aktion;
    final knoepfe = <Widget>[
      if (onTeilen != null)
        OutlinedButton.icon(
          key: const ValueKey<String>('inventory-editor-split'),
          onPressed: frei(onTeilen),
          icon: const Icon(Icons.call_split),
          label: const Text('Stapel teilen'),
        ),
      if (onZusammenfuehren != null)
        OutlinedButton.icon(
          key: const ValueKey<String>('inventory-editor-merge'),
          onPressed: frei(onZusammenfuehren),
          icon: const Icon(Icons.call_merge),
          label: const Text('Zusammenführen'),
        ),
      if (onVerkaufen != null)
        OutlinedButton.icon(
          key: const ValueKey<String>('inventory-editor-sell'),
          onPressed: frei(onVerkaufen),
          icon: const Icon(Icons.sell_outlined),
          label: const Text('Verkaufen'),
        ),
    ];
    final uebernehmen = onKampfUebernehmen;
    if (knoepfe.isEmpty && uebernehmen == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (uebernehmen != null) ...[
            InventoryKampfUebernehmen(
              entry: entry,
              onPressed: frei(uebernehmen),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(spacing: 8, runSpacing: 8, children: knoepfe),
        ],
      ),
    );
  }
}
