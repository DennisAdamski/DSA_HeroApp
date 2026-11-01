import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Breite einer Kachel im Raster der Spielansicht (SPIEL-07).
///
/// Gemessen in Rastereinheiten; wie viele Einheiten nebeneinander passen,
/// entscheidet die Breite der Ansicht. Eine Kachel wird auf die vorhandene
/// Spaltenzahl gekappt.
enum SpielkachelBreite {
  /// Eine Rastereinheit.
  schmal,

  /// Zwei Rastereinheiten.
  mittel,

  /// Die ganze Zeile.
  voll,
}

/// Gespeicherte Einstellung einer Kachel der Spielansicht.
///
/// Die [id] benennt die Kachel (`kampf`, `dabei` …). Eine ID, die diese
/// App-Version nicht kennt, bleibt mit allen Feldern erhalten. Die Listen-
/// reihenfolge in [HeroSpielansicht.kacheln] ist die Anzeigereihenfolge.
class HeroSpielkachel {
  /// Einstellung der Kachel [id].
  const HeroSpielkachel({
    required this.id,
    this.breite,
    this.ausgeblendet = false,
    this.eingeklappt = false,
    this.unbekannteFelder = const <String, Object?>{},
    this.unbekannteEnumWerte = const <String, Object?>{},
  });

  /// Kennung der Kachel.
  final String id;

  /// Gewählte Breite; `null` nimmt die Standardbreite der Kachel.
  final SpielkachelBreite? breite;

  /// Ob die Kachel von der Seite genommen ist. Nur bei `true` im JSON.
  final bool ausgeblendet;

  /// Ob die Kachel nur ihren Kopf zeigt. Nur bei `true` im JSON.
  final bool eingeklappt;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten.
  final Map<String, Object?> unbekannteFelder;

  /// Unbekannte Rohwerte bekannter Aufzählungsfelder (`breite`).
  final Map<String, Object?> unbekannteEnumWerte;

  /// Alle Schlüssel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{
    'id',
    'breite',
    'ausgeblendet',
    'eingeklappt',
  };

  HeroSpielkachel copyWith({
    String? id,
    Object? breite = _unveraendert,
    bool? ausgeblendet,
    bool? eingeklappt,
    Map<String, Object?>? unbekannteFelder,
    Map<String, Object?>? unbekannteEnumWerte,
  }) {
    return HeroSpielkachel(
      id: id ?? this.id,
      breite: identical(breite, _unveraendert)
          ? this.breite
          : breite as SpielkachelBreite?,
      ausgeblendet: ausgeblendet ?? this.ausgeblendet,
      eingeklappt: eingeklappt ?? this.eingeklappt,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
      unbekannteEnumWerte:
          unbekannteEnumWerte ??
          ohneGeaenderteEnumWerte(this.unbekannteEnumWerte, {
            // Nur ein anderer Wert ändert; wer den Ersatz durchreicht, lässt den
            // Rohwert einer neueren Version stehen.
            'breite':
                !identical(breite, _unveraendert) && breite != this.breite,
          }),
    );
  }

  Map<String, dynamic> toJson() {
    return mitUnbekanntenEnumWerten(
      mitUnbekanntenFeldern(<String, dynamic>{
        'id': id,
        if (breite != null) 'breite': breite!.name,
        if (ausgeblendet) 'ausgeblendet': true,
        if (eingeklappt) 'eingeklappt': true,
      }, unbekannteFelder),
      unbekannteEnumWerte,
    );
  }

  /// Liest eine Kachel; `null` ohne verwertbare [id].
  static HeroSpielkachel? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.trim().isEmpty) return null;
    final enumRoh = <String, Object?>{};
    return HeroSpielkachel(
      id: id,
      breite: leseEnumWert<SpielkachelBreite?>(
        json['breite'],
        'breite',
        erkenne: (roh) => enumNachName(SpielkachelBreite.values, roh),
        ersatz: null,
        unbekannt: enumRoh,
      ),
      ausgeblendet: json['ausgeblendet'] == true,
      eingeklappt: json['eingeklappt'] == true,
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
      unbekannteEnumWerte: festeEnumWerte(enumRoh),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HeroSpielkachel &&
        other.id == id &&
        other.breite == breite &&
        other.ausgeblendet == ausgeblendet &&
        other.eingeklappt == eingeklappt &&
        unbekannteFelderGleich(unbekannteFelder, other.unbekannteFelder) &&
        unbekannteFelderGleich(unbekannteEnumWerte, other.unbekannteEnumWerte);
  }

  @override
  int get hashCode => Object.hash(
    id,
    breite,
    ausgeblendet,
    eingeklappt,
    unbekannteFelderHash(unbekannteFelder),
    unbekannteFelderHash(unbekannteEnumWerte),
  );
}

/// Vom Spieler angepasste Spielansicht eines Helden (SPIEL-07).
///
/// Persönliche Anordnung wie `HeroSheet.probenFavoriten`: sie läuft mit dem
/// Helden über den Konto-Sync. Die Kacheln tragen eine `id`, damit
/// `fuehreSyncZusammen` zwei Geräte je Kachel zusammenführt. Was eine Kachel
/// erlaubt (Breiten, Ausblenden, Einklappen), legt die Oberfläche fest; das
/// Modell speichert nur die Wahl.
class HeroSpielansicht {
  /// Anordnung aus [kacheln] in Anzeigereihenfolge.
  const HeroSpielansicht({
    this.kacheln = const <HeroSpielkachel>[],
    this.unbekannteFelder = const <String, Object?>{},
  });

  /// Gespeicherte Kacheln in Anzeigereihenfolge.
  final List<HeroSpielkachel> kacheln;

  /// JSON-Felder einer neueren App-Version; bleiben beim Speichern erhalten.
  final Map<String, Object?> unbekannteFelder;

  /// Alle Schlüssel, die [fromJson] liest; alles andere bleibt erhalten.
  static const Set<String> jsonSchluessel = <String>{'kacheln'};

  /// Gespeicherte Einstellung der Kachel [id] oder `null`.
  HeroSpielkachel? kachel(String id) {
    for (final kachel in kacheln) {
      if (kachel.id == id) return kachel;
    }
    return null;
  }

  HeroSpielansicht copyWith({
    List<HeroSpielkachel>? kacheln,
    Map<String, Object?>? unbekannteFelder,
  }) {
    return HeroSpielansicht(
      kacheln: kacheln ?? this.kacheln,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
    );
  }

  Map<String, dynamic> toJson() {
    return mitUnbekanntenFeldern(<String, dynamic>{
      'kacheln': kacheln.map((k) => k.toJson()).toList(growable: false),
    }, unbekannteFelder);
  }

  /// Liest die Anordnung; doppelte IDs und unlesbare Kacheln entfallen.
  static HeroSpielansicht fromJson(Map<String, dynamic> json) {
    final roh = json['kacheln'];
    final gesehen = <String>{};
    final kacheln = <HeroSpielkachel>[];
    if (roh is List) {
      for (final eintrag in roh) {
        if (eintrag is! Map) continue;
        final kachel = HeroSpielkachel.fromJson(
          Map<String, dynamic>.from(eintrag),
        );
        if (kachel != null && gesehen.add(kachel.id)) kacheln.add(kachel);
      }
    }
    return HeroSpielansicht(
      kacheln: List<HeroSpielkachel>.unmodifiable(kacheln),
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! HeroSpielansicht ||
        other.kacheln.length != kacheln.length ||
        !unbekannteFelderGleich(unbekannteFelder, other.unbekannteFelder)) {
      return false;
    }
    for (var i = 0; i < kacheln.length; i++) {
      if (other.kacheln[i] != kacheln[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(kacheln),
    unbekannteFelderHash(unbekannteFelder),
  );
}

const Object _unveraendert = Object();
