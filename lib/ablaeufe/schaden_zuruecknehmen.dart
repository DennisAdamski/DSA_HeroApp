import 'package:dsa_heldenverwaltung/ablaeufe/schaden_protokoll.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/zustand_schreiben.dart';
import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/rules/derived/schaden_ruecknahme_rules.dart';

/// Anwendungsablauf „Schaden zurücknehmen“ (ARCH-06).
///
/// Nimmt eine Schadensbuchung als Gegenbuchung auf den frisch gespeicherten
/// Zustand zurück: LeP und AuP kommen um den tatsächlich abgezogenen Betrag
/// zurück (ohne Obergrenze), Wunden des Treffers werden entfernt, soweit noch
/// eingetragen, und ein eigener Protokolleintrag hält die Rücknahme fest.
/// Alles übrige, auch zwischenzeitliche Heilung, bleibt erhalten. Eine
/// Buchung lässt sich nur einmal zurücknehmen; die Prüfung läuft auf dem
/// gespeicherten Stand, eingereiht hinter jede andere Zustandsänderung.
class SchadenZuruecknehmen {
  /// Erzeugt den Ablauf mit Heldenspeicher und Uhr.
  const SchadenZuruecknehmen({required this.repository, required this.uhr});

  /// Speicher, aus dem frisch geladen und in den geschrieben wird.
  final HeroRepository repository;

  /// Liefert den Zeitpunkt für Gegenbuchung, Protokoll und Stempel.
  final DateTime Function() uhr;

  /// Nimmt die Buchung [buchungId] des Helden [heroId] zurück.
  ///
  /// [vorgangId] ist die ID der Gegenbuchung: Eine Wiederholung mit derselben
  /// ID ändert nichts und liefert `null`. Ist die Rücknahme nicht (mehr)
  /// möglich, wirft der Ablauf einen [StateError] mit deutschem Text.
  /// Liefert sonst den angewendeten Plan.
  Future<SchadensRuecknahmePlan?> nimmZurueck({
    required String heroId,
    required String buchungId,
    required String vorgangId,
  }) async {
    final jetzt = uhr();
    SchadensRuecknahmePlan? angewendet;
    await aendereGespeichertenZustand(
      repository: repository,
      heroId: heroId,
      uhr: () => jetzt,
      aenderung: (aktuell) {
        if (aktuell.buchungen.any((b) => b.id == vorgangId)) {
          return aktuell;
        }
        final plan = switch (planeSchadensRuecknahme(aktuell, buchungId)) {
          RuecknahmeMoeglich(:final plan) => plan,
          RuecknahmeUnmoeglich(:final hindernis) => throw StateError(
            ruecknahmeHindernisText(hindernis),
          ),
        };
        angewendet = plan;
        return wendeSchadensRuecknahmeAn(
          aktuell,
          plan,
          gegenbuchungId: vorgangId,
          zeitpunkt: jetzt,
        ).withAppendedDiceLog(
          baueRuecknahmeProtokoll(
            plan: plan,
            gegenbuchungId: vorgangId,
            zeitpunkt: jetzt,
          ),
        );
      },
    );
    return angewendet;
  }
}
