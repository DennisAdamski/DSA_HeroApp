import 'package:dsa_heldenverwaltung/ablaeufe/zustand_schreiben.dart';
import 'package:dsa_heldenverwaltung/data/hero_repository.dart';
import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/meisterhandwerk_rules.dart';

/// Anwendungsablauf „Meisterhandwerk einsetzen“ (WdH S. 256, WdZ S. 37).
///
/// Bucht auf den frisch gespeicherten Laufzeitzustand genau ein Dokument:
/// die eingesetzten AsP, die Erschöpfung der teuren TaP* und einen neutralen
/// Protokolleintrag, der den Einsatz nachvollziehbar macht. Der Wurf selbst
/// ist schon protokolliert. Reichen die gespeicherten AsP nicht, wird nichts
/// geschrieben und der Fehler an die Oberfläche weitergereicht.
class MeisterhandwerkEinsetzen {
  /// Erzeugt den Ablauf mit Heldenspeicher und Uhr.
  const MeisterhandwerkEinsetzen({required this.repository, required this.uhr});

  /// Speicher, aus dem frisch geladen und in den geschrieben wird.
  final HeroRepository repository;

  /// Liefert den Zeitpunkt für Protokoll und Änderungsstempel.
  final DateTime Function() uhr;

  /// Bucht [buchung] für den Helden [heroId].
  Future<HeroState> buche({
    required String heroId,
    required MeisterhandwerkBuchung buchung,
  }) {
    final jetzt = uhr();
    return aendereGespeichertenZustand(
      repository: repository,
      heroId: heroId,
      uhr: () => jetzt,
      aenderung: (aktuell) {
        if (buchung.asp <= 0 && buchung.erschoepfung <= 0) {
          return aktuell;
        }
        if (aktuell.currentAsp < buchung.asp) {
          throw StateError(
            'Zu wenig AsP: ${buchung.asp} AsP nötig, ${aktuell.currentAsp} '
            'vorhanden.',
          );
        }
        return aktuell
            .copyWith(
              currentAsp: aktuell.currentAsp - buchung.asp,
              erschoepfung: aktuell.erschoepfung + buchung.erschoepfung,
            )
            .withAppendedDiceLog(
              baueMeisterhandwerkProtokoll(buchung, zeitpunkt: jetzt),
            );
      },
    );
  }
}

/// Baut den neutralen Protokolleintrag einer Meisterhandwerk-Buchung.
DiceLogEntry baueMeisterhandwerkProtokoll(
  MeisterhandwerkBuchung buchung, {
  required DateTime zeitpunkt,
}) {
  return DiceLogEntry(
    timestamp: zeitpunkt.toUtc(),
    type: ProbeType.genericRoll,
    title: 'Meisterhandwerk: ${buchung.talent}',
    subtitle: buchung.beschreibung,
    success: true,
    diceValues: const <int>[],
    isNeutral: true,
  );
}
