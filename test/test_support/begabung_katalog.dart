import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';

import '../catalog/catalog_reference_names.dart';

/// Ergaenzt [basis] um echte Vor-/Nachteile aus dem Katalog.
///
/// Widget-Tests fuer Begabung und Unfaehigkeit sollen die ausgelieferten
/// Definitionen (Template, Auswahlquelle, `wirkungen`) verwenden statt sie
/// nachzubauen; sonst bliebe ein Fehler im Katalog in der UI unbemerkt.
RulesCatalog mitKatalogMerkmalen(
  RulesCatalog basis, {
  Iterable<String> vorteilIds = const <String>[],
  Iterable<String> nachteilIds = const <String>[],
}) {
  return RulesCatalog(
    version: basis.version,
    source: basis.source,
    talents: basis.talents,
    spells: basis.spells,
    weapons: basis.weapons,
    maneuvers: basis.maneuvers,
    combatSpecialAbilities: basis.combatSpecialAbilities,
    generalSpecialAbilities: basis.generalSpecialAbilities,
    magicSpecialAbilities: basis.magicSpecialAbilities,
    karmalSpecialAbilities: basis.karmalSpecialAbilities,
    advantages: <HeroTraitDef>[
      ...basis.advantages,
      ..._lade('vorteile.json', vorteilIds),
    ],
    disadvantages: <HeroTraitDef>[
      ...basis.disadvantages,
      ..._lade('nachteile.json', nachteilIds),
    ],
    sprachen: basis.sprachen,
    schriften: basis.schriften,
    reisebericht: basis.reisebericht,
    metadata: basis.metadata,
    ruleResolver: basis.ruleResolver,
  );
}

List<HeroTraitDef> _lade(String datei, Iterable<String> ids) {
  final gesucht = ids.toSet();
  if (gesucht.isEmpty) {
    return const <HeroTraitDef>[];
  }
  final gefunden = <HeroTraitDef>[
    for (final json in ladeKatalogDatei(datei))
      if (gesucht.contains(json['id'])) HeroTraitDef.fromJson(json),
  ];
  if (gefunden.length != gesucht.length) {
    throw StateError('Nicht im Katalog ($datei): $gesucht');
  }
  return gefunden;
}
