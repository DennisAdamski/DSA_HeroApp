part of 'advancement_options.dart';

// Alle SF-Arten teilen Voraussetzungen, unterscheiden sich aber im Speicherort.
AdvancementOption? _abilityOption(
  AdvancementContext context,
  AdvancementKind kind,
  String id,
  Map<String, String> options,
) {
  final def = context
      .abilityEntries(kind)
      .where((item) => item.id == id)
      .firstOrNull;
  if (def == null) return null;
  final hero = context.hero;
  final variant = options['variant']?.trim() ?? '';
  final name = buildVariantAbilityName(def.name, variant);
  final multi = def is SpecialAbilityDef && def.mehrfachwaehlbar;
  final ownedCount = multi
      ? countOwnedVariants(context.ownedAbilityNames, def.name)
      : 0;
  // Mit gewählter Variante zählt genau dieser Anzeigename, ohne sie der
  // Bestand des Basiseintrags: Ein Held führt nur `Geländekunde (Wüste)`,
  // besitzt die Sonderfertigkeit aber sehr wohl. Alias-Namen und die
  // Sonderfelder der Kampf-SF deckt [isAbilityEntryOwned] ab.
  final isOwned = multi && variant.isNotEmpty
      ? context.hasOwnedAbilityName(name)
      : context.ownedAbilityIds(kind).contains(id);
  final structured = [...def.voraussetzungenStruktur];
  final chain = def.kette;
  if (chain != null) {
    final previous = context.abilityEntries(kind).where((entry) =>
        entry.kette?.id == chain.id && entry.kette!.stufe < chain.stufe).toList();
    previous.sort((a,b) => b.kette!.stufe.compareTo(a.kette!.stufe));
    if (previous.isNotEmpty && !structured.any((r) =>
        r.art == RequirementArt.sonderfertigkeit && r.name == previous.first.name)) {
      structured.add(SpecialAbilityRequirement(art: RequirementArt.sonderfertigkeit,
          name: previous.first.name));
    }
  }
  final requirements = evaluateRequirements(
    structured,
    context.requirementContext,
  );
  String? unavailable;
  if (def.nurEpisch && !hero.isEpisch) {
    unavailable = 'Erfordert epischen Status';
  }
  if (def is SpecialAbilityDef && def.nurInformation) {
    unavailable = 'Reiner Informationseintrag';
  }
  // Diese Sperre ist zugleich der Bestandsnachweis: `_validateEntry` verlässt
  // sich darauf, und die Karte unterdrückt ihre Anzeige für erworbene
  // Einträge. Wer sie umbaut, muss beide Seiten anfassen.
  if (isOwned && (!multi || variant.isNotEmpty)) {
    unavailable = 'Bereits erworben';
  }
  var cost = parseLeadingApAmount(def.kosten);
  if (def is SpecialAbilityDef && multi) {
    cost = suggestVariantApCost(
      def: def,
      bereitsErworben: ownedCount,
      variante: variant,
      eigeneKultur: def.name == 'Kulturkunde' ? hero.background.kultur : '',
    );
  }
  return AdvancementOption(
    kind: kind,
    targetId: id,
    label: name,
    ability: def,
    options: options,
    isOwned: isOwned,
    ownedCount: ownedCount,
    unavailableReason: unavailable,
    apCost: cost,
    requirements: requirements,
  );
}
