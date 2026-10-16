import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Art eines Herkunftsmodifikators (ARCH-02, Herkunftsmerkmale).
enum HeroHerkunftsModifikatorArt {
  /// Direkter Modifikator einer Eigenschaft, z. B. `MU+1`.
  eigenschaft,

  /// Direkter Modifikator eines Basiswerts, z. B. `LEP+2` oder `ASP-1`.
  basiswert,

  /// Freier Herkunftstext ohne eigene Rechenbedeutung.
  frei,
}

/// Ein einzelner Eintrag der strukturierten Herkunftsmodifikatoren.
///
/// [ziel] ist der normalisierte Code (`MU`, `LEP`, `ASP` …) eines direkten
/// Modifikators, [betrag] sein Wert; beide fehlen bei freien Einträgen. [text]
/// ist das ursprüngliche Textfragment, aus dem der Eintrag stammt und das in
/// die Textprojektion für ältere App-Versionen eingeht.
///
/// Ein Eintrag, dessen Rohform diese Version nicht versteht (kein Objekt,
/// fehlende ID, nicht ganzzahliger Betrag …), trägt sie vollständig in
/// [unverstandeneRohdaten] und schreibt sie unverändert zurück.
class HeroHerkunftsModifikator {
  /// Erstellt einen Eintrag.
  const HeroHerkunftsModifikator({
    required this.id,
    this.art = HeroHerkunftsModifikatorArt.frei,
    this.ziel = '',
    this.betrag,
    this.text = '',
    this.unbekannteFelder = const <String, Object?>{},
    this.unbekannteEnumWerte = const <String, Object?>{},
    this.unverstandeneRohdaten,
  });

  /// Stabile, innerhalb des Helden eindeutige ID.
  final String id;

  /// Art des Eintrags.
  final HeroHerkunftsModifikatorArt art;

  /// Normalisierter Zielcode; leer bei freien Einträgen.
  final String ziel;

  /// Ganzzahliger Modifikatorwert; `null` bei freien Einträgen.
  final int? betrag;

  /// Ursprüngliches Textfragment des Eintrags.
  final String text;

  /// JSON-Felder einer neueren App-Version.
  final Map<String, Object?> unbekannteFelder;

  /// Unbekannte Aufzählungswerte einer neueren App-Version.
  final Map<String, Object?> unbekannteEnumWerte;

  /// Vollständige Rohform eines nicht verstandenen Eintrags; `null` sonst.
  final Object? unverstandeneRohdaten;

  /// Alle Schlüssel, die [fromJson] liest.
  static const Set<String> jsonSchluessel = <String>{
    'id',
    'art',
    'ziel',
    'betrag',
    'text',
  };

  /// Ob die Rohform dieses Eintrags unverstanden erhalten wird.
  bool get istUnverstanden => unverstandeneRohdaten != null;

  /// Gibt eine Kopie mit geänderten Feldern zurück.
  ///
  /// Ein unverstandener Eintrag lässt sich nicht ändern.
  HeroHerkunftsModifikator copyWith({
    String? id,
    HeroHerkunftsModifikatorArt? art,
    String? ziel,
    Object? betrag = _unveraendert,
    String? text,
    Map<String, Object?>? unbekannteFelder,
    Map<String, Object?>? unbekannteEnumWerte,
  }) {
    if (istUnverstanden) {
      throw StateError(
        'Ein unverstandener Herkunftseintrag ist nicht änderbar.',
      );
    }
    return HeroHerkunftsModifikator(
      id: id ?? this.id,
      art: art ?? this.art,
      ziel: ziel ?? this.ziel,
      betrag: identical(betrag, _unveraendert) ? this.betrag : betrag as int?,
      text: text ?? this.text,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
      unbekannteEnumWerte:
          unbekannteEnumWerte ??
          ohneGeaenderteEnumWerte(this.unbekannteEnumWerte, {
            'art': art != null && art != this.art,
          }),
    );
  }

  /// Serialisiert den Eintrag; optionale Felder nur bei belegtem Wert.
  Object? toJson() {
    final roh = unverstandeneRohdaten;
    if (roh != null) {
      return identical(roh, _jsonNull) ? null : kopiereJsonRohwert(roh);
    }
    return mitUnbekanntenEnumWerten(
      mitUnbekanntenFeldern(<String, dynamic>{
        'id': id,
        'art': art.name,
        if (ziel.isNotEmpty) 'ziel': ziel,
        if (betrag != null) 'betrag': betrag,
        if (text.isNotEmpty) 'text': text,
      }, unbekannteFelder),
      unbekannteEnumWerte,
    );
  }

  /// Liest einen Eintrag tolerant.
  ///
  /// Was keine verständliche Form hat, bleibt vollständig als Rohdaten
  /// erhalten. Eine unbekannte [art] gilt als `frei`, ihr Rohwert wird
  /// zurückgeschrieben.
  static HeroHerkunftsModifikator fromJson(Object? roh) {
    if (roh is! Map) {
      return HeroHerkunftsModifikator._unverstanden(roh);
    }
    final json = roh.cast<String, dynamic>();
    final id = json['id'];
    final art = json['art'];
    final ziel = json['ziel'];
    final betrag = json['betrag'];
    final text = json['text'];
    final verstanden =
        id is String &&
        id.trim().isNotEmpty &&
        art is String &&
        (ziel == null || ziel is String) &&
        (betrag == null || betrag is int) &&
        (text == null || text is String);
    if (!verstanden) {
      return HeroHerkunftsModifikator._unverstanden(roh);
    }
    final enumRoh = <String, Object?>{};
    return HeroHerkunftsModifikator(
      id: id,
      art: leseEnumWert(
        art,
        'art',
        erkenne: (wert) =>
            enumNachName(HeroHerkunftsModifikatorArt.values, wert),
        ersatz: HeroHerkunftsModifikatorArt.frei,
        unbekannt: enumRoh,
      ),
      ziel: (ziel as String?) ?? '',
      betrag: betrag as int?,
      text: (text as String?) ?? '',
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
      unbekannteEnumWerte: festeEnumWerte(enumRoh),
    );
  }

  HeroHerkunftsModifikator._unverstanden(Object? roh)
    : id = '',
      art = HeroHerkunftsModifikatorArt.frei,
      ziel = '',
      betrag = null,
      text = '',
      unbekannteFelder = const <String, Object?>{},
      unbekannteEnumWerte = const <String, Object?>{},
      // Ein `null`-Eintrag ist ebenfalls unverstanden und braucht einen
      // Marker, der von „verstanden“ (null) unterscheidbar bleibt.
      unverstandeneRohdaten = roh ?? _jsonNull;

  @override
  bool operator ==(Object other) {
    return other is HeroHerkunftsModifikator &&
        other.id == id &&
        other.art == art &&
        other.ziel == ziel &&
        other.betrag == betrag &&
        other.text == text &&
        unbekannteFelderGleich(unbekannteFelder, other.unbekannteFelder) &&
        unbekannteFelderGleich(
          unbekannteEnumWerte,
          other.unbekannteEnumWerte,
        ) &&
        unbekannteFelderGleich(
          <String, Object?>{'roh': unverstandeneRohdaten},
          <String, Object?>{'roh': other.unverstandeneRohdaten},
        );
  }

  @override
  int get hashCode => Object.hash(
    id,
    art,
    ziel,
    betrag,
    text,
    unbekannteFelderHash(unbekannteFelder),
    unbekannteFelderHash(unbekannteEnumWerte),
    istUnverstanden,
  );
}

/// Marker für einen rohen JSON-`null`-Eintrag.
const Object _jsonNull = _JsonNull();

class _JsonNull {
  const _JsonNull();
}

const Object _unveraendert = Object();
