import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

/// Ändert den gespeicherten Laufzeitzustand frisch und meldet Fehler sichtbar.
///
/// Gemeinsamer Schreibweg der Bedienelemente für Laufzeitwerte (Ressourcen,
/// Belastung, Wunden, Zaubereffekte). [aenderung] bekommt den **gespeicherten**
/// Zustand und ersetzt nur ihre eigenen Felder; ein beim Rendern erfasster
/// Stand wird nie zurückgeschrieben (ARCH-05). Änderungen desselben Helden
/// laufen nacheinander (`aendereGespeichertenZustand`).
///
/// Scheitert das Speichern, erscheint `„[was] nicht gespeichert: …“` als
/// Snackbar und das Ergebnis ist `null`; sonst der gespeicherte Zustand.
/// Ein fehlgeschlagener Write darf nie als stille Übernahme erscheinen.
Future<HeroState?> aendereZustandMitMeldung({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required String was,
  required HeroState Function(HeroState aktuell) aenderung,
}) async {
  // Vor dem Warten greifen: das Bedienelement kann danach abgebaut sein.
  final bote = ScaffoldMessenger.maybeOf(context);
  final aktionen = ref.read(heroActionsProvider);
  try {
    return await aktionen.updateHeroState(heroId, aenderung);
  } catch (fehler) {
    bote?.showSnackBar(
      SnackBar(content: Text('$was nicht gespeichert: $fehler')),
    );
    return null;
  }
}
