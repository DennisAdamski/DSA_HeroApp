import 'package:dsa_heldenverwaltung/ablaeufe/matrix_ausloesen.dart';
import 'package:dsa_heldenverwaltung/ablaeufe/zustand_schreiben.dart';
import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_auxiliator_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_matrix_rules.dart';

/// Die Angaben zum Einsatz eines Auxiliators bei einem Zauber des Anwenders.
class AuxiliatorEinsatz {
  /// Erstellt einen Einsatz.
  const AuxiliatorEinsatz({
    required this.zauberName,
    required this.zfpProbe,
    required this.bonus,
    required this.spruchGelungen,
    required this.grundkosten,
    required this.w3,
    this.ziel = '',
  });

  /// Name des gesprochenen Zaubers.
  final String zauberName;

  /// ZfP* der eigenen Zauberprobe des Anwenders (ohne Auxiliator).
  final int zfpProbe;

  /// Zusätzliche ZfP* durch den Auxiliator (0 bei misslungenem Spruch).
  final int bonus;

  /// Ob der Spruch auch ohne den Auxiliator gelungen wäre.
  final bool spruchGelungen;

  /// AsP, die als Zauberkosten in das Artefakt fließen und hier gebucht
  /// werden (0, wenn der Aufrufer sie schon als Zauberkosten bucht).
  final int grundkosten;

  /// W3 für die zusätzlichen AsP der Harmonisierung.
  final int w3;

  /// Zielangabe, nur fürs Protokoll.
  final String ziel;

  /// Gesamt-ZfP* des Spruchs mit Auxiliator.
  int get zfpGesamt => zfpProbe + bonus;

  /// AsP, die in das Artefakt fließen.
  int get kosten => auxiliatorKosten(grundkosten: grundkosten, w3: w3);
}

/// Ergebnis eines gebuchten Auxiliator-Einsatzes.
class AuxiliatorAnwendung {
  /// Erstellt das Ergebnis.
  const AuxiliatorAnwendung({
    required this.zustand,
    required this.einsatz,
    required this.stabilitaet,
  });

  /// Gespeicherter Laufzeitzustand nach der Buchung.
  final HeroState zustand;

  /// Der gebuchte Einsatz.
  final AuxiliatorEinsatz einsatz;

  /// Ausgang des Ausfallwurfs.
  final MatrixStabilitaetsErgebnis stabilitaet;
}

/// Anwendungsablauf „Auxiliator einsetzen“.
///
/// Der Anwender spricht den Zauber selbst (Zauberdauer, eigene Probe –
/// außerhalb dieses Ablaufs) und lässt zusätzlich Astralenergie in den
/// Zaubertalisman fließen: die Zauberkosten, soweit nicht anderweitig
/// gebucht, plus 1W3. Der Ablauf bucht auf den frisch geladenen Zustand genau
/// ein Dokument: die AsP und einen Protokolleintrag mit Bonus und Ausfallwurf.
/// Dass die Matrix dabei irreparabel beschädigt wird, schreibt er **nicht** an
/// den Bogen; das Ergebnis meldet es, die Oberfläche bietet die Markierung als
/// eigene Aktion an. Fehler (zu wenig AsP, beschädigter Talisman) werden an die
/// Oberfläche weitergereicht.
class AuxiliatorEinsetzen {
  /// Erzeugt den Ablauf mit Heldenspeicher und Uhr.
  const AuxiliatorEinsetzen({required this.repository, required this.uhr});

  /// Speicher, aus dem frisch geladen und in den geschrieben wird.
  final HeroRepository repository;

  /// Liefert den Zeitpunkt für Protokoll und Änderungsstempel.
  final DateTime Function() uhr;

  /// Setzt den Zaubertalisman [daten] des Gegenstands [artefaktName] für den
  /// Helden [heroId] ein.
  Future<AuxiliatorAnwendung> setzeEin({
    required String heroId,
    required String artefaktName,
    required ArtefaktDaten daten,
    required AuxiliatorEinsatz einsatz,
    required MatrixWuerfe wuerfe,
  }) async {
    if (daten.defekt) {
      throw StateError('Die Matrix ist irreparabel beschädigt.');
    }
    final jetzt = uhr();
    final aufschlag = auxiliatorAusfallAufschlag(
      spruchGelungen: einsatz.spruchGelungen,
    );
    final stabilitaet = wertMatrixStabilitaet(
      stabilitaet: daten.stabilitaet,
      regelfassung: daten.regelfassung,
      wuerfe: wuerfe,
      aufschlag: aufschlag,
    );
    final kosten = einsatz.kosten;
    final zustand = await aendereGespeichertenZustand(
      repository: repository,
      heroId: heroId,
      uhr: () => jetzt,
      aenderung: (aktuell) {
        if (!matrixAspReichen(aktuell.currentAsp, kosten)) {
          throw StateError(
            'Zu wenig AsP: $kosten AsP nötig, ${aktuell.currentAsp} '
            'vorhanden.',
          );
        }
        return aktuell
            .copyWith(currentAsp: aktuell.currentAsp - kosten)
            .withAppendedDiceLog(
              baueAuxiliatorProtokoll(
                artefaktName: artefaktName,
                daten: daten,
                einsatz: einsatz,
                wuerfe: wuerfe,
                aufschlag: aufschlag,
                stabilitaet: stabilitaet,
                zeitpunkt: jetzt,
              ),
            );
      },
    );
    return AuxiliatorAnwendung(
      zustand: zustand,
      einsatz: einsatz,
      stabilitaet: stabilitaet,
    );
  }
}

/// Baut den Würfelprotokolleintrag eines Auxiliator-Einsatzes.
///
/// Nennt Zauber, ZfP* (Probe, Bonus, Gesamt), die gebuchten AsP und den
/// Ausfallwurf samt Ausgang. Der Eintrag ist neutral; `total` ist der
/// Ausfallwurf.
DiceLogEntry baueAuxiliatorProtokoll({
  required String artefaktName,
  required ArtefaktDaten daten,
  required AuxiliatorEinsatz einsatz,
  required MatrixWuerfe wuerfe,
  required int aufschlag,
  required MatrixStabilitaetsErgebnis stabilitaet,
  required DateTime zeitpunkt,
}) {
  final ausgang = switch (stabilitaet.ausgang) {
    MatrixAusgang.ok => 'ohne Zwischenfall',
    MatrixAusgang.gehemmt => 'gehemmt für ${stabilitaet.hemmungSr} SR',
    MatrixAusgang.irreparabel => 'irreparabel beschädigt',
  };
  final zfp = einsatz.spruchGelungen
      ? 'ZfP* ${einsatz.zfpProbe} + ${einsatz.bonus} = ${einsatz.zfpGesamt}'
      : 'Spruch misslungen, kein Bonus';
  final teile = <String>[
    if (einsatz.zauberName.trim().isNotEmpty) einsatz.zauberName.trim(),
    zfp,
    '${einsatz.kosten} AsP',
    'Matrix ${matrixStabilitaetLabel(daten.stabilitaet)}: '
        'W20 ${wuerfe.w20}${aufschlag == 0 ? '' : ' +$aufschlag'} → $ausgang',
    if (einsatz.ziel.trim().isNotEmpty) 'Ziel: ${einsatz.ziel.trim()}',
  ];
  return diceLogEntryFromRoll(
    title:
        'Auxiliator: ${artefaktName.trim().isEmpty ? 'Artefakt' : artefaktName.trim()}',
    subtitle: teile.join(' · '),
    diceValues: <int>[wuerfe.w20],
    diceSpec: const DiceSpec(count: 1, sides: 20),
    type: ProbeType.genericRoll,
    total: wuerfe.w20,
    timestamp: zeitpunkt,
  );
}
