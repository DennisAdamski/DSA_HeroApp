/// Stufenketten aufeinander aufbauender Sonderfertigkeiten.
///
/// Die Regelwerke kennen Sonderfertigkeiten, die in mehreren Stufen erworben
/// werden — `Eiserner Wille I` vor `II`, `Regeneration I` vor `II`. Jede Stufe
/// hat eigene AP-Kosten und eigene Voraussetzungen und bleibt deshalb ein
/// eigener Katalogeintrag; zusammengehalten werden sie ueber
/// `SpecialAbilityDef.kette`.
///
/// Dieses Modul gruppiert einen Katalog in Ketten und beantwortet die beiden
/// Fragen, die die Erwerbs-UI stellt: Welche Stufe hat der Held schon, und
/// welche ist als naechstes dran?
library;

import 'package:dsa_heldenverwaltung/catalog/special_ability_def.dart';
import 'package:dsa_heldenverwaltung/rules/derived/special_ability_variant_rules.dart';

/// Eine Kette aus mindestens zwei Stufen.
class SpecialAbilityChain {
  /// Erzeugt eine unveraenderliche Kette.
  const SpecialAbilityChain({
    required this.id,
    required this.label,
    required this.stufen,
  });

  /// Gemeinsame Kennung aller Stufen.
  final String id;

  /// Anzeigename der Kette.
  final String label;

  /// Die Stufen, aufsteigend sortiert.
  final List<SpecialAbilityDef> stufen;

  /// Kategorie der Kette — die der ersten Stufe.
  String get kategorie => stufen.first.kategorie;

  /// Ob die Kette nur informativ ist (siehe [SpecialAbilityDef.nurInformation]).
  bool get nurInformation => stufen.first.nurInformation;
}

/// Gruppiert die Eintraege eines Katalogs zu Ketten.
///
/// Eintraege ohne `kette` und Ketten mit nur einer Stufe werden bewusst
/// uebergangen: Eine „Kette“ aus einem Glied ist eine gewoehnliche
/// Sonderfertigkeit und soll auch so aussehen. Die Reihenfolge der Ketten
/// folgt dem ersten Auftreten im Katalog, damit die Anzeige stabil bleibt.
List<SpecialAbilityChain> buildSpecialAbilityChains(
  Iterable<SpecialAbilityDef> katalog,
) {
  final gruppen = <String, List<SpecialAbilityDef>>{};
  final reihenfolge = <String>[];
  for (final def in katalog) {
    final id = def.kette?.id.trim() ?? '';
    if (id.isEmpty) {
      continue;
    }
    if (gruppen.putIfAbsent(id, () => <SpecialAbilityDef>[]).isEmpty) {
      reihenfolge.add(id);
    }
    gruppen[id]!.add(def);
  }

  final ketten = <SpecialAbilityChain>[];
  for (final id in reihenfolge) {
    final stufen = gruppen[id]!
      ..sort((a, b) => (a.kette!.stufe).compareTo(b.kette!.stufe));
    if (stufen.length < 2) {
      continue;
    }
    final label = stufen.first.kette!.label.trim();
    ketten.add(
      SpecialAbilityChain(
        id: id,
        label: label.isEmpty ? _basisName(stufen.first.name) : label,
        stufen: List<SpecialAbilityDef>.unmodifiable(stufen),
      ),
    );
  }
  return List<SpecialAbilityChain>.unmodifiable(ketten);
}

/// Alle Eintraege, die von [buildSpecialAbilityChains] nicht erfasst werden.
///
/// Zusammen mit den Ketten ergibt das wieder den vollstaendigen Katalog — die
/// UI kann also beides nebeneinander anzeigen, ohne etwas zu verlieren.
List<SpecialAbilityDef> kettenloseEintraege(
  Iterable<SpecialAbilityDef> katalog,
) {
  final kettenIds = buildSpecialAbilityChains(katalog)
      .map((kette) => kette.id)
      .toSet();
  return katalog
      .where((def) => !kettenIds.contains(def.kette?.id.trim() ?? ''))
      .toList(growable: false);
}

/// Die hoechste Stufe der Kette, die der Held bereits erworben hat. `0`, wenn
/// er noch gar keine besitzt.
int erworbeneKettenstufe(
  SpecialAbilityChain kette,
  Iterable<String> erworbeneNamen,
) {
  var hoechste = 0;
  for (final stufe in kette.stufen) {
    if (istEintragErworben(stufe, erworbeneNamen)) {
      final nummer = stufe.kette?.stufe ?? 0;
      if (nummer > hoechste) {
        hoechste = nummer;
      }
    }
  }
  return hoechste;
}

/// Die naechste erwerbbare Stufe — die niedrigste, die noch fehlt.
///
/// Bewusst nicht „erworbene Stufe + 1“: Ein importierter Held kann Stufe II
/// besitzen, ohne dass Stufe I eingetragen ist. Dann soll die UI die Luecke
/// anbieten statt die Kette als abgeschlossen zu behandeln.
SpecialAbilityDef? naechsteKettenstufe(
  SpecialAbilityChain kette,
  Iterable<String> erworbeneNamen,
) {
  for (final stufe in kette.stufen) {
    if (!istEintragErworben(stufe, erworbeneNamen)) {
      return stufe;
    }
  }
  return null;
}

/// Ob ein Katalogeintrag beim Helden eingetragen ist.
///
/// Beruecksichtigt neben dem Anzeigenamen auch die Alias-Namen, damit ein
/// Held, der noch den alten Sammeleintrag `Eiserner Wille I / II` gespeichert
/// hat, als Besitzer von Stufe I erkannt wird.
bool istEintragErworben(
  SpecialAbilityDef def,
  Iterable<String> erworbeneNamen,
) {
  final kandidaten = def.alleNamen
      .map(normalizeSpecialAbilityName)
      .where((name) => name.isNotEmpty)
      .toSet();
  if (kandidaten.isEmpty) {
    return false;
  }
  for (final owned in erworbeneNamen) {
    if (kandidaten.contains(normalizeSpecialAbilityName(owned))) {
      return true;
    }
  }
  return false;
}

/// Schneidet eine abschliessende roemische Stufenangabe vom Namen ab.
String _basisName(String name) {
  final treffer = RegExp(
    r'\s+(I{1,3}|IV|V|VI|VII)$',
    caseSensitive: false,
  ).firstMatch(name.trim());
  if (treffer == null) {
    return name.trim();
  }
  return name.trim().substring(0, treffer.start).trim();
}
