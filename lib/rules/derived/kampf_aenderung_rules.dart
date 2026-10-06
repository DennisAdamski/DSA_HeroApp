// Sofortänderungen im Kampf-Tab: Waffenwahl, Geschosse, Nebenhand, Waffen-,
// Rüstungs- und Nebenhandteile (ARCH-05).
//
// Alle Funktionen arbeiten auf der **gespeicherten** Kampfkonfiguration und
// ersetzen nur die Felder, die die Bedienung meint. Slots werden über ihre
// stabile ID getroffen, nicht über ihre Position: Ein anderer Schreibweg kann
// die Liste inzwischen verschoben haben. Slots ohne ID (unbenannt oder vor
// dem ersten Speichern) werden über ihren Inhalt wiedergefunden. Geändert
// wird ausschließlich per `copyWith`, damit unbekannte Felder erhalten
// bleiben.

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';

/// Höchstbestand eines Geschosses; mehr lässt die Bedienung nicht zu.
const int kGeschossHoechstbestand = 9999;

/// Wendet [aenderung] auf die Kampfkonfiguration des gespeicherten Helden an.
///
/// Ändert sich dabei inhaltlich nichts, kommt [held] selbst zurück; dann wird
/// nichts gespeichert (`aendereGespeichertenHelden`).
HeroSheet mitKampfAenderung(
  HeroSheet held,
  CombatConfig Function(CombatConfig aktuell) aenderung,
) {
  final bisher = held.combatConfig;
  final neu = aenderung(bisher);
  final unveraendert =
      stableContentHash(neu.toJson()) == stableContentHash(bisher.toJson());
  if (unveraendert) {
    return held;
  }
  return held.copyWith(combatConfig: neu);
}

/// Macht [waffe] zur aktiven Hauptwaffe, `null` heißt „keine Waffe“.
///
/// [index] ist die angezeigte Position und hilft nur bei Slots ohne ID. Ist
/// die gewählte Waffe bisher die Nebenhand, fällt die Nebenhand weg, wie es
/// die Normalisierung der Kampfkonfiguration vorsieht.
CombatConfig mitAktiverWaffe(
  CombatConfig config,
  MainWeaponSlot? waffe, {
  int? index,
}) {
  if (waffe == null) {
    return config.copyWith(selectedWeaponIndex: -1);
  }
  final position = _findeWaffe(config, waffe, index: index);
  return config.copyWith(selectedWeaponIndex: position);
}

/// Wendet [aenderung] auf den gespeicherten Slot der angezeigten Waffe an.
///
/// Gedacht für Felder, die die Bedienung einzeln setzt (BF, Talent,
/// Entfernung, Geschosswahl); alle übrigen Felder bleiben, wie sie
/// gespeichert sind.
CombatConfig aendereWaffe(
  CombatConfig config,
  MainWeaponSlot angezeigt,
  MainWeaponSlot Function(MainWeaponSlot gespeichert) aenderung, {
  int? index,
}) {
  final slots = List<MainWeaponSlot>.of(config.weaponSlots);
  final position = _findeWaffe(config, angezeigt, index: index);
  slots[position] = aenderung(slots[position]);
  return config.copyWith(weapons: slots);
}

/// Wählt die Entfernungsstufe [stufe] der angezeigten Fernkampfwaffe.
CombatConfig mitEntfernung(
  CombatConfig config,
  MainWeaponSlot waffe,
  int stufe, {
  int? index,
}) {
  return aendereWaffe(config, waffe, (slot) {
    final profil = slot.rangedProfile.copyWith(selectedDistanceIndex: stufe);
    return slot.copyWith(rangedProfile: profil);
  }, index: index);
}

/// Wählt [geschoss] als aktives Geschoss der angezeigten Waffe, `null` heißt
/// „kein Geschoss“.
CombatConfig mitGeschossWahl(
  CombatConfig config,
  MainWeaponSlot waffe,
  RangedProjectile? geschoss, {
  int? index,
  int? geschossIndex,
}) {
  return aendereWaffe(config, waffe, (slot) {
    final position = geschoss == null
        ? -1
        : _findeGeschoss(slot, geschoss, index: geschossIndex);
    final profil = slot.rangedProfile.copyWith(
      selectedProjectileIndex: position,
    );
    return slot.copyWith(rangedProfile: profil);
  }, index: index);
}

/// Verschiebt den Bestand des angezeigten [geschoss] um [delta].
///
/// Gezählt wird vom **gespeicherten** Bestand, damit jeder schnelle Klick
/// zählt; begrenzt auf 0 bis [kGeschossHoechstbestand]. Getroffen wird das
/// angezeigte Geschoss, auch wenn inzwischen ein anderes gewählt ist.
CombatConfig mitGeschossSchritt(
  CombatConfig config,
  MainWeaponSlot waffe,
  RangedProjectile geschoss,
  int delta, {
  int? index,
  int? geschossIndex,
}) {
  return aendereWaffe(config, waffe, (slot) {
    final geschosse = List<RangedProjectile>.of(slot.rangedProfile.projectiles);
    final position = _findeGeschoss(slot, geschoss, index: geschossIndex);
    final gespeichert = geschosse[position];
    final bestand = (gespeichert.count + delta).clamp(
      0,
      kGeschossHoechstbestand,
    );
    geschosse[position] = gespeichert.copyWith(count: bestand);
    final profil = slot.rangedProfile.copyWith(projectiles: geschosse);
    return slot.copyWith(rangedProfile: profil);
  }, index: index);
}

/// Hängt die neu angelegte Waffe [neu] an die gespeicherten Waffen an.
CombatConfig mitNeuerWaffe(CombatConfig config, MainWeaponSlot neu) {
  return config.copyWith(weapons: [...config.weaponSlots, neu]);
}

/// Ersetzt die im Editor bearbeitete Waffe durch das Editorergebnis [neu].
///
/// [ausgang] ist der Stand beim Öffnen des Editors. Wurde die gespeicherte
/// Waffe seitdem anderswo geändert (etwa ihr Geschossbestand), wird die
/// Änderung abgewiesen, statt diese Werte zu überschreiben.
CombatConfig ersetzeWaffe(
  CombatConfig config, {
  required MainWeaponSlot ausgang,
  required MainWeaponSlot neu,
  int? index,
}) {
  final slots = List<MainWeaponSlot>.of(config.weaponSlots);
  final position = _findeWaffe(config, ausgang, index: index);
  if (!_gleicht(slots[position].toJson(), ausgang.toJson(), ausgang.id)) {
    throw StateError('Die Waffe wurde inzwischen geändert.');
  }
  slots[position] = neu;
  return config.copyWith(weapons: slots);
}

/// Entfernt die angezeigte Waffe aus den gespeicherten Waffen.
///
/// Aktive Waffe und Nebenhand rücken mit, wenn sie hinter der entfernten
/// liegen; war die entfernte Waffe aktiv, ist danach keine Waffe gewählt,
/// war sie die Nebenhand, bleibt die Nebenhand leer. Die letzte Waffe lässt
/// sich nicht entfernen.
CombatConfig ohneWaffe(
  CombatConfig config,
  MainWeaponSlot angezeigt, {
  int? index,
}) {
  final slots = List<MainWeaponSlot>.of(config.weaponSlots);
  if (slots.length <= 1) {
    throw StateError('Die letzte Waffe lässt sich nicht entfernen.');
  }
  final position = _findeWaffe(config, angezeigt, index: index);
  slots.removeAt(position);
  final gewaehlt = config.hasSelectedWeapon ? config.selectedWeaponIndex : -1;
  final nebenhand = config.offhandAssignment;
  return config.copyWith(
    weapons: slots,
    selectedWeaponIndex: _nachEntfernen(gewaehlt, position),
    offhandAssignment: nebenhand.copyWith(
      weaponIndex: _nachEntfernen(nebenhand.weaponIndex, position),
    ),
  );
}

/// Belegt die Nebenhand mit [waffe] oder [teil]; ohne beide bleibt sie leer.
///
/// [waffenIndex] und [teilIndex] sind die angezeigten Positionen und helfen
/// nur bei Einträgen ohne ID.
CombatConfig mitNebenhand(
  CombatConfig config, {
  MainWeaponSlot? waffe,
  int? waffenIndex,
  OffhandEquipmentEntry? teil,
  int? teilIndex,
}) {
  final bisher = config.offhandAssignment;
  if (waffe != null) {
    final position = _findeWaffe(config, waffe, index: waffenIndex);
    return config.copyWith(
      offhandAssignment: bisher.copyWith(
        weaponIndex: position,
        equipmentIndex: -1,
      ),
    );
  }
  if (teil != null) {
    final position = _findeNebenhandTeil(config, teil, index: teilIndex);
    return config.copyWith(
      offhandAssignment: bisher.copyWith(
        weaponIndex: -1,
        equipmentIndex: position,
      ),
    );
  }
  return config.copyWith(
    offhandAssignment: bisher.copyWith(weaponIndex: -1, equipmentIndex: -1),
  );
}

/// Legt das Rüstungsteil [neu] an oder ersetzt das im Editor geöffnete
/// [ausgang].
///
/// Wie bei [ersetzeWaffe] wird ein inzwischen anderswo geändertes Teil nicht
/// überschrieben.
CombatConfig mitRuestungsteil(
  CombatConfig config,
  ArmorPiece neu, {
  ArmorPiece? ausgang,
  int? index,
}) {
  final teile = List<ArmorPiece>.of(config.armor.pieces);
  if (ausgang == null) {
    teile.add(neu);
  } else {
    final position = _findeRuestungsteil(config, ausgang, index: index);
    if (!_gleicht(teile[position].toJson(), ausgang.toJson(), ausgang.id)) {
      throw StateError('Das Rüstungsteil wurde inzwischen geändert.');
    }
    teile[position] = neu;
  }
  return config.copyWith(armor: config.armor.copyWith(pieces: teile));
}

/// Entfernt das angezeigte Rüstungsteil.
CombatConfig ohneRuestungsteil(
  CombatConfig config,
  ArmorPiece angezeigt, {
  int? index,
}) {
  final teile = List<ArmorPiece>.of(config.armor.pieces);
  final position = _findeRuestungsteil(config, angezeigt, index: index);
  teile.removeAt(position);
  return config.copyWith(armor: config.armor.copyWith(pieces: teile));
}

/// Legt das Nebenhandteil (Schild oder Parierwaffe) [neu] an oder ersetzt
/// das im Editor geöffnete [ausgang].
///
/// Wie bei [ersetzeWaffe] wird ein inzwischen anderswo geändertes Teil nicht
/// überschrieben.
CombatConfig mitNebenhandTeil(
  CombatConfig config,
  OffhandEquipmentEntry neu, {
  OffhandEquipmentEntry? ausgang,
  int? index,
}) {
  final teile = List<OffhandEquipmentEntry>.of(config.offhandEquipment);
  if (ausgang == null) {
    teile.add(neu);
  } else {
    final position = _findeNebenhandTeil(config, ausgang, index: index);
    if (!_gleicht(teile[position].toJson(), ausgang.toJson(), ausgang.id)) {
      throw StateError('Das Nebenhandteil wurde inzwischen geändert.');
    }
    teile[position] = neu;
  }
  return config.copyWith(offhandEquipment: teile);
}

/// Entfernt das angezeigte Nebenhandteil.
///
/// Eine Nebenhand, die auf ein späteres Teil zeigt, rückt mit; zeigte sie
/// auf das entfernte, bleibt sie leer.
CombatConfig ohneNebenhandTeil(
  CombatConfig config,
  OffhandEquipmentEntry angezeigt, {
  int? index,
}) {
  final teile = List<OffhandEquipmentEntry>.of(config.offhandEquipment);
  final position = _findeNebenhandTeil(config, angezeigt, index: index);
  teile.removeAt(position);
  final nebenhand = config.offhandAssignment;
  return config.copyWith(
    offhandEquipment: teile,
    offhandAssignment: nebenhand.copyWith(
      equipmentIndex: _nachEntfernen(nebenhand.equipmentIndex, position),
    ),
  );
}

/// Gespeicherter Stand der angezeigten Waffe [angezeigt].
///
/// Gefunden wie bei allen Sofortänderungen über die ID, sonst über Inhalt und
/// angezeigte Position [index]; wirft einen [StateError], wenn sie
/// inzwischen entfernt wurde.
MainWeaponSlot gespeicherteWaffe(
  CombatConfig config,
  MainWeaponSlot angezeigt, {
  int? index,
}) {
  return config.weaponSlots[_findeWaffe(config, angezeigt, index: index)];
}

/// Gespeicherter Stand des angezeigten Rüstungsteils; siehe
/// [gespeicherteWaffe].
ArmorPiece gespeichertesRuestungsteil(
  CombatConfig config,
  ArmorPiece angezeigt, {
  int? index,
}) {
  final position = _findeRuestungsteil(config, angezeigt, index: index);
  return config.armor.pieces[position];
}

/// Gespeicherter Stand des angezeigten Nebenhandteils; siehe
/// [gespeicherteWaffe].
OffhandEquipmentEntry gespeichertesNebenhandteil(
  CombatConfig config,
  OffhandEquipmentEntry angezeigt, {
  int? index,
}) {
  final position = _findeNebenhandTeil(config, angezeigt, index: index);
  return config.offhandEquipment[position];
}

// Position eines Verweises, nachdem der Eintrag an [entfernt] weggefallen
// ist: dahinter rückt er auf, auf dem entfernten wird er leer (-1).
int _nachEntfernen(int verweis, int entfernt) {
  if (verweis < 0 || verweis == entfernt) {
    return -1;
  }
  return verweis > entfernt ? verweis - 1 : verweis;
}

// Position der angezeigten Waffe in den gespeicherten Slots.
int _findeWaffe(CombatConfig config, MainWeaponSlot angezeigt, {int? index}) {
  final position = _findePosition(
    config.weaponSlots,
    angezeigt,
    index: index,
    idVon: (slot) => slot.id,
    jsonVon: (slot) => slot.toJson(),
  );
  if (position < 0) {
    throw StateError('Die Waffe wurde inzwischen geändert oder entfernt.');
  }
  return position;
}

// Position des angezeigten Geschosses im gespeicherten [slot].
int _findeGeschoss(
  MainWeaponSlot slot,
  RangedProjectile angezeigt, {
  int? index,
}) {
  final position = _findePosition(
    slot.rangedProfile.projectiles,
    angezeigt,
    index: index,
    idVon: (geschoss) => geschoss.id,
    jsonVon: (geschoss) => geschoss.toJson(),
  );
  if (position < 0) {
    throw StateError('Das Geschoss wurde inzwischen geändert oder entfernt.');
  }
  return position;
}

// Position des angezeigten Rüstungsteils in der gespeicherten Rüstung.
int _findeRuestungsteil(
  CombatConfig config,
  ArmorPiece angezeigt, {
  int? index,
}) {
  final position = _findePosition(
    config.armor.pieces,
    angezeigt,
    index: index,
    idVon: (teil) => teil.id,
    jsonVon: (teil) => teil.toJson(),
  );
  if (position < 0) {
    throw StateError(
      'Das Rüstungsteil wurde inzwischen geändert oder entfernt.',
    );
  }
  return position;
}

// Position des angezeigten Nebenhandteils in der gespeicherten Liste.
int _findeNebenhandTeil(
  CombatConfig config,
  OffhandEquipmentEntry angezeigt, {
  int? index,
}) {
  final position = _findePosition(
    config.offhandEquipment,
    angezeigt,
    index: index,
    idVon: (teil) => teil.id,
    jsonVon: (teil) => teil.toJson(),
  );
  if (position < 0) {
    throw StateError(
      'Das Nebenhandteil wurde inzwischen geändert oder entfernt.',
    );
  }
  return position;
}

// Sucht [angezeigt] in [eintraege], sonst -1.
//
// Mit ID entscheidet allein sie. Ohne ID zählt der Inhalt ohne IDs: Das
// Speichern vergibt benannten Slots erst dabei eine, der angezeigte Stand
// kennt sie dann noch nicht. Die angezeigte Position [index] gewinnt, wenn
// sie inhaltlich passt; sonst gilt der erste gleiche Eintrag.
int _findePosition<T>(
  List<T> eintraege,
  T angezeigt, {
  required int? index,
  required String Function(T eintrag) idVon,
  required Map<String, dynamic> Function(T eintrag) jsonVon,
}) {
  final id = idVon(angezeigt);
  if (id.isNotEmpty) {
    return eintraege.indexWhere((eintrag) => idVon(eintrag) == id);
  }
  final gesucht = stableContentHash(_ohneIds(jsonVon(angezeigt)));
  bool gleicht(T eintrag) =>
      stableContentHash(_ohneIds(jsonVon(eintrag))) == gesucht;
  final passtIndex =
      index != null &&
      index >= 0 &&
      index < eintraege.length &&
      gleicht(eintraege[index]);
  if (passtIndex) {
    return index;
  }
  return eintraege.indexWhere(gleicht);
}

// Ob der gespeicherte Eintrag noch dem angezeigten gleicht; ohne angezeigte
// [id] werden IDs nicht mitverglichen (siehe [_findePosition]). Den Verweis
// auf die Inventarinstanz setzt nur das Speichern; er zählt nie als fremde
// Änderung.
bool _gleicht(
  Map<String, dynamic> gespeichert,
  Map<String, dynamic> angezeigt,
  String id,
) {
  final ohne = id.isNotEmpty ? _abgeleitetBeimSpeichern : _ohneSchluessel;
  return stableContentHash(_ohne(gespeichert, ohne)) ==
      stableContentHash(_ohne(angezeigt, ohne));
}

// Schlüssel, die erst das Speichern ergänzt (ARCH-03).
const Set<String> _abgeleitetBeimSpeichern = <String>{'inventarInstanzId'};

// Dazu die IDs, die das Speichern neuen Slots vergibt.
const Set<String> _ohneSchluessel = <String>{'id', 'inventarInstanzId'};

// JSON ohne `id`-Schlüssel und Instanzverweise auf jeder Ebene.
Object? _ohneIds(Object? wert) => _ohne(wert, _ohneSchluessel);

// [wert] ohne die Schlüssel aus [schluessel], auf jeder Ebene.
Object? _ohne(Object? wert, Set<String> schluessel) {
  if (wert is Map) {
    return <String, Object?>{
      for (final eintrag in wert.entries)
        if (!schluessel.contains(eintrag.key))
          eintrag.key.toString(): _ohne(eintrag.value, schluessel),
    };
  }
  if (wert is List) {
    return wert.map((e) => _ohne(e, schluessel)).toList(growable: false);
  }
  return wert;
}
