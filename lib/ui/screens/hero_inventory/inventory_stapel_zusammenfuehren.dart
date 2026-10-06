import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';

/// Fragt, in welchen der [ziele] ein Stapel zusammengeführt wird (ARCH-03).
///
/// Zeigt je Ziel Menge und Ort, damit gleichnamige Stapel unterscheidbar
/// sind. Liefert das gewählte Ziel oder `null` bei Abbruch.
Future<HeroInventoryEntry?> waehleZielstapel(
  BuildContext context,
  List<HeroInventoryEntry> ziele,
) {
  return showDialog<HeroInventoryEntry>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: const Text('In welchen Stapel?'),
      children: [
        for (var i = 0; i < ziele.length; i++)
          SimpleDialogOption(
            key: ValueKey<String>('inventory-zielstapel-$i'),
            onPressed: () => Navigator.of(dialogContext).pop(ziele[i]),
            child: Text(_beschreibe(ziele[i])),
          ),
      ],
    ),
  );
}

// „Pfeil — 20 Stück · Köcher“.
String _beschreibe(HeroInventoryEntry ziel) {
  final ort = ziel.woGetragen.trim();
  final menge = '${ziel.anzahl.trim()} Stück';
  return [
    ziel.gegenstand.trim(),
    ort.isEmpty ? menge : '$menge · $ort',
  ].join(' — ');
}
