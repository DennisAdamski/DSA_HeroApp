// Gezielte Änderungen an den Modifikatoren des Heldenbogens (ARCH-05).
//
// Die Oberfläche beschreibt, welcher Modifikator sich wie ändert; angewendet
// wird die Änderung erst auf den frisch geladenen Helden. So zählt jeder
// schnelle Klick, und Modifikatoren, die ein anderer Weg zwischenzeitlich
// gespeichert hat, bleiben stehen.

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ressourcen_aenderung_rules.dart';

/// Die im Inspector bedienbaren Dauermodifikatoren (`persistentMods`).
enum Dauermodifikator {
  /// INI-Basiswert.
  iniBase,

  /// Geschwindigkeit.
  gs,

  /// Ausweichen.
  ausweichen,

  /// Parade.
  pa,

  /// Attacke.
  at,

  /// Rüstungsschutz.
  rs,
}

/// Liefert den Wert von [art] in [mods].
int dauermodifikatorWert(StatModifiers mods, Dauermodifikator art) {
  return switch (art) {
    Dauermodifikator.iniBase => mods.iniBase,
    Dauermodifikator.gs => mods.gs,
    Dauermodifikator.ausweichen => mods.ausweichen,
    Dauermodifikator.pa => mods.pa,
    Dauermodifikator.at => mods.at,
    Dauermodifikator.rs => mods.rs,
  };
}

/// Ändert genau den Dauermodifikator [art] des Helden um [aenderung].
///
/// Gerechnet wird ab dem Wert in [held], also dem gespeicherten Stand. Die
/// übrigen Modifikatoren und unbekannte Felder bleiben erhalten
/// (`copyWith`). Ändert sich nichts (etwa Zurücksetzen eines Werts, der
/// schon 0 ist), kommt [held] selbst zurück, damit nichts gespeichert wird.
HeroSheet mitDauermodifikator(
  HeroSheet held,
  Dauermodifikator art,
  RessourcenAenderung aenderung,
) {
  final mods = held.persistentMods;
  final bisher = dauermodifikatorWert(mods, art);
  final neu = aenderung.wendeAn(bisher);
  if (neu == bisher) {
    return held;
  }
  final geaendert = switch (art) {
    Dauermodifikator.iniBase => mods.copyWith(iniBase: neu),
    Dauermodifikator.gs => mods.copyWith(gs: neu),
    Dauermodifikator.ausweichen => mods.copyWith(ausweichen: neu),
    Dauermodifikator.pa => mods.copyWith(pa: neu),
    Dauermodifikator.at => mods.copyWith(at: neu),
    Dauermodifikator.rs => mods.copyWith(rs: neu),
  };
  return held.copyWith(persistentMods: geaendert);
}

/// Ersetzt die benannten Modifikatoren des Grundwerts [schluessel]
/// (z. B. `wundschwelle`, `lep`) durch [liste].
///
/// Eine leere [liste] entfernt den Schlüssel. Alle anderen Grundwerte
/// behalten ihre Einträge, auch solche, die seit dem Öffnen des Dialogs
/// anderswo gespeichert wurden.
HeroSheet mitBenanntenStatModifikatoren(
  HeroSheet held,
  String schluessel,
  List<HeroTalentModifier> liste,
) {
  return held.copyWith(
    statModifiers: _mitBenanntenModifikatoren(
      held.statModifiers,
      schluessel,
      liste,
    ),
  );
}

/// Ersetzt die benannten Modifikatoren der Eigenschaft [schluessel]
/// (z. B. `mu`) durch [liste]; wie [mitBenanntenStatModifikatoren].
HeroSheet mitBenanntenEigenschaftsModifikatoren(
  HeroSheet held,
  String schluessel,
  List<HeroTalentModifier> liste,
) {
  return held.copyWith(
    attributeModifiers: _mitBenanntenModifikatoren(
      held.attributeModifiers,
      schluessel,
      liste,
    ),
  );
}

// Kopie von [bisher], in der nur [schluessel] ersetzt oder entfernt ist.
Map<String, List<HeroTalentModifier>> _mitBenanntenModifikatoren(
  Map<String, List<HeroTalentModifier>> bisher,
  String schluessel,
  List<HeroTalentModifier> liste,
) {
  final neu = Map<String, List<HeroTalentModifier>>.of(bisher);
  if (liste.isEmpty) {
    neu.remove(schluessel);
  } else {
    neu[schluessel] = List<HeroTalentModifier>.unmodifiable(liste);
  }
  return Map<String, List<HeroTalentModifier>>.unmodifiable(neu);
}
