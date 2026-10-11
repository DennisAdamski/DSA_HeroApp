import 'package:dsa_heldenverwaltung/domain/copy_with_sentinel.dart';
import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Art eines Artefakts am Inventareintrag.
///
/// Bisher nur der Matrixgeber (Stäbe, Ringe, Dschinnenlampen S. 17; Wege der
/// Alchimie S. 87 f.). Weitere Arten kommen als neue Werte hinzu.
enum ArtefaktArt {
  /// Der zauberkundige Träger lässt die Zauber-AsP einfließen; die
  /// gespeicherte Wirkung ist unveränderlich.
  matrixgeber,
}

/// Stabilität der Speichermatrix eines Matrixgebers.
enum MatrixStabilitaet {
  /// Labil.
  labil,

  /// Stabil.
  stabil,

  /// Sehr stabil.
  sehrStabil,

  /// Unempfindlich.
  unempfindlich,
}

/// Quelle der Regeln für Stabilitätswurf und AsP-Kosten eines Matrixgebers.
///
/// Die beiden Bände weichen voneinander ab; die Fassung steht deshalb am
/// Gegenstand (Nutzerentscheidung vom 11. Oktober 2026).
enum MatrixRegelfassung {
  /// Wege der Alchimie, 2. Auflage 2012: Schwellen 12/17/18, Kosten wie der
  /// Zauber.
  alchimie2012,

  /// Stäbe, Ringe, Dschinnenlampen 2011: Schwellen 10/16/18, Kosten ± W6.
  staebeRinge2011,
}

/// Ein in ein Artefakt gesprochener Zauber samt den Werten des Sprechers.
///
/// Alle Angaben gelten für den Zeitpunkt der Verzauberung. Sie stammen nicht
/// vom Träger und werden nie aus dessen Heldenbogen gelesen.
class ArtefaktZauber {
  /// Erstellt einen gespeicherten Zauber.
  const ArtefaktZauber({
    this.spellId,
    this.name = '',
    this.repraesentation = '',
    this.variante = '',
    this.zfw,
    this.zfpStern,
    this.kostenAsp,
    this.reichweite = '',
    this.wirkungsdauer = '',
    this.zielHinweis = '',
    this.spontaneModifikation = '',
    this.notiz = '',
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Katalog-ID des Zaubers; `null` bei einem freien Zauber.
  final String? spellId;

  /// Name des Zaubers.
  final String name;

  /// Repräsentation, in der der Zauber gesprochen wurde.
  final String repraesentation;

  /// Gewählte Variante des Zaubers; leer = keine Variante.
  final String variante;

  /// ZfW des Sprechers zum Zeitpunkt der Verzauberung.
  final int? zfw;

  /// Beim Einsprechen erzielte ZfP*.
  final int? zfpStern;

  /// AsP, die der Träger beim Auslösen aufbringen muss.
  final int? kostenAsp;

  /// Gespeicherte Reichweite.
  final String reichweite;

  /// Gespeicherte Wirkungsdauer.
  final String wirkungsdauer;

  /// Zielvorgabe (die konkrete Wahl trifft der Anwender).
  final String zielHinweis;

  /// Spontane Modifikation, mit der der Zauber eingesprochen wurde.
  final String spontaneModifikation;

  /// Freie Notiz.
  final String notiz;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schlüssel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'spellId',
    'name',
    'repraesentation',
    'variante',
    'zfw',
    'zfpStern',
    'kostenAsp',
    'reichweite',
    'wirkungsdauer',
    'zielHinweis',
    'spontaneModifikation',
    'notiz',
  };

  /// Gibt eine Kopie mit selektiv überschriebenen Feldern zurück.
  ArtefaktZauber copyWith({
    Object? spellId = keepFieldValue,
    String? name,
    String? repraesentation,
    String? variante,
    Object? zfw = keepFieldValue,
    Object? zfpStern = keepFieldValue,
    Object? kostenAsp = keepFieldValue,
    String? reichweite,
    String? wirkungsdauer,
    String? zielHinweis,
    String? spontaneModifikation,
    String? notiz,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return ArtefaktZauber(
      spellId: spellId == keepFieldValue ? this.spellId : spellId as String?,
      name: name ?? this.name,
      repraesentation: repraesentation ?? this.repraesentation,
      variante: variante ?? this.variante,
      zfw: zfw == keepFieldValue ? this.zfw : zfw as int?,
      zfpStern: zfpStern == keepFieldValue ? this.zfpStern : zfpStern as int?,
      kostenAsp: kostenAsp == keepFieldValue
          ? this.kostenAsp
          : kostenAsp as int?,
      reichweite: reichweite ?? this.reichweite,
      wirkungsdauer: wirkungsdauer ?? this.wirkungsdauer,
      zielHinweis: zielHinweis ?? this.zielHinweis,
      spontaneModifikation: spontaneModifikation ?? this.spontaneModifikation,
      notiz: notiz ?? this.notiz,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  /// Serialisiert den Zauber; optionale Zahlen nur bei Belegung.
  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      if (spellId != null) 'spellId': spellId,
      'name': name,
      'repraesentation': repraesentation,
      // Nur bei gewählter Variante, damit der Schlüssel sonst nicht erscheint.
      if (variante.isNotEmpty) 'variante': variante,
      if (zfw != null) 'zfw': zfw,
      if (zfpStern != null) 'zfpStern': zfpStern,
      if (kostenAsp != null) 'kostenAsp': kostenAsp,
      'reichweite': reichweite,
      'wirkungsdauer': wirkungsdauer,
      'zielHinweis': zielHinweis,
      'spontaneModifikation': spontaneModifikation,
      'notiz': notiz,
    }, unbekannteFelder);
  }

  /// Liest einen Zauber tolerant aus JSON.
  static ArtefaktZauber fromJson(Map<String, dynamic> json) {
    String text(String key) => json[key] is String ? json[key] as String : '';
    return ArtefaktZauber(
      spellId: json['spellId'] as String?,
      name: text('name'),
      repraesentation: text('repraesentation'),
      variante: text('variante'),
      zfw: _ganzzahl(json['zfw']),
      zfpStern: _ganzzahl(json['zfpStern']),
      kostenAsp: _ganzzahl(json['kostenAsp']),
      reichweite: text('reichweite'),
      wirkungsdauer: text('wirkungsdauer'),
      zielHinweis: text('zielHinweis'),
      spontaneModifikation: text('spontaneModifikation'),
      notiz: text('notiz'),
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }
}

/// Artefaktdaten eines Inventareintrags (`HeroInventoryEntry.artefaktDaten`).
///
/// Der Eintrag trägt alles, was sonst aus dem Helden käme: welche Zauber in
/// welcher Repräsentation und mit welchem ZfW gesprochen wurden. So kann ein
/// Matrixgeber an einen Träger weitergegeben werden, der den Zauber nicht
/// beherrscht. Nur geschrieben, wenn belegt.
class ArtefaktDaten {
  /// Erstellt Artefaktdaten.
  const ArtefaktDaten({
    this.art = ArtefaktArt.matrixgeber,
    this.stabilitaet = MatrixStabilitaet.stabil,
    this.regelfassung = MatrixRegelfassung.alchimie2012,
    this.zauber = const <ArtefaktZauber>[],
    this.ersteller = '',
    this.ausloeser = '',
    this.ausloeserAktionen = 1,
    this.pAsP,
    this.defekt = false,
    this.unbekannteFelder = const <String, Object?>{},
    this.unbekannteEnumWerte = const <String, Object?>{},
  });

  /// Art des Artefakts.
  final ArtefaktArt art;

  /// Stabilität der Speichermatrix.
  final MatrixStabilitaet stabilitaet;

  /// Regelfassung für Stabilitätswurf und Kosten.
  final MatrixRegelfassung regelfassung;

  /// Gemeinsam ausgelöste Zauber der Matrix.
  final List<ArtefaktZauber> zauber;

  /// Wer das Artefakt erschaffen hat.
  final String ersteller;

  /// Beschreibung des Auslösers (Schlüsselwort, Geste …).
  final String ausloeser;

  /// Aktionen, die das Betätigen des Auslösers braucht (mindestens 1).
  final int ausloeserAktionen;

  /// Permanent gebundene AsP des Artefakts.
  final int? pAsP;

  /// Ob die Matrix irreparabel beschädigt ist.
  final bool defekt;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Unbekannte Aufzählungswerte einer neueren App-Version (JSON-Schlüssel ->
  /// Rohwert; siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteEnumWerte;

  /// Alle Schlüssel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'art',
    'stabilitaet',
    'regelfassung',
    'zauber',
    'ersteller',
    'ausloeser',
    'ausloeserAktionen',
    'pAsP',
    'defekt',
  };

  /// Gibt eine Kopie mit selektiv überschriebenen Feldern zurück.
  ArtefaktDaten copyWith({
    ArtefaktArt? art,
    MatrixStabilitaet? stabilitaet,
    MatrixRegelfassung? regelfassung,
    List<ArtefaktZauber>? zauber,
    String? ersteller,
    String? ausloeser,
    int? ausloeserAktionen,
    Object? pAsP = keepFieldValue,
    bool? defekt,
    Map<String, Object?>? unbekannteFelder,
    Map<String, Object?>? unbekannteEnumWerte,
  }) {
    return ArtefaktDaten(
      art: art ?? this.art,
      stabilitaet: stabilitaet ?? this.stabilitaet,
      regelfassung: regelfassung ?? this.regelfassung,
      zauber: zauber ?? this.zauber,
      ersteller: ersteller ?? this.ersteller,
      ausloeser: ausloeser ?? this.ausloeser,
      ausloeserAktionen: ausloeserAktionen ?? this.ausloeserAktionen,
      pAsP: pAsP == keepFieldValue ? this.pAsP : pAsP as int?,
      defekt: defekt ?? this.defekt,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
      unbekannteEnumWerte:
          unbekannteEnumWerte ??
          ohneGeaenderteEnumWerte(this.unbekannteEnumWerte, {
            'art': art != null && art != this.art,
            'stabilitaet':
                stabilitaet != null && stabilitaet != this.stabilitaet,
            'regelfassung':
                regelfassung != null && regelfassung != this.regelfassung,
          }),
    );
  }

  /// Serialisiert die Artefaktdaten.
  Map<String, dynamic> toJson() {
    return mitUnbekanntenEnumWerten(
      mitUnbekanntenFeldern(<String, dynamic>{
        'art': art.name,
        'stabilitaet': stabilitaet.name,
        'regelfassung': regelfassung.name,
        'zauber': zauber.map((z) => z.toJson()).toList(),
        'ersteller': ersteller,
        'ausloeser': ausloeser,
        'ausloeserAktionen': ausloeserAktionen,
        if (pAsP != null) 'pAsP': pAsP,
        'defekt': defekt,
      }, unbekannteFelder),
      unbekannteEnumWerte,
    );
  }

  /// Liest Artefaktdaten tolerant aus JSON.
  static ArtefaktDaten fromJson(Map<String, dynamic> json) {
    final enumRoh = <String, Object?>{};
    String text(String key) => json[key] is String ? json[key] as String : '';
    final zauberRoh = json['zauber'];
    return ArtefaktDaten(
      art: leseEnumWert(
        json['art'],
        'art',
        erkenne: (roh) => enumNachName(ArtefaktArt.values, roh),
        ersatz: ArtefaktArt.matrixgeber,
        unbekannt: enumRoh,
      ),
      stabilitaet: leseEnumWert(
        json['stabilitaet'],
        'stabilitaet',
        erkenne: (roh) => enumNachName(MatrixStabilitaet.values, roh),
        ersatz: MatrixStabilitaet.stabil,
        unbekannt: enumRoh,
      ),
      regelfassung: leseEnumWert(
        json['regelfassung'],
        'regelfassung',
        erkenne: (roh) => enumNachName(MatrixRegelfassung.values, roh),
        ersatz: MatrixRegelfassung.alchimie2012,
        unbekannt: enumRoh,
      ),
      zauber: zauberRoh is List
          ? zauberRoh
                .whereType<Map>()
                .map((z) => ArtefaktZauber.fromJson(z.cast<String, dynamic>()))
                .toList(growable: false)
          : const <ArtefaktZauber>[],
      ersteller: text('ersteller'),
      ausloeser: text('ausloeser'),
      ausloeserAktionen: _ganzzahl(json['ausloeserAktionen']) ?? 1,
      pAsP: _ganzzahl(json['pAsP']),
      defekt: (json['defekt'] as bool?) ?? false,
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
      unbekannteEnumWerte: festeEnumWerte(enumRoh),
    );
  }
}

// Liest eine Zahl tolerant; alles andere gilt als nicht belegt.
int? _ganzzahl(Object? roh) => roh is num ? roh.toInt() : null;
