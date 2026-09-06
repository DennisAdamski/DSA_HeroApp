part of 'advancement_options.dart';

/// Umfang der aufzubauenden Optionsliste.
enum AdvancementScope {
  /// Nur Ziele, die beim Helden auf dem Bogen stehen, plus die unmittelbar
  /// daraus folgenden Sonderfertigkeitsschritte.
  active,

  /// Nur Ziele, die noch nicht beim Helden stehen — die Vorlage des
  /// Erwerbsblatts.
  inactive,

  /// Der vollständige Katalog.
  all,
}

/// Ob ein Ziel beim Helden auf dem Bogen steht.
///
/// Für Werte zählt der Schlüssel, nicht der Wert: Ein eingeblendetes Talent
/// ohne TaW gehört dem Helden bereits, nur seine Aktivierungskosten sind noch
/// offen. Eigenschaften und Grundwerte besitzt jeder Held.
bool isAdvancementTargetOwned({
  required AdvancementContext context,
  required AdvancementKind kind,
  required String targetId,
}) {
  final hero = context.hero;
  return switch (kind) {
    AdvancementKind.attribute || AdvancementKind.boughtStat => true,
    AdvancementKind.talent => hero.talents.containsKey(targetId),
    AdvancementKind.spell => hero.spells.containsKey(targetId),
    AdvancementKind.language => hero.sprachen.containsKey(targetId),
    AdvancementKind.script => hero.schriften.containsKey(targetId),
    _ => context.ownedAbilityIds(kind).contains(targetId),
  };
}

/// Ob ein Ziel im gewählten Umfang enthalten ist.
bool advancementScopeIncludes({
  required AdvancementContext context,
  required AdvancementScope scope,
  required AdvancementKind kind,
  required String targetId,
}) {
  if (scope == AdvancementScope.all) {
    return true;
  }
  final owned = isAdvancementTargetOwned(
    context: context,
    kind: kind,
    targetId: targetId,
  );
  if (scope == AdvancementScope.inactive) {
    return !owned;
  }
  return owned || context.actionableAbilityTargets(kind).contains(targetId);
}

/// Ob der Held einen Sonderfertigkeits-Katalogeintrag bereits führt.
///
/// Mehrfach wählbare Einträge werden über ihre Varianten gezählt: Ein Held mit
/// `Geländekunde (Wüste)` führt keinen Eintrag namens `Geländekunde`, besitzt
/// die Sonderfertigkeit aber sehr wohl. Für alle übrigen entscheidet
/// [istEintragErworben], weil nur diese Prüfung die Alias-Namen kennt und
/// damit Bestandshelden mit alten Sammelnamen wie `Eiserner Wille I / II`
/// erkennt. Kampf-Sonderfertigkeiten gehen zusätzlich über
/// [isCombatSpecialAbilityActive], die einzige Instanz, die ihre Sonderfelder
/// kennt.
bool isAbilityEntryOwned(
  AdvancementContext context,
  AdvancementKind kind,
  SpecialAbilityEntry def,
) {
  if (kind == AdvancementKind.combatAbility &&
      isCombatSpecialAbilityActive(context.hero.combatConfig, def.id)) {
    return true;
  }
  if (def is SpecialAbilityDef && def.mehrfachwaehlbar) {
    return countOwnedVariants(context.ownedAbilityNames, def.name) > 0;
  }
  return istEintragErworben(def, context.ownedAbilityNames);
}

/// IDs der bereits erworbenen Sonderfertigkeiten einer Art.
Set<String> computeOwnedAbilityIds(
  AdvancementContext context,
  AdvancementKind kind,
) => <String>{
  for (final def in context.abilityEntries(kind))
    if (isAbilityEntryOwned(context, kind, def)) def.id,
};

/// Sonderfertigkeiten, die aus dem Bestand des Helden unmittelbar
/// handlungsfähig sind.
///
/// Das sind die erworbenen selbst — mehrfach wählbare bleiben über weitere
/// Varianten offen, alle übrigen zeigt die Liste als Bestandsnachweis — und
/// die nächste Stufe jeder Kette, von der der Held mindestens eine Stufe
/// besitzt. Eine unangetastete Kette gehört dagegen ins Erwerbsblatt: Sie ist
/// kein Folgeschritt, sondern ein Neuerwerb.
Set<String> computeActionableAbilityTargets(
  AdvancementContext context,
  AdvancementKind kind,
) {
  final targets = <String>{...context.ownedAbilityIds(kind)};
  final owned = context.ownedAbilityNames;
  for (final kette in buildSpecialAbilityChains(context.abilityEntries(kind))) {
    if (erworbeneKettenstufe(kette, owned) == 0) {
      continue;
    }
    final naechste = naechsteKettenstufe(kette, owned);
    if (naechste != null) {
      targets.add(naechste.id);
    }
  }
  return targets;
}
