import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/abgelegter_kampfgegenstand.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';

/// Hinweis und Knopf „In Kampfbereich übernehmen“ für einen im
/// Kampfbereich abgelegten Gegenstand (ARCH-03).
class InventoryKampfUebernehmen extends StatelessWidget {
  /// Erstellt den Abschnitt für den abgelegten Eintrag [entry].
  const InventoryKampfUebernehmen({
    super.key,
    required this.entry,
    required this.onPressed,
  });

  /// Der abgelegte Eintrag.
  final HeroInventoryEntry entry;

  /// Holt ihn zurück; `null` sperrt den Knopf, etwa während des Speicherns.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bereich = _bereich(entry.abgelegt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aus $bereich abgelegt; die Kampfwerte sind gemerkt.',
          key: const ValueKey<String>('inventory-editor-abgelegt-hint'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          key: const ValueKey<String>('inventory-editor-kampf-uebernehmen'),
          onPressed: onPressed,
          icon: const Icon(Icons.shield_outlined),
          label: const Text('In Kampfbereich übernehmen'),
        ),
      ],
    );
  }
}

// Bereich des Kampfbereichs, aus dem [abgelegt] stammt, für den Hinweis.
String _bereich(AbgelegterKampfgegenstand? abgelegt) {
  if (abgelegt?.geschoss != null) return 'den Geschossen einer Waffe';
  if (abgelegt?.ruestungsteil != null) return 'der Rüstung';
  if (abgelegt?.nebenhandteil != null) return 'der Nebenhand-Ausrüstung';
  return 'den Waffen';
}

/// Fragt, an welche der [waffen] ein abgelegtes Geschoss zurückkommt.
///
/// Liefert die ID der gewählten Waffe oder `null` bei Abbruch. Ohne
/// Fernkampfwaffe gibt es nichts zu wählen; dann entsteht ein [StateError],
/// den der Editor anzeigt.
Future<String?> waehleZielwaffeFuerGeschoss(
  BuildContext context,
  List<MainWeaponSlot> waffen,
) {
  if (waffen.isEmpty) {
    throw StateError(
      'Im Kampfbereich gibt es keine Fernkampfwaffe für dieses Geschoss.',
    );
  }
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: const Text('An welche Waffe?'),
      children: [
        for (final waffe in waffen)
          SimpleDialogOption(
            key: ValueKey<String>('inventory-zielwaffe-${waffe.id}'),
            onPressed: () => Navigator.of(dialogContext).pop(waffe.id),
            child: Text(waffe.name),
          ),
      ],
    ),
  );
}
