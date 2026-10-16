import 'package:dsa_heldenverwaltung/ablaeufe/zustand_schreiben.dart';
import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/artefakt_matrix_rules.dart';

/// Ergebnis einer gebuchten Matrixauslösung.
class MatrixAnwendung {
  /// Erstellt das Ergebnis.
  const MatrixAnwendung({
    required this.zustand,
    required this.kosten,
    required this.stabilitaet,
  });

  /// Gespeicherter Laufzeitzustand nach der Buchung.
  final HeroState zustand;

  /// Abgezogene AsP.
  final int kosten;

  /// Ausgang des Stabilitätstests.
  final MatrixStabilitaetsErgebnis stabilitaet;
}

/// Anwendungsablauf „Matrixgeber auslösen“.
///
/// Bucht auf den frisch gespeicherten Laufzeitzustand genau ein Dokument:
/// die AsP des Trägers (Zauberkosten, nach der Regelfassung 2011 ± W6) und
/// einen Protokolleintrag mit dem Stabilitätswurf. Eine Zauberprobe gibt es
/// nicht — Wirkung, ZfP*, Reichweite und Dauer stehen im Artefakt fest.
/// Dass die Matrix dabei irreparabel beschädigt wird, schreibt dieser
/// Ablauf **nicht** an den Bogen; das Ergebnis meldet es, die Oberfläche
/// bietet die Markierung als eigene Aktion an. Fehler (zu wenig AsP,
/// beschädigte Matrix) werden an die Oberfläche weitergereicht.
class MatrixAusloesen {
  /// Erzeugt den Ablauf mit Heldenspeicher und Uhr.
  const MatrixAusloesen({required this.repository, required this.uhr});

  /// Speicher, aus dem frisch geladen und in den geschrieben wird.
  final HeroRepository repository;

  /// Liefert den Zeitpunkt für Protokoll und Änderungsstempel.
  final DateTime Function() uhr;

  /// Löst [daten] des Gegenstands [artefaktName] für den Helden [heroId] aus.
  ///
  /// [ziel] ist die vom Anwender gewählte Zielangabe und erscheint nur im
  /// Protokoll.
  Future<MatrixAnwendung> loeseAus({
    required String heroId,
    required String artefaktName,
    required ArtefaktDaten daten,
    required MatrixWuerfe wuerfe,
    String ziel = '',
  }) async {
    if (daten.defekt) {
      throw StateError('Die Matrix ist irreparabel beschädigt.');
    }
    final jetzt = uhr();
    final kosten = matrixAusloeseKosten(daten, w6Kosten: wuerfe.w6Kosten);
    final stabilitaet = wertMatrixStabilitaet(
      stabilitaet: daten.stabilitaet,
      regelfassung: daten.regelfassung,
      wuerfe: wuerfe,
    );
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
              baueMatrixProtokoll(
                artefaktName: artefaktName,
                daten: daten,
                wuerfe: wuerfe,
                kosten: kosten,
                stabilitaet: stabilitaet,
                ziel: ziel,
                zeitpunkt: jetzt,
              ),
            );
      },
    );
    return MatrixAnwendung(
      zustand: zustand,
      kosten: kosten,
      stabilitaet: stabilitaet,
    );
  }
}

/// Kurzbezeichnung der Stabilität für Anzeige und Protokoll.
String matrixStabilitaetLabel(MatrixStabilitaet stabilitaet) =>
    switch (stabilitaet) {
      MatrixStabilitaet.labil => 'labil',
      MatrixStabilitaet.stabil => 'stabil',
      MatrixStabilitaet.sehrStabil => 'sehr stabil',
      MatrixStabilitaet.unempfindlich => 'unempfindlich',
    };

/// Kurzbezeichnung der Regelfassung für Anzeige und Protokoll.
String matrixRegelfassungLabel(MatrixRegelfassung fassung) => switch (fassung) {
  MatrixRegelfassung.alchimie2012 => 'Wege der Alchimie 2012',
  MatrixRegelfassung.staebeRinge2011 => 'Stäbe, Ringe, Dschinnenlampen 2011',
};

/// Baut den Würfelprotokolleintrag einer Matrixauslösung.
///
/// Nennt Zauber, Kosten, Stabilität samt Wurf und Ausgang, damit sich die
/// Buchung von Hand nachvollziehen und korrigieren lässt. Der Eintrag ist
/// neutral (kein Probenerfolg); `total` ist der Stabilitätswurf.
DiceLogEntry baueMatrixProtokoll({
  required String artefaktName,
  required ArtefaktDaten daten,
  required MatrixWuerfe wuerfe,
  required int kosten,
  required MatrixStabilitaetsErgebnis stabilitaet,
  required String ziel,
  required DateTime zeitpunkt,
}) {
  final namen = daten.zauber
      .map((z) => z.name.trim())
      .where((n) => n.isNotEmpty)
      .join(' + ');
  final ausgang = switch (stabilitaet.ausgang) {
    MatrixAusgang.ok => 'ohne Zwischenfall',
    MatrixAusgang.gehemmt => 'gehemmt für ${stabilitaet.hemmungSr} SR',
    MatrixAusgang.irreparabel => 'irreparabel beschädigt',
  };
  final teile = <String>[
    if (namen.isNotEmpty) namen,
    '$kosten AsP',
    'Matrix ${matrixStabilitaetLabel(daten.stabilitaet)}: '
        'W20 ${wuerfe.w20} → $ausgang',
    if (ziel.trim().isNotEmpty) 'Ziel: ${ziel.trim()}',
  ];
  return diceLogEntryFromRoll(
    title:
        'Matrixgeber: ${artefaktName.trim().isEmpty ? 'Artefakt' : artefaktName.trim()}',
    subtitle: teile.join(' · '),
    diceValues: <int>[wuerfe.w20],
    diceSpec: const DiceSpec(count: 1, sides: 20),
    type: ProbeType.genericRoll,
    total: wuerfe.w20,
    timestamp: zeitpunkt,
  );
}
