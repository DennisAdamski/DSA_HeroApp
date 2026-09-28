import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Woher die Zuordnung eines erworbenen Merkmals zum Katalog stammt.
enum HeroMerkmalZuordnung {
  /// Im Katalogdialog gewaehlt oder vom Nutzer bestaetigt.
  katalog,

  /// Beim Speichern automatisch aus dem Alttext zugeordnet (ARCH-02).
  migration,

  /// Freier Eintrag ohne Katalogbezug (eigenes Merkmal, Hausnotiz, `LEP+2`).
  frei,
}

/// Ein erworbener Vor- oder Nachteil eines Helden (ARCH-02).
///
/// Maßgeblich fuer Regeln ist die stabile [katalogId] samt [wert] und
/// [auswahl]; der Anzeigename kommt aus dem Katalog. [text] ist das
/// Textfragment, das dieser Eintrag in `HeroSheet.vorteileText` bzw.
/// `nachteileText` beitraegt — diese Felder sind nur noch die Projektion der
/// Liste fuer aeltere App-Versionen. Ein Eintrag ohne [katalogId] ist frei;
/// er wirkt wie bisher ueber den Modifikator-Parser. Mehrdeutig zugeordnete
/// Alttexte bleiben frei und tragen ihre [kandidatenIds] zur Pruefung.
class HeroMerkmal {
  /// Erstellt einen Merkmalseintrag.
  const HeroMerkmal({
    this.katalogId = '',
    required this.text,
    this.wert,
    this.auswahl = '',
    this.kandidatenIds = const <String>[],
    this.zuordnung = HeroMerkmalZuordnung.katalog,
    this.unbekannteFelder = const <String, Object?>{},
    this.unbekannteEnumWerte = const <String, Object?>{},
  });

  /// Stabile Katalog-ID (`adv_…`/`dis_…`); leer bei freien Eintraegen.
  final String katalogId;

  /// Textfragment dieses Eintrags in der Projektion fuer aeltere Apps.
  final String text;

  /// Zahlenwert (Punkte, Stufe); `null`, wenn das Merkmal keinen traegt.
  final int? wert;

  /// Auswahl (`{choice}`), z. B. `KK` oder `Spinnen`; leer ohne Auswahl.
  final String auswahl;

  /// Moegliche Katalog-IDs eines mehrdeutigen Alttexts; nur bei freien
  /// Eintraegen belegt.
  final List<String> kandidatenIds;

  /// Herkunft der Zuordnung.
  final HeroMerkmalZuordnung zuordnung;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten
  /// (siehe `unbekannte_json_felder.dart`).
  final Map<String, Object?> unbekannteFelder;

  /// Unbekannte Aufzaehlungswerte einer neueren App-Version (JSON-Schluessel
  /// -> Rohwert); geschrieben wird der Rohwert, bis das Feld geaendert wird.
  final Map<String, Object?> unbekannteEnumWerte;

  /// Alle Schluessel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'katalogId',
    'text',
    'wert',
    'auswahl',
    'kandidatenIds',
    'zuordnung',
  };

  /// Ob der Eintrag einem Katalogeintrag zugeordnet ist.
  bool get istKatalogisiert => katalogId.trim().isNotEmpty;

  /// Ob der Eintrag mehrdeutig zugeordnet wurde und geprueft werden sollte.
  bool get brauchtPruefung => !istKatalogisiert && kandidatenIds.isNotEmpty;

  /// Gibt eine Kopie mit geaenderten Feldern zurueck.
  ///
  /// [wert] nimmt `null` als echten Wert an (Wert entfernen); ohne Angabe
  /// bleibt der bisherige Wert.
  HeroMerkmal copyWith({
    String? katalogId,
    String? text,
    Object? wert = _unveraendert,
    String? auswahl,
    List<String>? kandidatenIds,
    HeroMerkmalZuordnung? zuordnung,
    Map<String, Object?>? unbekannteFelder,
    Map<String, Object?>? unbekannteEnumWerte,
  }) {
    return HeroMerkmal(
      katalogId: katalogId ?? this.katalogId,
      text: text ?? this.text,
      wert: identical(wert, _unveraendert) ? this.wert : wert as int?,
      auswahl: auswahl ?? this.auswahl,
      kandidatenIds: kandidatenIds ?? this.kandidatenIds,
      zuordnung: zuordnung ?? this.zuordnung,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
      unbekannteEnumWerte:
          unbekannteEnumWerte ??
          ohneGeaenderteEnumWerte(this.unbekannteEnumWerte, {
            'zuordnung': zuordnung != null && zuordnung != this.zuordnung,
          }),
    );
  }

  /// Serialisiert den Eintrag; optionale Felder nur bei belegtem Wert.
  Map<String, dynamic> toJson() {
    return mitUnbekanntenEnumWerten(
      mitUnbekanntenFeldern(<String, dynamic>{
        'katalogId': katalogId,
        'text': text,
        if (wert != null) 'wert': wert,
        if (auswahl.isNotEmpty) 'auswahl': auswahl,
        if (kandidatenIds.isNotEmpty) 'kandidatenIds': kandidatenIds,
        'zuordnung': zuordnung.name,
      }, unbekannteFelder),
      unbekannteEnumWerte,
    );
  }

  /// Liest einen Eintrag tolerant; eine unbekannte Zuordnung faellt auf
  /// `katalog` bzw. bei fehlender ID auf `frei` zurueck.
  static HeroMerkmal fromJson(Map<String, dynamic> json) {
    final enumRoh = <String, Object?>{};
    final katalogId = (json['katalogId'] as String?)?.trim() ?? '';
    final zuordnung = leseEnumWert(
      json['zuordnung'],
      'zuordnung',
      erkenne: (roh) => enumNachName(HeroMerkmalZuordnung.values, roh),
      ersatz: katalogId.isEmpty
          ? HeroMerkmalZuordnung.frei
          : HeroMerkmalZuordnung.katalog,
      unbekannt: enumRoh,
    );
    final rohKandidaten = json['kandidatenIds'];
    return HeroMerkmal(
      katalogId: katalogId,
      text: (json['text'] as String?) ?? '',
      wert: (json['wert'] as num?)?.toInt(),
      auswahl: (json['auswahl'] as String?) ?? '',
      kandidatenIds: rohKandidaten is List
          ? List<String>.unmodifiable(rohKandidaten.map((e) => e.toString()))
          : const <String>[],
      zuordnung: zuordnung,
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
      unbekannteEnumWerte: festeEnumWerte(enumRoh),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HeroMerkmal &&
        other.katalogId == katalogId &&
        other.text == text &&
        other.wert == wert &&
        other.auswahl == auswahl &&
        _listenGleich(other.kandidatenIds, kandidatenIds) &&
        other.zuordnung == zuordnung &&
        unbekannteFelderGleich(unbekannteFelder, other.unbekannteFelder) &&
        unbekannteFelderGleich(unbekannteEnumWerte, other.unbekannteEnumWerte);
  }

  @override
  int get hashCode => Object.hash(
    katalogId,
    text,
    wert,
    auswahl,
    Object.hashAll(kandidatenIds),
    zuordnung,
    unbekannteFelderHash(unbekannteFelder),
    unbekannteFelderHash(unbekannteEnumWerte),
  );
}

/// Liest eine Merkmalsliste tolerant; Nicht-Objekte werden uebersprungen.
List<HeroMerkmal> leseHeroMerkmale(Object? roh) {
  if (roh is! List) {
    return const <HeroMerkmal>[];
  }
  return List<HeroMerkmal>.unmodifiable(
    roh.whereType<Map>().map(
      (eintrag) => HeroMerkmal.fromJson(eintrag.cast<String, dynamic>()),
    ),
  );
}

const Object _unveraendert = Object();

bool _listenGleich(List<String> a, List<String> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
