import 'package:dsa_heldenverwaltung/ablaeufe/schaden_protokoll.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/zustand_schreiben.dart';
import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/rules/derived/schaden_rules.dart';

/// Anwendungsablauf „Schaden erhalten“ (ARCH-05).
///
/// Bucht einen bestätigten Treffer auf den frisch gespeicherten
/// Laufzeitzustand: LeP bzw. AuP, Wunden und ein Protokolleintrag, dann
/// stempeln und speichern. Andere Felder, die seit dem Öffnen des Dialogs
/// gespeichert wurden, bleiben erhalten. Die Buchung ist nur über den
/// Protokolleintrag nachvollziehbar; eine Rücknahme gehört zu ARCH-06.
/// Fehler werden an die Oberfläche weitergereicht.
class SchadenErhalten {
  /// Erzeugt den Ablauf mit Heldenspeicher und Uhr.
  const SchadenErhalten({required this.repository, required this.uhr});

  /// Speicher, aus dem frisch geladen und in den geschrieben wird.
  final HeroRepository repository;

  /// Liefert den Zeitpunkt für Protokoll und Änderungsstempel.
  final DateTime Function() uhr;

  /// Bucht [buchung] für den Helden [heroId].
  ///
  /// Gerechnet wird auf dem **gespeicherten** Zustand. Hat die Zone dort
  /// weniger freie Plätze als gewählt, verfallen die übrigen Wunden; das
  /// Ergebnis nennt beides. Protokoll und Änderungsstempel tragen denselben
  /// Zeitpunkt.
  Future<SchadensAnwendung> uebernehmeSchaden({
    required String heroId,
    required SchadensBuchung buchung,
  }) async {
    final jetzt = uhr();
    late SchadensAnwendung anwendung;
    await aendereGespeichertenZustand(
      repository: repository,
      heroId: heroId,
      uhr: () => jetzt,
      aenderung: (aktuell) {
        anwendung = wendeSchadenAn(aktuell, buchung);
        return anwendung.zustand.withAppendedDiceLog(
          baueSchadensProtokoll(
            buchung: buchung,
            hinzugefuegteWunden: anwendung.hinzugefuegteWunden,
            zeitpunkt: jetzt,
          ),
        );
      },
    );
    return anwendung;
  }
}
