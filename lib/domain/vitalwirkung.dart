import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Vorbelegung, mit der ein Verbrauchsgegenstand Vitalwerte beeinflusst
/// (Heiltrank, Verband, Kraftelixier …).
///
/// Die Werte sind nur **Vorschläge** für den Anwendungsdialog: Gewürfelte
/// Wirkungen (etwa „1W6+4 LeP“) trägt der Nutzer beim Anwenden ein, geschlossene
/// Wunden bestimmt er dort selbst. Nichts wird geraten oder automatisch
/// gebucht. Alle Zahlen sind nicht negativ; 0 heißt „keine Vorgabe“.
///
/// Ein Katalogmittel (TRANK) trägt seine Würfelausdrücke als Text in
/// [lepWurf], [aspWurf] und [aupWurf]; sie erscheinen im Dialog als Hinweis am
/// jeweiligen Feld. [lepProWunde] ist die Regel „je so viele zurückgewonnene
/// LeP schließt sich eine Wunde“.
class Vitalwirkung {
  /// Erstellt die Vorbelegung.
  const Vitalwirkung({
    this.lep = 0,
    this.asp = 0,
    this.aup = 0,
    this.wunden = 0,
    this.lepWurf = '',
    this.aspWurf = '',
    this.aupWurf = '',
    this.lepProWunde = 0,
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Vorgeschlagene LeP, die zurückkommen.
  final int lep;

  /// Vorgeschlagene AsP, die zurückkommen.
  final int asp;

  /// Vorgeschlagene AuP, die zurückkommen.
  final int aup;

  /// Vorgeschlagene Zahl der Wunden, die der Gegenstand schließt.
  final int wunden;

  /// Würfelausdruck für die LeP, z. B. `2W6+4`; nur Hinweis, nie gebucht.
  final String lepWurf;

  /// Würfelausdruck für die AsP; nur Hinweis.
  final String aspWurf;

  /// Würfelausdruck für die AuP; nur Hinweis.
  final String aupWurf;

  /// Je so viele zurückgewonnene LeP schließt sich eine Wunde (Heiltrank:
  /// 7); 0 = keine solche Regel.
  final int lepProWunde;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schlüssel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'lep',
    'asp',
    'aup',
    'wunden',
    'lepWurf',
    'aspWurf',
    'aupWurf',
    'lepProWunde',
  };

  /// Ob mindestens ein Vorschlag belegt ist.
  bool get istBelegt =>
      lep > 0 ||
      asp > 0 ||
      aup > 0 ||
      wunden > 0 ||
      lepWurf.isNotEmpty ||
      aspWurf.isNotEmpty ||
      aupWurf.isNotEmpty ||
      lepProWunde > 0;

  /// Gibt eine Kopie mit selektiv überschriebenen Feldern zurück.
  Vitalwirkung copyWith({
    int? lep,
    int? asp,
    int? aup,
    int? wunden,
    String? lepWurf,
    String? aspWurf,
    String? aupWurf,
    int? lepProWunde,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return Vitalwirkung(
      lep: lep ?? this.lep,
      asp: asp ?? this.asp,
      aup: aup ?? this.aup,
      wunden: wunden ?? this.wunden,
      lepWurf: lepWurf ?? this.lepWurf,
      aspWurf: aspWurf ?? this.aspWurf,
      aupWurf: aupWurf ?? this.aupWurf,
      lepProWunde: lepProWunde ?? this.lepProWunde,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  /// Serialisiert nur die belegten Werte.
  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      if (lep != 0) 'lep': lep,
      if (asp != 0) 'asp': asp,
      if (aup != 0) 'aup': aup,
      if (wunden != 0) 'wunden': wunden,
      if (lepWurf.isNotEmpty) 'lepWurf': lepWurf,
      if (aspWurf.isNotEmpty) 'aspWurf': aspWurf,
      if (aupWurf.isNotEmpty) 'aupWurf': aupWurf,
      if (lepProWunde != 0) 'lepProWunde': lepProWunde,
    }, unbekannteFelder);
  }

  /// Liest die Vorbelegung tolerant; negative Zahlen zählen als 0.
  static Vitalwirkung fromJson(Map<String, dynamic> json) {
    int zahl(String schluessel) {
      final wert = (json[schluessel] as num?)?.toInt() ?? 0;
      return wert < 0 ? 0 : wert;
    }

    String text(String schluessel) {
      final wert = json[schluessel];
      return wert is String ? wert.trim() : '';
    }

    return Vitalwirkung(
      lep: zahl('lep'),
      asp: zahl('asp'),
      aup: zahl('aup'),
      wunden: zahl('wunden'),
      lepWurf: text('lepWurf'),
      aspWurf: text('aspWurf'),
      aupWurf: text('aupWurf'),
      lepProWunde: zahl('lepProWunde'),
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }
}
