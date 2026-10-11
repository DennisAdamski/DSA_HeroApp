import 'package:dsa_heldenverwaltung/ablaeufe/zustand_schreiben.dart';
import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';

/// Anwendungsablauf „Artefaktvorgang protokollieren“.
///
/// Ein Spruchspeicher verbraucht weder AsP noch ändert er den Zustand; was er
/// ändert, steht am Bogen (Ladung verbraucht, wieder aufgeladen). Das
/// Würfelprotokoll ist deshalb eine eigene, nachgelagerte Buchung auf den
/// frisch geladenen Zustand — genau ein Dokument. Läuft sie nach der
/// Bogenänderung und scheitert, fehlt nur ein Protokolleintrag, nie eine
/// Buchung. Fehler werden an die Oberfläche weitergereicht.
class ArtefaktProtokollieren {
  /// Erzeugt den Ablauf mit Heldenspeicher und Uhr.
  const ArtefaktProtokollieren({required this.repository, required this.uhr});

  /// Speicher, aus dem frisch geladen und in den geschrieben wird.
  final HeroRepository repository;

  /// Liefert den Zeitpunkt für Protokoll und Änderungsstempel.
  final DateTime Function() uhr;

  /// Hängt den Eintrag, den [baue] zum Zeitpunkt der Buchung erzeugt, an das
  /// Würfelprotokoll des Helden [heroId] an.
  Future<HeroState> protokolliere({
    required String heroId,
    required DiceLogEntry Function(DateTime zeitpunkt) baue,
  }) {
    final jetzt = uhr();
    return aendereGespeichertenZustand(
      repository: repository,
      heroId: heroId,
      uhr: () => jetzt,
      aenderung: (aktuell) => aktuell.withAppendedDiceLog(baue(jetzt)),
    );
  }
}

String _name(String artefaktName) =>
    artefaktName.trim().isEmpty ? 'Artefakt' : artefaktName.trim();

/// Baut den Protokolleintrag einer Auslösung des Spruchspeichers.
///
/// Nennt die Zauber der Ladung und das Ziel; es gibt keinen Wurf und keine
/// Kosten. Der Eintrag ist neutral.
DiceLogEntry baueSpruchspeicherProtokoll({
  required String artefaktName,
  required ArtefaktLadung ladung,
  required ArtefaktDaten daten,
  required String ziel,
  required DateTime zeitpunkt,
}) {
  final namen = ladung.zauber
      .map((z) => z.name.trim())
      .where((n) => n.isNotEmpty)
      .join(' + ');
  final frei = daten.ladungen.where((l) => !l.verbraucht).length;
  final teile = <String>[
    if (namen.isNotEmpty) namen,
    'Ladung ausgelöst ($frei von ${daten.ladungen.length} frei)',
    if (ziel.trim().isNotEmpty) 'Ziel: ${ziel.trim()}',
  ];
  return diceLogEntryFromRoll(
    title: 'Spruchspeicher: ${_name(artefaktName)}',
    subtitle: teile.join(' · '),
    diceValues: const <int>[],
    type: ProbeType.genericRoll,
    total: 0,
    timestamp: zeitpunkt,
  );
}

/// Baut den Protokolleintrag eines Aufladevorgangs mit dem Wurf auf die
/// Haltematrix.
DiceLogEntry baueAufladeProtokoll({
  required String artefaktName,
  required int w20,
  required int schadenAb,
  required bool beschaedigt,
  required DateTime zeitpunkt,
}) {
  final ausgang = beschaedigt
      ? 'Haltematrix irreparabel beschädigt'
      : 'Haltematrix unversehrt, Speicher neu geladen';
  return diceLogEntryFromRoll(
    title: 'Aufladen: ${_name(artefaktName)}',
    subtitle: 'W20 $w20 (Schaden ab $schadenAb) → $ausgang',
    diceValues: <int>[w20],
    diceSpec: const DiceSpec(count: 1, sides: 20),
    type: ProbeType.genericRoll,
    total: w20,
    timestamp: zeitpunkt,
  );
}
