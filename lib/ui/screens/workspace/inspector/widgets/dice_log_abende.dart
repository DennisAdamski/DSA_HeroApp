import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';

/// Ein Spielabend im Würfelprotokoll: aufeinanderfolgende Würfe ohne lange
/// Pause dazwischen.
class DiceLogAbend {
  /// Erstellt den Abend aus seinen Einträgen (älteste zuerst, nie leer).
  const DiceLogAbend(this.eintraege);

  /// Einträge des Abends in zeitlicher Reihenfolge, ältester zuerst.
  final List<DiceLogEntry> eintraege;

  /// Beginn des Abends in Ortszeit: der Zeitpunkt des ersten Wurfs.
  DateTime get beginn => eintraege.first.timestamp.toLocal();
}

/// Längste Pause zwischen zwei Würfen, die noch zum selben Abend gehört.
///
/// Sechs Stunden trennen eine Runde, die über Mitternacht geht, von der
/// Runde der nächsten Woche, ohne dass jemand „Abend beenden“ drücken muss.
const Duration kDiceLogAbendPause = Duration(hours: 6);

/// Gliedert [chronologisch] in Spielabende, ältester Abend zuerst.
///
/// Ein neuer Abend beginnt, wenn zwischen zwei Würfen mehr als [pause] liegt.
/// Die Einträge werden nach Zeitstempel geordnet, bei gleichem Zeitstempel
/// bleibt die Reihenfolge der Eingabe; so teilt auch ein über Geräte
/// zusammengeführtes Protokoll nicht mitten im Abend. Die Eingabe bleibt
/// unverändert.
List<DiceLogAbend> gruppiereNachSpielabend(
  List<DiceLogEntry> chronologisch, {
  Duration pause = kDiceLogAbendPause,
}) {
  if (chronologisch.isEmpty) return const <DiceLogAbend>[];
  final geordnet =
      [for (var i = 0; i < chronologisch.length; i++) (i, chronologisch[i])]
        ..sort((a, b) {
          final zeit = a.$2.timestamp.compareTo(b.$2.timestamp);
          return zeit != 0 ? zeit : a.$1.compareTo(b.$1);
        });

  final abende = <DiceLogAbend>[];
  var aktuell = <DiceLogEntry>[geordnet.first.$2];
  for (var i = 1; i < geordnet.length; i++) {
    final eintrag = geordnet[i].$2;
    final abstand = eintrag.timestamp.difference(aktuell.last.timestamp);
    if (abstand > pause) {
      abende.add(DiceLogAbend(List<DiceLogEntry>.unmodifiable(aktuell)));
      aktuell = <DiceLogEntry>[];
    }
    aktuell.add(eintrag);
  }
  abende.add(DiceLogAbend(List<DiceLogEntry>.unmodifiable(aktuell)));
  return List<DiceLogAbend>.unmodifiable(abende);
}

const List<String> _wochentage = <String>[
  'Mo',
  'Di',
  'Mi',
  'Do',
  'Fr',
  'Sa',
  'So',
];

/// Überschrift eines Abends: „Heute“, „Gestern“ oder „Fr, 23.10.2026“.
///
/// [beginn] und [jetzt] sind Ortszeiten; verglichen werden nur die
/// Kalendertage.
String diceLogAbendUeberschrift(DateTime beginn, DateTime jetzt) {
  // UTC-Mitternacht, damit eine Zeitumstellung den Tagesabstand nicht um eine
  // Stunde verschiebt.
  final tag = DateTime.utc(beginn.year, beginn.month, beginn.day);
  final heute = DateTime.utc(jetzt.year, jetzt.month, jetzt.day);
  final differenz = heute.difference(tag).inDays;
  if (differenz == 0) return 'Heute';
  if (differenz == 1) return 'Gestern';
  final t = beginn.day.toString().padLeft(2, '0');
  final m = beginn.month.toString().padLeft(2, '0');
  return '${_wochentage[beginn.weekday - 1]}, $t.$m.${beginn.year}';
}
