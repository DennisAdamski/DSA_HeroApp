import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_zustand_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ressourcen_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/zustand_aendern.dart';

/// Ändert einen laufenden Wert (LeP, AsP, AuP) eines Begleiters im
/// gespeicherten Zustand und meldet Fehler sichtbar.
///
/// Der einzige Schreibweg der Oberfläche für `HeroState.begleiterZustaende`:
/// [aenderung] wird auf den **gespeicherten** Wert angewendet
/// (`mitBegleiterPool`), nie auf den angezeigten. [begleiter] liefert nur das
/// wirksame Maximum und die ID. Fehler erscheinen wie bei
/// [aendereZustandMitMeldung] im nächsten `ZustandFehlerBereich`.
Future<HeroState?> aendereBegleiterPool({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required HeroCompanion begleiter,
  required BegleiterPool pool,
  required RessourcenAenderung aenderung,
}) {
  return aendereZustandMitMeldung(
    context: context,
    ref: ref,
    heroId: heroId,
    was: pool.kuerzel,
    aenderung: (aktuell) =>
        mitBegleiterPool(aktuell, begleiter, pool, aenderung),
  );
}
