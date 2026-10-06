import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';

/// Führt nur flüchtige Sitzungen; Regelentscheidungen kommen aus Regelmodulen.
class GefechtsController extends Notifier<Gefechtszustand?> {
  /// Bindet die Sitzung an eine Heldenidentität.
  GefechtsController(this.heroId);
  final String heroId;
  @override
  Gefechtszustand? build() => null;

  /// Beginnt eine Sitzung, ohne ein laufendes Gefecht zu überschreiben.
  ///
  /// [dk] ist die Start-Distanzklasse; die Sitzung beginnt mit Vorgaben.
  void beginnen(int wurf, {String? dk}) =>
      state ??= beginneGefecht(wurf, dk: dk);

  /// Verwirft nur diesen flüchtigen Zustand.
  void beenden() => state = null;

  /// Übernimmt eine regelgeprüfte Zustandsänderung außerhalb eines Auftrags.
  void setzen(Gefechtszustand neu) {
    if (state?.auftrag != null) throw StateError('Aktionsauftrag läuft.');
    state = neu;
  }

  /// Reserviert einen einmaligen Auftrag und verhindert parallele Dialoge.
  bool reservieren(String id) {
    if (state == null || state!.auftrag != null) return false;
    state = state!.copyWith(auftrag: id);
    return true;
  }

  /// Ein Abbruch vor Auswertung verbraucht keine Aktionsmarke.
  void abbrechen(String id) {
    if (state?.auftrag == id) state = state!.copyWith(ohneAuftrag: true);
  }

  /// Bucht exakt den reservierten Auftrag; wiederholte callbacks bleiben inert.
  bool abschliessen(
    String id,
    Gefechtswerte werte,
    Gefechtspruefung pruefung, {
    bool? erfolg,
  }) {
    final aktuell = state;
    if (aktuell == null || aktuell.auftrag != id) return false;
    state = verbraucheGefechtsaktion(aktuell, werte, pruefung, erfolg: erfolg);
    return true;
  }
}

/// Navigation erhält Gefechte je Held; ein Prozessneustart beendet sie.
final gefechtProvider =
    NotifierProvider.family<GefechtsController, Gefechtszustand?, String>(
      GefechtsController.new,
    );
