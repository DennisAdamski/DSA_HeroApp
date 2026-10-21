import 'dart:math';

/// Beitrittscode einer Heldengruppe (`groups_v2`).
///
/// Besteht aus der Gruppen-ID und dem geheimen `joinCode` aus dem
/// Gruppendokument. Nur Mitglieder lesen den Code; wer ihn kennt, darf sich
/// per Firestore-Regel selbst als Mitglied eintragen. Der Besitzer kann den
/// `joinCode` erneuern, ohne die Gruppen-ID zu ändern.
class GruppenBeitrittscode {
  /// Erstellt einen Beitrittscode aus Gruppen-ID und Beitrittsgeheimnis.
  const GruppenBeitrittscode({required this.groupId, required this.joinCode});

  /// Dokument-ID der Gruppe in `groups_v2`.
  final String groupId;

  /// Geheimnis aus dem Gruppendokument.
  final String joinCode;

  static const String _trenner = '.';

  /// Zeichen ohne leicht verwechselbare Paare (0/O, 1/I/L).
  static const String _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  /// Länge eines neu erzeugten Beitrittsgeheimnisses.
  static const int joinCodeLaenge = 12;

  /// Erzeugt ein neues, zufälliges Beitrittsgeheimnis.
  static String erzeugeJoinCode({Random? random}) {
    final zufall = random ?? Random.secure();
    return String.fromCharCodes(
      List<int>.generate(
        joinCodeLaenge,
        (_) => _alphabet.codeUnitAt(zufall.nextInt(_alphabet.length)),
      ),
    );
  }

  /// Teilbare Textform `<groupId>.<joinCode>`.
  String get text => '$groupId$_trenner$joinCode';

  /// Liest die Textform; `null`, wenn sie nicht dem Aufbau entspricht.
  static GruppenBeitrittscode? parse(String eingabe) {
    final bereinigt = eingabe.trim();
    final trenner = bereinigt.lastIndexOf(_trenner);
    if (trenner <= 0 || trenner >= bereinigt.length - 1) {
      return null;
    }
    final groupId = bereinigt.substring(0, trenner);
    final joinCode = bereinigt.substring(trenner + 1);
    // Firestore-Dokument-IDs dürfen keinen Schrägstrich enthalten.
    if (groupId.contains('/') || joinCode.contains(RegExp(r'\s'))) {
      return null;
    }
    return GruppenBeitrittscode(groupId: groupId, joinCode: joinCode);
  }

  @override
  bool operator ==(Object other) =>
      other is GruppenBeitrittscode &&
      other.groupId == groupId &&
      other.joinCode == joinCode;

  @override
  int get hashCode => Object.hash(groupId, joinCode);
}
