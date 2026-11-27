import 'package:flutter/foundation.dart';

import 'package:dsa_heldenverwaltung/domain/sync_errors.dart';

/// Wie `SyncingHeroRepository` nach einem Fehler selbst wieder anläuft
/// (SYNC-12).
///
/// Zwei Lücken ließen den Konto-Sync vor allem im Browser hängen: Ein
/// Firestore-Listener ist nach seinem ersten Fehler endgültig beendet, und ein
/// gescheiterter Upload wartete auf den nächsten manuellen Abgleich. Ein Tab im
/// Hintergrund, ein Standby oder ein Netzwechsel genügten dafür.
///
/// Beide Folgen sind begrenzt: Nach der letzten Wartezeit ruht die
/// Wiederholung, bis die App wieder sichtbar wird oder jemand von Hand
/// abgleicht. Ein dauerhaft fehlschlagender Zugriff kostet so nur wenige
/// Lesevorgänge.
@immutable
class SyncWiederholung {
  /// Erstellt die Wartezeiten.
  const SyncWiederholung({
    this.abgleichNach = const <Duration>[
      Duration(seconds: 10),
      Duration(seconds: 30),
      Duration(minutes: 1),
      Duration(minutes: 2),
      Duration(minutes: 5),
    ],
    this.beobachtungNach = const <Duration>[
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 30),
      Duration(minutes: 1),
      Duration(minutes: 2),
      Duration(minutes: 5),
    ],
  });

  /// Wartezeit vor dem n-ten erneuten Abgleich nach einem Fehler.
  final List<Duration> abgleichNach;

  /// Wartezeit vor dem n-ten Neustart einer abgebrochenen Beobachtung.
  final List<Duration> beobachtungNach;

  /// Ob ein Fehler dieser Art von selbst vergehen kann.
  ///
  /// Konflikte brauchen eine Entscheidung, unlesbare Datensätze eine neuere
  /// App; ein erneuter Abgleich änderte daran nichts. Anmeldefehler werden
  /// wiederholt, weil der Browser das Token nach einem Standby oft erst
  /// verspätet erneuert.
  static bool istVoruebergehend(SyncErrorKind art) => switch (art) {
    SyncErrorKind.network ||
    SyncErrorKind.auth ||
    SyncErrorKind.unknown => true,
    SyncErrorKind.conflict || SyncErrorKind.decode => false,
  };

  /// Wartezeit für [versuch] (ab 0) aus [abstaende] oder `null`, wenn die
  /// Folge ausgeschöpft ist.
  static Duration? wartezeit(List<Duration> abstaende, int versuch) {
    if (versuch < 0 || versuch >= abstaende.length) return null;
    return abstaende[versuch];
  }
}
