import 'package:dsa_heldenverwaltung/ablaeufe/rast_protokoll.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/zustand_schreiben.dart';
import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/rest_outcome_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/rest_rules.dart';

/// Anwendungsablauf „Rast abschließen“ (ARCH-05).
///
/// Rechnet eine Rast auf dem frisch gespeicherten Laufzeitzustand, ersetzt
/// nur die betroffenen Felder, hängt das Würfelprotokoll an, stempelt und
/// speichert. Änderungen anderer Felder, die seit dem Öffnen des Rastdialogs
/// gespeichert wurden (Würfelprotokoll, Wunden, Zaubereffekte), bleiben
/// erhalten. Fehler werden nicht gefangen, sondern an die Oberfläche
/// weitergereicht. Dies ist keine Transaktion gegenüber parallelen
/// Schreibwegen (ARCH-06).
class RastAbschliessen {
  /// Erzeugt den Ablauf mit Heldenspeicher und Uhr.
  const RastAbschliessen({required this.repository, required this.uhr});

  /// Speicher, aus dem frisch geladen und in den geschrieben wird.
  final HeroRepository repository;

  /// Liefert den Zeitpunkt für Protokoll und Änderungsstempel.
  final DateTime Function() uhr;

  /// Übernimmt eine Rast mit den Eingaben aus [eingabe].
  ///
  /// Gerechnet wird ausgehend von den **gespeicherten** Werten, nicht von
  /// einem Stand der Oberfläche; die Maxima und Probenzielwerte kommen aus
  /// [eingabe]. [manuelleWuerfe] kennzeichnet von Hand eingetragene Würfe im
  /// Protokoll. Protokolleinträge und Änderungszeitpunkt tragen denselben
  /// Zeitpunkt. Liefert das Ergebnis der tatsächlich gespeicherten Rast.
  Future<RestOutcome> uebernehmeRast({
    required String heroId,
    required RestOutcomeInput eingabe,
    Set<RestRollSlot> manuelleWuerfe = const <RestRollSlot>{},
  }) async {
    final jetzt = uhr();
    late RestOutcome ergebnis;
    await aendereGespeichertenZustand(
      repository: repository,
      heroId: heroId,
      uhr: () => jetzt,
      aenderung: (aktuell) {
        ergebnis = computeRestOutcome(
          input: eingabe,
          current: RestVitals.fromState(aktuell),
        );
        final protokoll = baueRastProtokoll(
          eingabe: eingabe,
          manuelleWuerfe: manuelleWuerfe,
          zeitpunkt: jetzt,
        );
        return applyRestOutcome(
          aktuell,
          ergebnis,
        ).withAppendedDiceLogEntries(protokoll);
      },
    );
    return ergebnis;
  }

  /// Stellt den Helden vollständig wieder her (Fullrestore).
  ///
  /// Setzt LeP, Au, AsP und KaP auf die Maxima aus [werte], baut Erschöpfung
  /// und Überanstrengung ab und heilt alle Wunden
  /// ([buildFullRestoreState]); alle übrigen Felder des gespeicherten
  /// Zustands bleiben erhalten.
  Future<void> vollstaendigeErholung({
    required String heroId,
    required DerivedStats werte,
  }) async {
    await aendereGespeichertenZustand(
      repository: repository,
      heroId: heroId,
      uhr: uhr,
      aenderung: (aktuell) =>
          buildFullRestoreState(currentState: aktuell, derivedStats: werte),
    );
  }
}
