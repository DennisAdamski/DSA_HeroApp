import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_patzer.dart';

import 'gefecht_provider.dart';

/// Verwirft Folgewürfe und Defekte automatisch beim Ende der Heldensitzung.
class GefechtsPatzerController extends Notifier<GefechtsPatzerstand> {
  /// Trennt die flüchtigen Folgen verschiedener Helden.
  GefechtsPatzerController(this.heroId);
  final String heroId;
  @override
  GefechtsPatzerstand build() {
    ref.listen(gefechtProvider(heroId), (vorher, jetzt) {
      if (jetzt == null || vorher == null) state = const GefechtsPatzerstand();
    });
    return const GefechtsPatzerstand();
  }

  /// Übernimmt ausschließlich fachlich berechnete oder eingefrorene Ergebnisse.
  void setzen(GefechtsPatzerstand neu) => state = neu;
}

/// Kein Persistenzschema: Defekte gelten nur bis zum Sitzungsende.
final gefechtPatzerProvider =
    NotifierProvider.family<
      GefechtsPatzerController,
      GefechtsPatzerstand,
      String
    >(GefechtsPatzerController.new);
