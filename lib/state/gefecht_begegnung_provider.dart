import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_gegner.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_gegner_rules.dart';

/// Hält die lokale Gegnerliste gemeinsam für alle Heldensitzungen.
class GefechtsbegegnungsController extends Notifier<Gefechtsbegegnung> {
  /// Es wird weder ein Repository noch ein dauerhafter Speicher verwendet.
  @override
  Gefechtsbegegnung build() => const Gefechtsbegegnung();

  /// Erfasst bestätigte Gegnerwerte über die gemeinsame Profilprüfung.
  void speichern(Gefechtsgegner g) => state = speichereGefechtsgegner(state, g);

  /// Übernimmt bearbeitete Grundwerte auf den frischen Gegner.
  ///
  /// Treffer und Folgen, die während der Bearbeitung entstanden, bleiben.
  void profilSpeichern(Gefechtsgegner profil) =>
      state = speichereGefechtsgegnerprofil(state, profil);

  /// Bucht gegen die ursprüngliche ID mit den frischen Gegnerwerten.
  void schaden({
    required String gegnerId,
    required String buchungId,
    required int tp,
    bool direkt = false,
    WundZone? zone,
    int? wunden,
    int? runde,
    String von = '',
  }) => state = bucheGefechtsGegnerschaden(
    state,
    gegnerId: gegnerId,
    buchungId: buchungId,
    tp: tp,
    direkt: direkt,
    zone: zone,
    wunden: wunden,
    runde: runde,
    von: von,
  );

  /// Nimmt einen gebuchten Treffer zurück, ohne die Buchung freizugeben.
  void trefferZuruecknehmen({
    required String gegnerId,
    required String buchungId,
  }) => state = nimmGefechtsGegnertrefferZurueck(
    state,
    gegnerId: gegnerId,
    buchungId: buchungId,
  );

  /// Setzt einen ausdrücklich gewählten Status auf dem frischen Gegner.
  void statusSetzen(String gegnerId, GefechtsgegnerStatus status) => state =
      setzeGefechtsgegnerStatus(state, gegnerId: gegnerId, status: status);

  /// Beendet die Begegnung ausdrücklich für alle verbundenen Ansichten.
  void beenden() => state = const Gefechtsbegegnung();
}

/// Navigation erhält die Begegnung; ein Prozessneustart verwirft sie.
final gefechtBegegnungProvider =
    NotifierProvider<GefechtsbegegnungsController, Gefechtsbegegnung>(
      GefechtsbegegnungsController.new,
    );
