import 'package:dsa_heldenverwaltung/domain/aventurian_date.dart';
import 'package:dsa_heldenverwaltung/domain/copy_with_sentinel.dart';
import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Art eines Artefakts am Inventareintrag.
///
/// Matrixgeber, Spruchspeicher (ladungs-, intervallbasiert, permanent) und
/// Zaubertalisman (Stäbe, Ringe, Dschinnenlampen S. 8 und 16 f.; Wege der
/// Alchimie S. 80–88). Weitere Arten kommen als neue Werte hinzu.
enum ArtefaktArt {
  /// Der zauberkundige Träger lässt die Zauber-AsP einfließen; die
  /// gespeicherte Wirkung ist unveränderlich.
  matrixgeber,

  /// Ladungsbasierter Spruchspeicher, einmalig: nach der letzten Ladung ist
  /// jede Magie des Gegenstands verloren.
  spruchspeicherEinmalig,

  /// Ladungsbasierter Spruchspeicher, aufladbar: sind alle Ladungen
  /// verbraucht, lässt er sich mit Sprüchen desselben Thesiskerns neu laden.
  spruchspeicherAufladbar,

  /// Intervallbasierter Spruchspeicher, semipermanent: Er regeneriert seine
  /// Wirkungsmatrizen innerhalb eines Intervalls (Tag, Woche, Monat, Jahr)
  /// selbst und lässt sich je Intervall nur begrenzt oft auslösen.
  spruchspeicherSemipermanent,

  /// Zaubertalisman (Auxiliator): Der Anwender spricht den Zauber selbst und
  /// lässt zusätzlich Astralenergie in das Artefakt fließen; es gibt
  /// zusätzliche ZfP* (Wege der Alchimie S. 88).
  zaubertalisman,

  /// Permanenter Spruchspeicher („Aeternom“, erschaffen mit INFINITUM): Die
  /// Wirkung besteht ständig. Es gibt weder Ladungen noch Intervall, weder
  /// AsP-Kosten noch einen Auslöser (Stäbe, Ringe, Dschinnenlampen S. 8).
  spruchspeicherPermanent,
}

/// Intervall eines semipermanenten Spruchspeichers (Wege der Alchimie S. 82).
enum ArtefaktIntervall {
  /// Ein Tag.
  tag,

  /// Eine Woche (sieben Tage).
  woche,

  /// Ein Monat (ein Göttermonat zu 30 Tagen).
  monat,

  /// Ein Jahr (365 Tage).
  jahr,
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
    this.pAsP,
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

  /// Permanente AsP, die dieser Zauber im Artefakt bindet.
  ///
  /// Eine Buchführungshilfe: Regelwerklich fallen die permanenten AsP je
  /// Artefakt an (Bruchteil der Gesamtkosten); wer sie je Zauber festhält,
  /// sieht ihre Summe als Gesamtwert (siehe `artefaktPAspGesamt`).
  final int? pAsP;

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
    'pAsP',
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
    Object? pAsP = keepFieldValue,
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
      pAsP: pAsP == keepFieldValue ? this.pAsP : pAsP as int?,
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
      if (pAsP != null) 'pAsP': pAsP,
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
      pAsP: _ganzzahl(json['pAsP']),
      reichweite: text('reichweite'),
      wirkungsdauer: text('wirkungsdauer'),
      zielHinweis: text('zielHinweis'),
      spontaneModifikation: text('spontaneModifikation'),
      notiz: text('notiz'),
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }
}

/// Eine Ladung eines Spruchspeichers.
///
/// Eine Ladung ist eine unabhängig auslösbare Anwendung und kann aus mehreren
/// Zaubern bestehen, die grundsätzlich gemeinsam ausgelöst werden (Wege der
/// Alchimie S. 80). Die stabile [id] ordnet sie beim Konto-Sync zu.
class ArtefaktLadung {
  /// Erstellt eine Ladung.
  const ArtefaktLadung({
    required this.id,
    this.zauber = const <ArtefaktZauber>[],
    this.verbraucht = false,
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Stabile Kennung der Ladung innerhalb des Artefakts.
  final String id;

  /// Die gemeinsam ausgelösten Zauber der Ladung.
  final List<ArtefaktZauber> zauber;

  /// Ob die Ladung schon ausgelöst wurde.
  final bool verbraucht;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schlüssel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'id',
    'zauber',
    'verbraucht',
  };

  /// Gibt eine Kopie mit selektiv überschriebenen Feldern zurück.
  ArtefaktLadung copyWith({
    String? id,
    List<ArtefaktZauber>? zauber,
    bool? verbraucht,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return ArtefaktLadung(
      id: id ?? this.id,
      zauber: zauber ?? this.zauber,
      verbraucht: verbraucht ?? this.verbraucht,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  /// Serialisiert die Ladung.
  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      'id': id,
      'zauber': zauber.map((z) => z.toJson()).toList(),
      'verbraucht': verbraucht,
    }, unbekannteFelder);
  }

  /// Liest eine Ladung tolerant aus JSON.
  static ArtefaktLadung fromJson(Map<String, dynamic> json) {
    final zauberRoh = json['zauber'];
    return ArtefaktLadung(
      id: json['id'] is String ? json['id'] as String : '',
      zauber: zauberRoh is List
          ? zauberRoh
                .whereType<Map>()
                .map((z) => ArtefaktZauber.fromJson(z.cast<String, dynamic>()))
                .toList(growable: false)
          : const <ArtefaktZauber>[],
      verbraucht: (json['verbraucht'] as bool?) ?? false,
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
    this.ladungen = const <ArtefaktLadung>[],
    this.aufladungen = 0,
    this.gesamtAspErschaffung,
    this.intervall = ArtefaktIntervall.woche,
    this.anwendungenProIntervall = 1,
    this.anwendungen = const <AventurianDate>[],
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

  /// Ladungen eines Spruchspeichers; beim Matrixgeber leer.
  final List<ArtefaktLadung> ladungen;

  /// Wie oft der Spruchspeicher schon wieder aufgeladen wurde.
  ///
  /// Nach Wege der Alchimie 2012 steigt mit jedem Aufladen die Gefahr einer
  /// Schädigung der Haltematrix um 1 Punkt (S. 88).
  final int aufladungen;

  /// Gesamt-AsP bei der Erschaffung, einschließlich der AsP des ARCANOVI.
  ///
  /// Beim Aufladen dürfen die neu eingespeicherten Wirkenden Sprüche diese
  /// Summe nicht überschreiten (Wege der Alchimie S. 88).
  final int? gesamtAspErschaffung;

  /// Intervall eines semipermanenten Spruchspeichers.
  final ArtefaktIntervall intervall;

  /// Wie oft ein semipermanenter Spruchspeicher je Intervall ausgelöst werden
  /// kann (mindestens 1).
  final int anwendungenProIntervall;

  /// Zeitpunkte der letzten Anwendungen im aventurischen Kalender.
  ///
  /// Ein leeres Datum steht für eine Anwendung ohne bekanntes Datum; sie
  /// verfällt erst, wenn der Nutzer die Regeneration vermerkt.
  final List<AventurianDate> anwendungen;

  /// Alle gespeicherten Zauber: die der Matrix und die aller Ladungen.
  List<ArtefaktZauber> get alleZauber => <ArtefaktZauber>[
    ...zauber,
    for (final ladung in ladungen) ...ladung.zauber,
  ];

  /// Wer das Artefakt erschaffen hat.
  final String ersteller;

  /// Beschreibung des Auslösers (Schlüsselwort, Geste …).
  final String ausloeser;

  /// Aktionen, die das Betätigen des Auslösers braucht (mindestens 1).
  final int ausloeserAktionen;

  /// Permanent gebundene AsP des Artefakts insgesamt.
  ///
  /// Ein ausdrücklich eingetragener Wert gilt vor der Summe der Zauber-pAsP
  /// (`ArtefaktZauber.pAsP`); `artefaktPAspGesamt` fasst beides zusammen.
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
    'ladungen',
    'aufladungen',
    'gesamtAspErschaffung',
    'intervall',
    'anwendungenProIntervall',
    'anwendungen',
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
    List<ArtefaktLadung>? ladungen,
    int? aufladungen,
    Object? gesamtAspErschaffung = keepFieldValue,
    ArtefaktIntervall? intervall,
    int? anwendungenProIntervall,
    List<AventurianDate>? anwendungen,
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
      ladungen: ladungen ?? this.ladungen,
      aufladungen: aufladungen ?? this.aufladungen,
      gesamtAspErschaffung: gesamtAspErschaffung == keepFieldValue
          ? this.gesamtAspErschaffung
          : gesamtAspErschaffung as int?,
      intervall: intervall ?? this.intervall,
      anwendungenProIntervall:
          anwendungenProIntervall ?? this.anwendungenProIntervall,
      anwendungen: anwendungen ?? this.anwendungen,
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
            'intervall': intervall != null && intervall != this.intervall,
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
        // Nur bei Belegung: Bestandsdaten behalten ihren Inhalts-Hash.
        if (ladungen.isNotEmpty)
          'ladungen': ladungen.map((l) => l.toJson()).toList(),
        if (aufladungen > 0) 'aufladungen': aufladungen,
        if (gesamtAspErschaffung != null)
          'gesamtAspErschaffung': gesamtAspErschaffung,
        if (art == ArtefaktArt.spruchspeicherSemipermanent) ...{
          'intervall': intervall.name,
          'anwendungenProIntervall': anwendungenProIntervall,
        },
        if (anwendungen.isNotEmpty)
          'anwendungen': anwendungen.map((a) => a.toJson()).toList(),
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
    final ladungenRoh = json['ladungen'];
    final anwendungenRoh = json['anwendungen'];
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
      ladungen: ladungenRoh is List
          ? ladungenRoh
                .whereType<Map>()
                .map((l) => ArtefaktLadung.fromJson(l.cast<String, dynamic>()))
                .toList(growable: false)
          : const <ArtefaktLadung>[],
      aufladungen: _ganzzahl(json['aufladungen']) ?? 0,
      gesamtAspErschaffung: _ganzzahl(json['gesamtAspErschaffung']),
      intervall: leseEnumWert(
        json['intervall'],
        'intervall',
        erkenne: (roh) => enumNachName(ArtefaktIntervall.values, roh),
        ersatz: ArtefaktIntervall.woche,
        unbekannt: enumRoh,
      ),
      anwendungenProIntervall: _ganzzahl(json['anwendungenProIntervall']) ?? 1,
      anwendungen: anwendungenRoh is List
          ? anwendungenRoh
                .whereType<Map>()
                .map((a) => AventurianDate.fromJson(a.cast<String, dynamic>()))
                .toList(growable: false)
          : const <AventurianDate>[],
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
