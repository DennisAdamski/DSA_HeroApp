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
///
/// Alles hier ist generisch ueber [SpecialAbilityEntry], weil Kampf-Ketten
/// (`Ausweichen I-III`, `Ruestungsgewoehnung I-IV`) genauso funktionieren wie
/// magische — nur dass sie aus `CombatSpecialAbilityDef` bestehen.
library;

import 'package:dsa_heldenverwaltung/catalog/special_ability_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/special_ability_variant_rules.dart';

/// Eine Kette aus mindestens zwei Stufen.
class SpecialAbilityChain<T extends SpecialAbilityEntry> {
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
  final List<T> stufen;
}

/// Gruppiert die Eintraege eines Katalogs zu Ketten.
///
/// Eintraege ohne `kette` und Ketten mit nur einer Stufe werden bewusst
/// uebergangen: Eine „Kette“ aus einem Glied ist eine gewoehnliche
/// Sonderfertigkeit und soll auch so aussehen. Die Reihenfolge der Ketten
/// folgt dem ersten Auftreten im Katalog, damit die Anzeige stabil bleibt.
List<SpecialAbilityChain<T>> buildSpecialAbilityChains<T extends SpecialAbilityEntry>(
  Iterable<T> katalog,
) {
  final gruppen = <String, List<T>>{};
  final reihenfolge = <String>[];
  for (final def in katalog) {
    final id = def.kette?.id.trim() ?? '';
    if (id.isEmpty) {
      continue;
    }
    if (gruppen.putIfAbsent(id, () => <T>[]).isEmpty) {
      reihenfolge.add(id);
    }
    gruppen[id]!.add(def);
  }

  final ketten = <SpecialAbilityChain<T>>[];
  for (final id in reihenfolge) {
    final stufen = gruppen[id]!
      ..sort((a, b) => (a.kette!.stufe).compareTo(b.kette!.stufe));
    if (stufen.length < 2) {
      continue;
    }
    final label = stufen.first.kette!.label.trim();
    ketten.add(
      SpecialAbilityChain<T>(
        id: id,
        label: label.isEmpty ? _basisName(stufen.first.name) : label,
        stufen: List<T>.unmodifiable(stufen),
      ),
    );
  }
  return List<SpecialAbilityChain<T>>.unmodifiable(ketten);
}

/// Alle Eintraege, die von [buildSpecialAbilityChains] nicht erfasst werden.
///
/// Zusammen mit den Ketten ergibt das wieder den vollstaendigen Katalog — die
/// UI kann also beides nebeneinander anzeigen, ohne etwas zu verlieren.
List<T> kettenloseEintraege<T extends SpecialAbilityEntry>(
  Iterable<T> katalog,
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
int erworbeneKettenstufe<T extends SpecialAbilityEntry>(
  SpecialAbilityChain<T> kette,
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
T? naechsteKettenstufe<T extends SpecialAbilityEntry>(
  SpecialAbilityChain<T> kette,
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
  SpecialAbilityEntry def,
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
