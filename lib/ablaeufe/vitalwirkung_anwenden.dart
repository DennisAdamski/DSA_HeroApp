import 'package:dsa_heldenverwaltung/ablaeufe/zustand_schreiben.dart';
import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/rules/derived/vitalwirkung_rules.dart';

/// Anwendungsablauf „Gegenstand anwenden“ (Heiltrank, Verband …).
///
/// Bucht die bestätigte Wirkung auf den frisch gespeicherten Laufzeitzustand:
/// LeP, AsP, AuP, geschlossene Wunden, eine fachliche Buchung und ein
/// Protokolleintrag in **einem** Dokument. Eine Wiederholung derselben
/// Vorgangs-ID bucht nichts doppelt. Die Prüfung läuft auf dem gespeicherten
/// Zustand; scheitert sie, wird nichts geschrieben. Das Abbuchen des Stücks im
/// Inventar ist ein eigener Schritt am Bogen und gehört dem Aufrufer.
class VitalwirkungAnwenden {
  /// Erzeugt den Ablauf mit Heldenspeicher und Uhr.
  const VitalwirkungAnwenden({required this.repository, required this.uhr});

  /// Speicher, aus dem frisch geladen und in den geschrieben wird.
  final HeroRepository repository;

  /// Liefert den Zeitpunkt für Protokoll und Änderungsstempel.
  final DateTime Function() uhr;

  /// Bucht [eingabe] für den Helden [heroId].
  ///
  /// Wirft einen [StateError], wenn die Eingabe auf dem gespeicherten Zustand
  /// nicht mehr zulässig ist.
  Future<VitalAnwendung> uebernimm({
    required String heroId,
    required VitalEingabe eingabe,
    required String gegenstand,
    required VitalGrenzen grenzen,
    required String vorgangId,
  }) async {
    final jetzt = uhr();
    late VitalAnwendung ergebnis;
    await aendereGespeichertenZustand(
      repository: repository,
      heroId: heroId,
      uhr: () => jetzt,
      aenderung: (aktuell) {
        final gebucht = aktuell.buchungen
            .where((b) => b.id == vorgangId)
            .firstOrNull;
        if (gebucht != null) {
          ergebnis = VitalAnwendung(
            zustand: aktuell,
            lep: gebucht.lepDelta,
            asp: gebucht.aspDelta,
            aup: gebucht.auDelta,
            wundenJeZone: gebucht.zone == null || gebucht.wundenDelta == 0
                ? const {}
                : {gebucht.zone!: -gebucht.wundenDelta},
            istWiederholung: true,
          );
          return aktuell;
        }
        final pruefung = pruefeVitalwirkung(aktuell, eingabe, grenzen: grenzen);
        if (!pruefung.gueltig) {
          throw StateError(pruefung.fehler.first);
        }
        final anwendung = wendeVitalwirkungAn(
          aktuell,
          eingabe,
          grenzen: grenzen,
        );
        ergebnis = anwendung;
        return anwendung.zustand
            .withBuchung(
              vitalBuchungAus(
                anwendung: anwendung,
                id: vorgangId,
                zeitpunkt: jetzt,
              ),
            )
            .withAppendedDiceLog(
              baueVitalProtokoll(
                gegenstand: gegenstand,
                anwendung: anwendung,
                zeitpunkt: jetzt,
                buchungId: vorgangId,
              ),
            );
      },
    );
    return ergebnis;
  }
}
