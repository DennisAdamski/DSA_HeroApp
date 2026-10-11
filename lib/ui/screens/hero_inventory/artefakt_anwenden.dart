import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/matrix_ausloesen_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory/spruchspeicher_ausloesen_dialog.dart';

/// Öffnet den Auslösedialog, der zur Art des Artefakts passt.
///
/// Ein Matrixgeber braucht die AsP eines zauberkundigen Trägers und würfelt auf
/// die Stabilität seiner Matrix; ein Spruchspeicher verbraucht eine Ladung bzw.
/// eine Anwendung im Intervall ohne AsP und ohne Zauberprobe. Beide Wege kennen weder
/// Repräsentationswahl noch Zauberdauer: die gespeicherten Werte gelten.
Future<void> zeigeArtefaktAnwenden({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required HeroInventoryEntry eintrag,
}) {
  final art = eintrag.artefaktDaten?.art ?? ArtefaktArt.matrixgeber;
  return switch (art) {
    ArtefaktArt.matrixgeber => zeigeMatrixAusloesen(
      context: context,
      ref: ref,
      heroId: heroId,
      eintrag: eintrag,
    ),
    ArtefaktArt.spruchspeicherEinmalig ||
    ArtefaktArt.spruchspeicherAufladbar ||
    ArtefaktArt.spruchspeicherSemipermanent => zeigeSpruchspeicherAusloesen(
      context: context,
      ref: ref,
      heroId: heroId,
      eintrag: eintrag,
    ),
  };
}
