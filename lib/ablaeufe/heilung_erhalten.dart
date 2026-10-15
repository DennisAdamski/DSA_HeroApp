import 'package:dsa_heldenverwaltung/ablaeufe/zustand_schreiben.dart';
import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_healing_rules.dart';

/// Titel des Protokolleintrags einer Heilung.
const String heilungProtokollTitel = 'Heilung erhalten';

/// Baut den Protokolleintrag einer Heilung.
///
/// Nennt Zauber, eingesetzte AsP und die tatsächlichen Änderungen, damit die
/// Buchung von Hand korrigiert werden kann. `total` sind die gutgeschriebenen
/// LeP. Der Eintrag verweist über [buchungId] auf seine Buchung.
DiceLogEntry baueHeilungsProtokoll({
  required String zauberName,
  required HeilEingabe eingabe,
  required HeilAnwendung anwendung,
  required DateTime zeitpunkt,
  required String buchungId,
}) {
  final zone = eingabe.zone;
  final teile = <String>[
    zauberName,
    if (eingabe.asp > 0) '${eingabe.asp} AsP eingesetzt',
    if (eingabe.zfpStern > 0 && eingabe.asp == 0) 'ZfP* ${eingabe.zfpStern}',
    '+${anwendung.lep} LeP',
    if (anwendung.asp > 0) '−${anwendung.asp} AsP',
    if (anwendung.wunden > 0 && zone != null)
      '${anwendung.wunden == 1 ? '1 Wunde' : '${anwendung.wunden} Wunden'} '
          '${wundZoneLabel[zone]} geschlossen',
  ];
  return diceLogEntryFromRoll(
    title: heilungProtokollTitel,
    subtitle: teile.join(' · '),
    diceValues: const <int>[],
    total: anwendung.lep,
    timestamp: zeitpunkt,
    buchungId: buchungId,
  );
}

/// Anwendungsablauf „Heilung erhalten“ (MAG-EFF-05).
///
/// Bucht eine bestätigte Zauberheilung auf den frisch gespeicherten
/// Laufzeitzustand: LeP, AsP bei Selbstwirkung, geschlossene Wunden, eine
/// fachliche Buchung und ein Protokolleintrag in **einem** Dokument. Eine
/// Wiederholung derselben Vorgangs-ID bucht nichts doppelt. Die Prüfung
/// läuft auf dem gespeicherten Zustand; scheitert sie, wird nichts
/// geschrieben. Fehler gibt der Ablauf an die Oberfläche weiter.
class HeilungErhalten {
  /// Erzeugt den Ablauf mit Heldenspeicher und Uhr.
  const HeilungErhalten({required this.repository, required this.uhr});

  /// Speicher, aus dem frisch geladen und in den geschrieben wird.
  final HeroRepository repository;

  /// Liefert den Zeitpunkt für Protokoll und Änderungsstempel.
  final DateTime Function() uhr;

  /// Bucht [eingabe] für den Helden [heroId].
  ///
  /// [maxLep] ist die Obergrenze der LeP des Helden. Ist [vorgangId] schon
  /// gebucht, ändert sich nichts und das Ergebnis trägt `istWiederholung`.
  /// Wirft einen [StateError], wenn die Heilung auf dem gespeicherten Zustand
  /// nicht mehr zulässig ist (etwa weil die AsP inzwischen fehlen).
  Future<HeilAnwendung> uebernehmeHeilung({
    required String heroId,
    required HeilEingabe eingabe,
    required String zauberName,
    required int maxLep,
    required String vorgangId,
  }) async {
    final jetzt = uhr();
    late HeilAnwendung ergebnis;
    await aendereGespeichertenZustand(
      repository: repository,
      heroId: heroId,
      uhr: () => jetzt,
      aenderung: (aktuell) {
        final gebucht = aktuell.buchungen
            .where((b) => b.id == vorgangId)
            .firstOrNull;
        if (gebucht != null) {
          ergebnis = HeilAnwendung(
            zustand: aktuell,
            lep: gebucht.lepDelta,
            asp: -gebucht.aspDelta,
            wunden: -gebucht.wundenDelta,
            istWiederholung: true,
          );
          return aktuell;
        }
        final pruefung = pruefeHeilung(aktuell, eingabe, maxLep: maxLep);
        if (!pruefung.gueltig) {
          throw StateError(pruefung.fehler.first);
        }
        final anwendung = wendeHeilungAn(aktuell, eingabe, maxLep: maxLep);
        ergebnis = anwendung;
        return anwendung.zustand
            .withBuchung(
              heilungsBuchungAus(
                eingabe: eingabe,
                anwendung: anwendung,
                id: vorgangId,
                zeitpunkt: jetzt,
              ),
            )
            .withAppendedDiceLog(
              baueHeilungsProtokoll(
                zauberName: zauberName,
                eingabe: eingabe,
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
