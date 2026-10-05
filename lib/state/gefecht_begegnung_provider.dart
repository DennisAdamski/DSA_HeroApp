import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_gegner.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_gegner_rules.dart';

/// Hält die lokale Gegnerliste gemeinsam für alle Heldensitzungen.
class GefechtsbegegnungsController extends Notifier<Gefechtsbegegnung> {
  /// Es wird weder ein Repository noch ein dauerhafter Speicher verwendet.
  @override
  Gefechtsbegegnung build() => const Gefechtsbegegnung();

  /// Erfasst bestätigte Gegnerwerte über die gemeinsame Profilprüfung.
  void speichern(Gefechtsgegner g) => state = speichereGefechtsgegner(state, g);

  /// Bucht gegen die ursprüngliche ID mit den frischen Gegnerwerten.
  void schaden({
    required String gegnerId,
    required String buchungId,
    required int tp,
    bool direkt = false,
  }) => state = bucheGefechtsGegnerschaden(
    state,
    gegnerId: gegnerId,
    buchungId: buchungId,
    tp: tp,
    direkt: direkt,
  );

  /// Beendet die Begegnung ausdrücklich für alle verbundenen Ansichten.
  void beenden() => state = const Gefechtsbegegnung();
}

/// Navigation erhält die Begegnung; ein Prozessneustart verwirft sie.
final gefechtBegegnungProvider =
    NotifierProvider<GefechtsbegegnungsController, Gefechtsbegegnung>(
      GefechtsbegegnungsController.new,
    );
