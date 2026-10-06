import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/hero_transfer_codec.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_transfer_bundle.dart';
import 'package:dsa_heldenverwaltung/rules/derived/inventar_menge_rules.dart';

/// Synthetische Bestandshelden unter `test/fixtures/heroes/` (ARCH-07).
///
/// Die Dateien sind Transfer-Bundles, wie sie die App exportiert, und
/// werden **nie** angepasst: Sie stehen fuer Daten, die bereits auf Geraeten
/// und in der Cloud liegen. Ein neues Format bekommt eine neue Datei.
enum Bestandsheld {
  /// Kaempfer mit Nah- und Fernkampfwaffe, Schild, Ruestung, Notiz,
  /// laufendem Abenteuer, Wunde und Wuerfelprotokoll.
  kriegerNormal('f01_krieger_normal'),

  /// Geode mit Repraesentation, Traditionswahl, Zaubern, Ritualen und
  /// aktivem Armatrutz; magische SF unter dem alten Sammelnamen.
  geodeMagisch('f02_geode_magisch'),

  /// Geweihter mit KaP aus der Profession und abgeschalteter Magie.
  geweihterKarmal('f03_geweihter_karmal'),

  /// Epischer Held mit Haupteigenschaften und Aktivierungsregel.
  episch('f04_episch'),

  /// Freitext-Vor-/Nachteile mit unerkannten Fragmenten und einem
  /// Inspector-Wert nur in `persistentMods`, `statModifiers` leer — der
  /// Ausloeser von Befund ARCH-07-B1.
  freitextMerkmale('f05_freitext_merkmale'),

  /// Je zwei gleichnamige Waffen, Geschosse und Ruestungsteile mit
  /// unterschiedlichen Inventardaten, dazu ein manueller Namensvetter.
  gleichnamigeAusruestung('f06_gleichnamige_ausruestung'),

  /// Handgeschriebener Altstand: Transferversion 1, ohne `schemaVersion`,
  /// nur alte Schluessel (`attributes`, `mainWeapon`, `offhand`, ...).
  legacySchema1('f07_legacy_schema1'),

  /// Held mit Schemaversion 27 und uebernommener Steigerungshistorie.
  steigerungshistorie('f08_steigerungshistorie'),

  /// Wie [steigerungshistorie], der letzte Verlaufseintrag hat aber eine
  /// Steigerungsart aus einer neueren App-Version. Bis zur Behebung von
  /// Befund ARCH-07-B5 machte er den ganzen Helden unlesbar.
  unbekannteSteigerungsart('f08b_unbekannte_steigerungsart'),

  /// Vor- und Nachteile im strukturierten Format (ARCH-02): katalogisierte
  /// Eintraege mit Wirkung, freie Fragmente (`LEP+2`, eigener Tick) und ein
  /// mehrdeutiger Alttext mit Kandidaten. Text = Projektion der Liste.
  strukturierteMerkmale('f09_strukturierte_merkmale');

  const Bestandsheld(this.datei);

  /// Dateiname ohne Endung.
  final String datei;

  /// `true`, wenn die Datei vom aktuellen Export erzeugt wurde; nur dann
  /// ist ein Import eine Identitaetsabbildung des Heldeninhalts.
  bool get istAktuellesFormat => this != legacySchema1;
}

/// Liest eine Fixture-Datei als Text.
String ladeBestandsheldRoh(String datei) {
  return File('test/fixtures/heroes/$datei.json').readAsStringSync();
}

/// Liest eine Fixture als rohe JSON-Map, ohne Modell dazwischen.
Map<String, dynamic> ladeBestandsheldJson(Bestandsheld held) {
  final decoded = jsonDecode(ladeBestandsheldRoh(held.datei));
  return (decoded as Map).cast<String, dynamic>();
}

/// Dekodiert eine Fixture ueber denselben Codec wie der App-Import.
HeroTransferBundle ladeBestandsheld(Bestandsheld held) {
  return const HeroTransferCodec().decode(ladeBestandsheldRoh(held.datei));
}

/// Tiefe Kopie ohne den Zeitstempel `lastModified` auf oberster Ebene.
///
/// Der Zeitstempel geht nicht in die Inhalts-Hashes ein und wird je nach
/// Repository gesetzt oder nicht; fuer Inhaltsvergleiche zaehlt er nicht.
Map<String, dynamic> ohneZeitstempel(Map<String, dynamic> json) {
  final kopie = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
  kopie.remove('lastModified');
  return kopie;
}

/// Liefert alle Pfade, an denen sich zwei JSON-Strukturen unterscheiden.
///
/// Reihenfolgestreng: umsortierte Listen gelten als Aenderung. Pfade haben
/// die Form `combatConfig/weapons/1/name`.
List<String> jsonUnterschiede(
  Object? vorher,
  Object? nachher, [
  String pfad = '',
]) {
  if (vorher is Map && nachher is Map) {
    final schluessel = <Object?>{...vorher.keys, ...nachher.keys};
    return <String>[
      for (final key in schluessel)
        ...jsonUnterschiede(vorher[key], nachher[key], _kind(pfad, '$key')),
    ];
  }
  if (vorher is List && nachher is List) {
    final laenge = vorher.length > nachher.length
        ? vorher.length
        : nachher.length;
    return <String>[
      for (var i = 0; i < laenge; i++)
        ...jsonUnterschiede(
          i < vorher.length ? vorher[i] : null,
          i < nachher.length ? nachher[i] : null,
          _kind(pfad, '$i'),
        ),
    ];
  }
  return vorher == nachher ? const <String>[] : <String>[pfad];
}

// Haengt ein Pfadsegment an.
String _kind(String pfad, String segment) {
  return pfad.isEmpty ? segment : '$pfad/$segment';
}

/// Prueft, dass sich [nachher] von [vorher] nur unter [erlaubtePfade]
/// unterscheidet.
///
/// Ein erlaubter Pfad deckt sich selbst und alles darunter ab
/// (`talents/tal_klettern` erlaubt auch `talents/tal_klettern/talentValue`).
/// Die Fehlermeldung nennt jeden unerwarteten Pfad.
void expectNurGeaendert(
  Map<String, dynamic> vorher,
  Map<String, dynamic> nachher,
  Set<String> erlaubtePfade, {
  String? grund,
}) {
  bool erlaubt(String pfad) {
    return erlaubtePfade.any(
      (prefix) => pfad == prefix || pfad.startsWith('$prefix/'),
    );
  }

  final unerwartet = jsonUnterschiede(
    vorher,
    nachher,
  ).where((pfad) => !erlaubt(pfad)).toList(growable: false);
  expect(
    unerwartet,
    isEmpty,
    reason: '${grund ?? 'Unerwartete Änderung'}: ${unerwartet.join(', ')}',
  );
}

/// Legt ein temporaeres Verzeichnis fuer echte Hive-Boxen an.
///
/// Das Aufraeumen ist tolerant: Unter Windows scheitert das Loeschen, solange
/// eine Box noch offen ist. Tests muessen ihre Repositories deshalb vorher
/// schliessen; ein liegengebliebener Ordner laesst den Test nicht scheitern.
Future<String> hiveTempVerzeichnis(String praefix) async {
  final verzeichnis = await Directory.systemTemp.createTemp(praefix);
  addTearDown(() async {
    try {
      await verzeichnis.delete(recursive: true);
    } on FileSystemException {
      // Offene Datei-Handles unter Windows; der Systemtemp raeumt spaeter auf.
    }
  });
  return verzeichnis.path;
}

/// JSON-Pfade, die das erste Speichern ergänzt (ARCH-03): je
/// Inventareintrag die Instanz-ID und bei rein ganzzahliger Anzahl die
/// Menge, dazu je benanntem Slot den Verweis auf seine Instanz
/// ([slotInstanzPfade]). Laden ergänzt keinen davon.
Set<String> ersteSpeicherungPfade(HeroSheet held) {
  final eintraege = held.inventoryEntries;
  return <String>{
    for (var i = 0; i < eintraege.length; i++) ...<String>{
      'inventoryEntries/$i/instanzId',
      if (inventarZahlAusText(eintraege[i].anzahl) != null)
        'inventoryEntries/$i/menge',
    },
    ...slotInstanzPfade(held),
  };
}

/// JSON-Pfade von `inventarInstanzId` an jedem benannten Slot von [held]:
/// Waffen samt Geschossen (auch an der gespiegelten aktiven Waffe
/// `mainWeapon`), Rüstungsstücke und Nebenhand-Teile.
Set<String> slotInstanzPfade(HeroSheet held) {
  final kampf = held.combatConfig;
  Iterable<String> waffe(String pfad, MainWeaponSlot slot) sync* {
    if (slot.name.trim().isEmpty) return;
    yield '$pfad/inventarInstanzId';
    if (!slot.fuehrtGeschosse) return;
    final geschosse = slot.rangedProfile.projectiles;
    for (var j = 0; j < geschosse.length; j++) {
      if (geschosse[j].name.trim().isEmpty) continue;
      yield '$pfad/rangedProfile/projectiles/$j/inventarInstanzId';
    }
  }

  final slots = kampf.weaponSlots;
  final aktiv = kampf.selectedWeaponOrNull ?? kampf.mainWeapon;
  final ruestung = kampf.armor.pieces;
  final nebenhand = kampf.offhandEquipment;
  return <String>{
    for (var i = 0; i < slots.length; i++)
      ...waffe('combatConfig/weapons/$i', slots[i]),
    ...waffe('combatConfig/mainWeapon', aktiv),
    for (var i = 0; i < ruestung.length; i++)
      if (ruestung[i].name.trim().isNotEmpty)
        'combatConfig/armor/pieces/$i/inventarInstanzId',
    for (var i = 0; i < nebenhand.length; i++)
      if (nebenhand[i].name.trim().isNotEmpty)
        'combatConfig/offhandEquipment/$i/inventarInstanzId',
  };
}
