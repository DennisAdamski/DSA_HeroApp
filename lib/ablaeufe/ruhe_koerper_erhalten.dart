import 'package:dsa_heldenverwaltung/ablaeufe/zustand_schreiben.dart';
import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_rest_rules.dart';

/// Titel des Protokolleintrags eines Schlafs unter Ruhe Körper.
const String ruheKoerperProtokollTitel = 'Ruhe Körper';

/// Baut den Protokolleintrag eines Schlafs unter Ruhe Körper.
///
/// Nennt Stunden und alle tatsächlichen Änderungen, damit sich die Buchung
/// von Hand korrigieren lässt. `total` sind die gutgeschriebenen LeP.
DiceLogEntry baueRuheKoerperProtokoll({
  required RuheKoerperEingabe eingabe,
  required RuheKoerperAnwendung anwendung,
  required DateTime zeitpunkt,
  required String buchungId,
}) {
  final wunden = <String>[
    for (final eintrag in anwendung.wunden.entries)
      '${eintrag.value == 1 ? '1 Wunde' : '${eintrag.value} Wunden'} '
          '${wundZoneLabel[eintrag.key]}',
  ];
  final teile = <String>[
    '${eingabe.stunden} Std. Schlaf',
    '+${anwendung.lep} LeP',
    if (anwendung.asp > 0) '+${anwendung.asp} AsP',
    if (anwendung.ueberanstrengung > 0)
      '−${anwendung.ueberanstrengung} Überanstrengung',
    if (anwendung.erschoepfung > 0) '−${anwendung.erschoepfung} Erschöpfung',
    if (wunden.isNotEmpty) '${wunden.join(', ')} geheilt',
  ];
  return diceLogEntryFromRoll(
    title: ruheKoerperProtokollTitel,
    subtitle: teile.join(' · '),
    diceValues: const <int>[],
    total: anwendung.lep,
    timestamp: zeitpunkt,
    buchungId: buchungId,
  );
}

/// Anwendungsablauf „Ruhe Körper“ (MAG-EFF-05).
///
/// Bucht den Schlaf unter Ruhe Körper auf den frisch gespeicherten
/// Laufzeitzustand: LeP, AsP, Überanstrengung, Erschöpfung, geheilte Wunden,
/// Buchung und Protokoll in **einem** Dokument. Dieselbe Vorgangs-ID bucht
/// nie doppelt; die Prüfung läuft auf dem gespeicherten Zustand, eine
/// inzwischen unzulässige Eingabe wird nicht geschrieben. Fehler gibt der
/// Ablauf an die Oberfläche weiter.
class RuheKoerperErhalten {
  /// Erzeugt den Ablauf mit Heldenspeicher und Uhr.
  const RuheKoerperErhalten({required this.repository, required this.uhr});

  /// Speicher, aus dem frisch geladen und in den geschrieben wird.
  final HeroRepository repository;

  /// Liefert den Zeitpunkt für Protokoll und Änderungsstempel.
  final DateTime Function() uhr;

  /// Bucht [eingabe] für den Helden [heroId].
  ///
  /// [maxLep] und [maxAsp] sind die Obergrenzen des Helden. Wirft einen
  /// [StateError], wenn die Eingabe auf dem gespeicherten Zustand nicht mehr
  /// zulässig ist.
  Future<RuheKoerperAnwendung> uebernehmeSchlaf({
    required String heroId,
    required RuheKoerperEingabe eingabe,
    required int maxLep,
    required int maxAsp,
    required String vorgangId,
  }) async {
    final jetzt = uhr();
    late RuheKoerperAnwendung ergebnis;
    await aendereGespeichertenZustand(
      repository: repository,
      heroId: heroId,
      uhr: () => jetzt,
      aenderung: (aktuell) {
        final gebucht = aktuell.buchungen
            .where((b) => b.id == vorgangId)
            .firstOrNull;
        if (gebucht != null) {
          ergebnis = RuheKoerperAnwendung(
            zustand: aktuell,
            lep: gebucht.lepDelta,
            asp: gebucht.aspDelta,
            ueberanstrengung: 0,
            erschoepfung: 0,
            wunden: gebucht.zone == null || gebucht.wundenDelta == 0
                ? const <WundZone, int>{}
                : {gebucht.zone!: -gebucht.wundenDelta},
            istWiederholung: true,
          );
          return aktuell;
        }
        final pruefung = pruefeRuheKoerper(aktuell, eingabe, maxAsp: maxAsp);
        if (!pruefung.gueltig) {
          throw StateError(pruefung.fehler.first);
        }
        final anwendung = wendeRuheKoerperAn(
          aktuell,
          eingabe,
          maxLep: maxLep,
          maxAsp: maxAsp,
        );
        ergebnis = anwendung;
        return anwendung.zustand
            .withBuchung(
              ruheKoerperBuchungAus(
                anwendung: anwendung,
                id: vorgangId,
                zeitpunkt: jetzt,
              ),
            )
            .withAppendedDiceLog(
              baueRuheKoerperProtokoll(
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
