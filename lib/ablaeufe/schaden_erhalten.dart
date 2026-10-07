import 'package:dsa_heldenverwaltung/ablaeufe/schaden_protokoll.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/zustand_schreiben.dart';
import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/rules/derived/schaden_ruecknahme_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/schaden_rules.dart';

/// Anwendungsablauf „Schaden erhalten“ (ARCH-05).
///
/// Bucht einen bestätigten Treffer auf den frisch gespeicherten
/// Laufzeitzustand: LeP bzw. AuP, Wunden, eine fachliche Buchung mit den
/// tatsächlichen Änderungen und ein Protokolleintrag, dann stempeln und
/// speichern. Andere Felder, die seit dem Öffnen des Dialogs gespeichert
/// wurden, bleiben erhalten. Über die Buchung lässt sich der Treffer später
/// zurücknehmen (`SchadenZuruecknehmen`, ARCH-06), und eine Wiederholung
/// derselben Vorgangs-ID bucht nichts doppelt. Fehler werden an die
/// Oberfläche weitergereicht.
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
  /// Ergebnis nennt beides. Protokoll, Buchung und Änderungsstempel tragen
  /// denselben Zeitpunkt. Ist [vorgangId] schon gebucht, ändert sich nichts;
  /// das Ergebnis trägt dann `istWiederholung`.
  Future<SchadensAnwendung> uebernehmeSchaden({
    required String heroId,
    required SchadensBuchung buchung,
    required String vorgangId,
  }) async {
    final jetzt = uhr();
    late SchadensAnwendung anwendung;
    await aendereGespeichertenZustand(
      repository: repository,
      heroId: heroId,
      uhr: () => jetzt,
      aenderung: (aktuell) {
        final gebucht = aktuell.buchungen
            .where((b) => b.id == vorgangId)
            .firstOrNull;
        if (gebucht != null) {
          anwendung = SchadensAnwendung(
            zustand: aktuell,
            hinzugefuegteWunden: gebucht.wundenDelta,
            verfalleneWunden: buchung.wunden - gebucht.wundenDelta,
            istWiederholung: true,
          );
          return aktuell;
        }
        anwendung = wendeSchadenAn(aktuell, buchung);
        return anwendung.zustand
            .withBuchung(
              schadensBuchungAus(
                vorher: aktuell,
                anwendung: anwendung,
                buchung: buchung,
                id: vorgangId,
                zeitpunkt: jetzt,
              ),
            )
            .withAppendedDiceLog(
              baueSchadensProtokoll(
                buchung: buchung,
                hinzugefuegteWunden: anwendung.hinzugefuegteWunden,
                zeitpunkt: jetzt,
                buchungId: vorgangId,
              ),
            );
      },
    );
    return anwendung;
  }
}
