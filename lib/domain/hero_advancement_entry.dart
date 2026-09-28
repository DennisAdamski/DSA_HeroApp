import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Zielart eines geplanten oder übernommenen Steigerungsschritts.
enum AdvancementKind {
  attribute,
  talent,
  spell,
  generalAbility,
  magicAbility,
  karmalAbility,
  combatAbility,
  boughtStat,
  language,
  script,

  /// Einmaliger Manövererwerb, gegebenenfalls pro Kampftalent.
  maneuver,
}

/// Unveränderlicher Steigerungsbefehl und historischer Erwerbsnachweis.
///
/// Kosten stammen aus dem bestätigten Dialog, einschließlich Hausregeln.
/// `-1` als Ausgangswert bedeutet Aktivierung. Erwerbsoptionen dokumentieren
/// unter anderem Varianten, Repräsentationen und bestätigte Meisterentscheide.
class HeroAdvancementEntry {
  /// Übernimmt die Erwerbsentscheidung und schützt ihre Optionen vor Mutation.
  HeroAdvancementEntry({
    required this.id,
    required this.sessionId,
    required this.createdAt,
    required this.kind,
    required this.targetId,
    required this.label,
    this.fromValue,
    this.toValue,
    required this.apCost,
    this.seSpent = 0,
    Map<String, String> options = const {},
    this.unbekannteFelder = const <String, Object?>{},
  }) : options = Map<String, String>.unmodifiable(options);

  final String id;
  final String sessionId;
  final DateTime createdAt;
  final AdvancementKind kind;
  final String targetId;
  final String label;
  final int? fromValue;
  final int? toValue;
  final int apCost;
  final int seSpent;
  final Map<String, String> options;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schluessel, die [fromJson] liest — einschliesslich der nur bedingt
  /// geschriebenen; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'id',
    'sessionId',
    'createdAt',
    'kind',
    'targetId',
    'label',
    'fromValue',
    'toValue',
    'apCost',
    'seSpent',
    'options',
  };

  /// Serialisiert den vollständigen Erwerbsnachweis für Export und Persistenz.
  Map<String, dynamic> toJson() => mitUnbekanntenFeldern(<String, dynamic>{
    'id': id,
    'sessionId': sessionId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'kind': kind.name,
    'targetId': targetId,
    'label': label,
    if (fromValue != null) 'fromValue': fromValue,
    if (toValue != null) 'toValue': toValue,
    'apCost': apCost,
    'seSpent': seSpent,
    'options': options,
  }, unbekannteFelder);

  /// Lädt einen Erwerbsnachweis, ohne fehlende Historie zu erfinden.
  static HeroAdvancementEntry fromJson(Map<String, dynamic> json) {
    final rawOptions = (json['options'] as Map?) ?? const {};
    return HeroAdvancementEntry(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      kind: AdvancementKind.values.byName(json['kind'] as String),
      targetId: json['targetId'] as String,
      label: json['label'] as String? ?? '',
      fromValue: (json['fromValue'] as num?)?.toInt(),
      toValue: (json['toValue'] as num?)?.toInt(),
      apCost: (json['apCost'] as num?)?.toInt() ?? 0,
      seSpent: (json['seSpent'] as num?)?.toInt() ?? 0,
      options: rawOptions.map((key, value) => MapEntry('$key', '$value')),
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }
}

/// Verlaufseintrag, dessen Steigerungsart diese App-Version nicht kennt.
///
/// Stammt aus einer neueren Version. Er wird weder angezeigt noch
/// ausgewertet, bleibt aber an seiner Stelle im Verlauf erhalten, statt den
/// ganzen Helden unlesbar zu machen (Befund ARCH-07-B5).
class UnbekannterVerlaufseintrag {
  /// Haelt den Rohwert fest, der beim Speichern zurueckgeschrieben wird.
  const UnbekannterVerlaufseintrag({
    required this.position,
    required this.json,
  });

  /// Index im gespeicherten Verlauf, an dem der Eintrag wieder erscheint.
  final int position;

  /// Unveraendertes JSON des Eintrags.
  final Map<String, Object?> json;
}

/// Zerlegt einen gespeicherten Verlauf in bekannte und unbekannte Eintraege.
///
/// Nur eine unbekannte Steigerungsart macht einen Eintrag unbekannt; andere
/// Formfehler bleiben Fehler wie bisher.
({
  List<HeroAdvancementEntry> bekannt,
  List<UnbekannterVerlaufseintrag> unbekannt,
})
leseSteigerungsverlauf(List<dynamic> roh) {
  final arten = AdvancementKind.values.asNameMap();
  final bekannt = <HeroAdvancementEntry>[];
  final unbekannt = <UnbekannterVerlaufseintrag>[];
  var position = 0;
  for (final eintrag in roh.whereType<Map>()) {
    final json = eintrag.cast<String, dynamic>();
    if (arten.containsKey(json['kind'])) {
      bekannt.add(HeroAdvancementEntry.fromJson(json));
    } else {
      final kopie = Map<String, Object?>.unmodifiable(
        Map<String, Object?>.of(json),
      );
      unbekannt.add(
        UnbekannterVerlaufseintrag(position: position, json: kopie),
      );
    }
    position++;
  }
  return (
    bekannt: List<HeroAdvancementEntry>.unmodifiable(bekannt),
    unbekannt: List<UnbekannterVerlaufseintrag>.unmodifiable(unbekannt),
  );
}

/// Setzt den Verlauf in gespeicherter Reihenfolge wieder zusammen.
///
/// Neue Eintraege werden nur angehaengt, die Positionen der unbekannten
/// bleiben deshalb gueltig; liegt eine dahinter, folgt sie am Ende.
List<Map<String, dynamic>> schreibeSteigerungsverlauf(
  List<HeroAdvancementEntry> bekannt,
  List<UnbekannterVerlaufseintrag> unbekannt,
) {
  final offen = List<UnbekannterVerlaufseintrag>.of(unbekannt)
    ..sort((a, b) => a.position.compareTo(b.position));
  final ergebnis = <Map<String, dynamic>>[];
  var naechsterBekannter = 0;
  while (naechsterBekannter < bekannt.length || offen.isNotEmpty) {
    final stelle = ergebnis.length;
    final dran =
        offen.isNotEmpty &&
        (offen.first.position <= stelle ||
            naechsterBekannter >= bekannt.length);
    if (dran) {
      ergebnis.add(Map<String, dynamic>.of(offen.removeAt(0).json));
    } else {
      ergebnis.add(bekannt[naechsterBekannter].toJson());
      naechsterBekannter++;
    }
  }
  return ergebnis;
}
