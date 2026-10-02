import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';

import 'hero_requirement_context.dart';
import 'gefecht_wirken_rules.dart';

/// Baut eine tatsächliche Zauberprobe; Dauer und Kosten bleiben separat geprüft.
ResolvedProbeRequest? gefechtsZauberprobe(
  HeroComputedSnapshot snapshot,
  SpellDef zauber,
) {
  final eintrag = snapshot.hero.spells[zauber.id];
  if (eintrag?.spellValue == null) return null;
  final targets = <ProbeTargetValue>[];
  for (final name in zauber.attributes) {
    final code = parseAttributeCode(name);
    if (code == null) return null;
    targets.add(
      ProbeTargetValue(
        label: name,
        value: readAttributeValue(snapshot.probenEigenschaften, code),
      ),
    );
  }
  if (targets.length != 3) return null;
  return ResolvedProbeRequest(
    type: ProbeType.spell,
    title: zauber.name,
    subtitle: 'Gefechtszauber · ${zauber.castingTime}',
    ruleHint: 'Reichweite, Zeit, Modifikationen, Kosten und Wirkung ausdrücklich prüfen.',
    diceSpec: const DiceSpec(count: 3, sides: 20),
    targets: targets,
    basePool: eintrag!.spellValue! + eintrag.modifier,
  );
}

/// Verwendet die tatsächlich gelernte Liturgiekenntnis samt drei Eigenschaften.
ResolvedProbeRequest? gefechtsLiturgieprobe(
  HeroComputedSnapshot snapshot,
  TalentDef talent, {
  List<String>? eigenschaften,
}) {
  final entry = snapshot.hero.talents[talent.id];
  if (entry?.talentValue == null || talent.attributes.length != 3) return null;
  final targets = <ProbeTargetValue>[];
  for (final name
      in eigenschaften ??
          gefechtsEigenschaftenFuerKult(talent.name) ??
          talent.attributes) {
    final code = parseAttributeCode(name);
    if (code == null) return null;
    targets.add(
      ProbeTargetValue(
        label: name,
        value: readAttributeValue(snapshot.probenEigenschaften, code),
      ),
    );
  }
  if (targets.length != 3) return null;
  return ResolvedProbeRequest(
    type: ProbeType.talent,
    title: talent.name,
    subtitle: 'Liturgiekenntnis · Grad und Modifikatoren prüfen',
    ruleHint: 'Zeitpunkt, Grad, Dauer, Ziel, KaP-Kosten und Wirkung manuell bestätigen.',
    diceSpec: const DiceSpec(count: 3, sides: 20),
    targets: targets,
    basePool: entry!.talentValue! + entry.modifier,
  );
}

/// Baut eine Talentprobe aus denselben frischen Eigenschaften wie die Liturgie.
ResolvedProbeRequest? gefechtsTalentprobe(
  HeroComputedSnapshot snapshot,
  TalentDef talent,
) => gefechtsLiturgieprobe(snapshot, talent, eigenschaften: talent.attributes);

/// Erkennt eindeutige Kulte aus der tatsächlichen Liturgiekenntnis.
List<String>? gefechtsEigenschaftenFuerKult(String name) {
  final matches =
      [
            'praios',
            'ucuri',
            'rondra',
            'kor',
            'swafnir',
            'efferd',
            'travia',
            'boron',
            'hesinde',
            'nandus',
            'firun',
            'ifirn',
            'tsa',
            'phex',
            'aves',
            'peraine',
            'ingerimm',
            'rahja',
          ]
          .where(
            (k) =>
                RegExp('(^|[^a-z])$k([^a-z]|\$)').hasMatch(name.toLowerCase()),
          )
          .toList();
  return matches.length == 1 ? gefechtsKultEigenschaften(matches.single) : null;
}

/// Erlernte karmale Sonderfertigkeiten werden über vorhandene Namen aufgelöst.
List<SpecialAbilityDef> gefechtKarmaleFertigkeiten(
  HeroComputedSnapshot snapshot,
  RulesCatalog katalog,
) {
  final namen = heroSpecialAbilityNames(snapshot.hero, catalog: katalog);
  return katalog.karmalSpecialAbilities
      .where((sf) => namen.contains(sf.name))
      .toList();
}
