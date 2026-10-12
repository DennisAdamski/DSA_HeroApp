import 'package:dsa_heldenverwaltung/domain/hero_herkunfts_modifikator.dart';
import 'package:dsa_heldenverwaltung/domain/unbekannte_json_felder.dart';

/// Die drei Herkunftsgruppen eines Helden (ARCH-02, Herkunftsmerkmale).
enum HeroHerkunft {
  /// Rasse.
  rasse,

  /// Kultur.
  kultur,

  /// Profession.
  profession,
}

/// Versionierter Container der strukturierten Herkunftsmodifikatoren.
///
/// Er steht als optionales Feld `herkunftsModifikatoren` im flachen
/// Helden-JSON und ersetzt dort die Freitexte `rasseModText`,
/// `kulturModText` und `professionModText` als maßgebliche Quelle; die Texte
/// bleiben als Projektion für ältere App-Versionen bestehen.
///
/// Ein fehlender Container (`null` in `HeroBackground`) bedeutet „noch nicht
/// migriert“, ein Container mit drei leeren Listen „ausdrücklich keine
/// Einträge“. Eine unbekannte Formatversion oder ein Wert, der kein Objekt
/// ist, bleibt vollständig in [unverstandeneRohdaten] erhalten und sperrt die
/// Bearbeitung.
class HeroHerkunftsModifikatoren {
  /// Aktuelle Formatversion dieser App-Version.
  static const int aktuelleFormatVersion = 1;

  /// Alle Schlüssel, die [fromJson] liest.
  static const Set<String> jsonSchluessel = <String>{
    'formatVersion',
    'rasse',
    'kultur',
    'profession',
  };

  /// Erstellt einen Container.
  const HeroHerkunftsModifikatoren({
    this.formatVersion = aktuelleFormatVersion,
    this.rasse = const <HeroHerkunftsModifikator>[],
    this.kultur = const <HeroHerkunftsModifikator>[],
    this.profession = const <HeroHerkunftsModifikator>[],
    this.unbekannteFelder = const <String, Object?>{},
    this.unverstandeneGruppen = const <String, Object?>{},
    this.unverstandeneRohdaten,
  });

  /// Formatversion des gelesenen Containers.
  final int formatVersion;

  /// Einträge der Rasse.
  final List<HeroHerkunftsModifikator> rasse;

  /// Einträge der Kultur.
  final List<HeroHerkunftsModifikator> kultur;

  /// Einträge der Profession.
  final List<HeroHerkunftsModifikator> profession;

  /// JSON-Felder einer neueren App-Version auf Containerebene.
  final Map<String, Object?> unbekannteFelder;

  /// Gruppen (Schlüssel `rasse` …), deren Rohwert keine Liste war; sie bleiben
  /// roh erhalten und sind gesperrt.
  final Map<String, Object?> unverstandeneGruppen;

  /// Vollständige Rohform eines nicht verstandenen Containers (unbekannte
  /// Version, kein Objekt); `null` sonst.
  final Object? unverstandeneRohdaten;

  /// Ob die Rohform des ganzen Containers unverstanden erhalten wird.
  bool get istUnverstanden => unverstandeneRohdaten != null;

  /// Ob der Container als Ganzes bearbeitet werden darf.
  ///
  /// Einzelne Gruppen können trotzdem gesperrt sein, siehe
  /// [istGruppeBearbeitbar].
  bool get istBearbeitbar => !istUnverstanden;

  /// Ob mindestens eine Gruppe wegen unsicherer Daten gesperrt ist.
  bool get brauchtPruefung =>
      !istUnverstanden &&
      HeroHerkunft.values.any((h) => !istGruppeBearbeitbar(h));

  /// Einträge der Gruppe [herkunft].
  List<HeroHerkunftsModifikator> eintraegeFuer(HeroHerkunft herkunft) {
    return switch (herkunft) {
      HeroHerkunft.rasse => rasse,
      HeroHerkunft.kultur => kultur,
      HeroHerkunft.profession => profession,
    };
  }

  /// Ob die Gruppe [herkunft] gefahrlos geändert werden darf.
  ///
  /// Gesperrt sind Gruppen mit nicht verstandenem Rohwert, nicht verstandenen
  /// Einträgen oder doppelten IDs, weil eine Änderung sie nicht mehr eindeutig
  /// treffen oder Rohdaten verlieren würde.
  bool istGruppeBearbeitbar(HeroHerkunft herkunft) {
    if (istUnverstanden || unverstandeneGruppen.containsKey(herkunft.name)) {
      return false;
    }
    final ids = <String>{};
    for (final eintrag in eintraegeFuer(herkunft)) {
      if (eintrag.istUnverstanden || !ids.add(eintrag.id)) {
        return false;
      }
    }
    return true;
  }

  /// Gibt eine Kopie mit geänderten Gruppen zurück.
  ///
  /// Wird eine Gruppe ersetzt, entfällt ihr bewahrter Rohwert bewusst.
  HeroHerkunftsModifikatoren copyWith({
    List<HeroHerkunftsModifikator>? rasse,
    List<HeroHerkunftsModifikator>? kultur,
    List<HeroHerkunftsModifikator>? profession,
    Map<String, Object?>? unbekannteFelder,
  }) {
    final gruppen = <String, Object?>{
      for (final eintrag in unverstandeneGruppen.entries)
        if (!(eintrag.key == 'rasse' && rasse != null) &&
            !(eintrag.key == 'kultur' && kultur != null) &&
            !(eintrag.key == 'profession' && profession != null))
          eintrag.key: eintrag.value,
    };
    return HeroHerkunftsModifikatoren(
      formatVersion: formatVersion,
      rasse: rasse ?? this.rasse,
      kultur: kultur ?? this.kultur,
      profession: profession ?? this.profession,
      unbekannteFelder: unbekannteFelder ?? this.unbekannteFelder,
      unverstandeneGruppen: gruppen.isEmpty
          ? const <String, Object?>{}
          : Map<String, Object?>.unmodifiable(gruppen),
      unverstandeneRohdaten: unverstandeneRohdaten,
    );
  }

  /// Serialisiert den Container.
  ///
  /// Nicht verstandene Rohdaten und Gruppen werden unverändert zurückgegeben.
  Object? toJson() {
    final roh = unverstandeneRohdaten;
    if (roh != null) {
      return kopiereJsonRohwert(roh);
    }
    Object? gruppe(HeroHerkunft herkunft) {
      if (unverstandeneGruppen.containsKey(herkunft.name)) {
        return kopiereJsonRohwert(unverstandeneGruppen[herkunft.name]);
      }
      return <Object?>[
        for (final eintrag in eintraegeFuer(herkunft)) eintrag.toJson(),
      ];
    }

    return mitUnbekanntenFeldern(<String, dynamic>{
      'formatVersion': formatVersion,
      'rasse': gruppe(HeroHerkunft.rasse),
      'kultur': gruppe(HeroHerkunft.kultur),
      'profession': gruppe(HeroHerkunft.profession),
    }, unbekannteFelder);
  }

  /// Liest einen Container tolerant aus dem Rohwert des Helden-JSON.
  static HeroHerkunftsModifikatoren fromJson(Object? roh) {
    if (roh is! Map) {
      return HeroHerkunftsModifikatoren(
        unverstandeneRohdaten: kopiereJsonRohwert(roh),
      );
    }
    final json = roh.cast<String, dynamic>();
    final version = json['formatVersion'];
    if (version != aktuelleFormatVersion) {
      return HeroHerkunftsModifikatoren(
        formatVersion: version is int ? version : aktuelleFormatVersion,
        unverstandeneRohdaten: kopiereJsonRohwert(json),
      );
    }
    final unverstandeneGruppen = <String, Object?>{};
    List<HeroHerkunftsModifikator> gruppe(HeroHerkunft herkunft) {
      final wert = json[herkunft.name];
      if (wert == null) {
        return const <HeroHerkunftsModifikator>[];
      }
      if (wert is! List) {
        unverstandeneGruppen[herkunft.name] = kopiereJsonRohwert(wert);
        return const <HeroHerkunftsModifikator>[];
      }
      return List<HeroHerkunftsModifikator>.unmodifiable(
        wert.map(HeroHerkunftsModifikator.fromJson),
      );
    }

    final rasse = gruppe(HeroHerkunft.rasse);
    final kultur = gruppe(HeroHerkunft.kultur);
    final profession = gruppe(HeroHerkunft.profession);
    return HeroHerkunftsModifikatoren(
      rasse: rasse,
      kultur: kultur,
      profession: profession,
      unbekannteFelder: sammleUnbekannteFelder(json, jsonSchluessel),
      unverstandeneGruppen: unverstandeneGruppen.isEmpty
          ? const <String, Object?>{}
          : Map<String, Object?>.unmodifiable(unverstandeneGruppen),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HeroHerkunftsModifikatoren &&
        unbekannteFelderGleich(
          <String, Object?>{'json': toJson()},
          <String, Object?>{'json': other.toJson()},
        );
  }

  @override
  int get hashCode => Object.hash(
    formatVersion,
    rasse.length,
    kultur.length,
    profession.length,
    istUnverstanden,
  );
}
