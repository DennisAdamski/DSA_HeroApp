import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';

import 'hero_requirement_context.dart';
import 'gefecht_wirken_rules.dart';
import 'talent_probe_rules.dart';

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
///
/// TaW* kommt aus `talentProbenwertFuer` (Behinderung, Inventarboni,
/// Modifikator) wie in der Probensuche; die Kette folgt der Gottheit.
ResolvedProbeRequest? gefechtsLiturgieprobe(
  HeroComputedSnapshot snapshot,
  TalentDef talent, {
  List<String>? eigenschaften,
  bool epicAdvantagesActive = false,
}) {
  if (snapshot.hero.talents[talent.id]?.talentValue == null ||
      talent.attributes.length != 3) {
    return null;
  }
  final wert = talentProbenwertFuer(
    snapshot: snapshot,
    talent: talent,
    epicAdvantagesActive: epicAdvantagesActive,
    eigenschaften:
        eigenschaften ??
        gefechtsEigenschaftenFuerKult(talent.name) ??
        talent.attributes,
  );
  if (wert == null) return null;
  return ResolvedProbeRequest(
    type: ProbeType.talent,
    title: talent.name,
    subtitle: 'Liturgiekenntnis · Grad und Modifikatoren prüfen',
    ruleHint: 'Zeitpunkt, Grad, Dauer, Ziel, KaP-Kosten und Wirkung manuell bestätigen.',
    diceSpec: const DiceSpec(count: 3, sides: 20),
    targets: wert.ziele,
    basePool: wert.taw,
  );
}

/// Gelernte Talentprobe im Gefecht mit derselben TaW*-Rechnung wie die Suche.
///
/// `null`, wenn der Held das Talent nicht mit Wert führt.
ResolvedProbeRequest? gefechtsTalentprobe(
  HeroComputedSnapshot snapshot,
  TalentDef talent, {
  bool epicAdvantagesActive = false,
}) {
  if (snapshot.hero.talents[talent.id]?.talentValue == null) return null;
  return talentprobeFuer(
    snapshot: snapshot,
    talent: talent,
    epicAdvantagesActive: epicAdvantagesActive,
  );
}

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

/// Ein gelernter Zauber in der Gefechtsliste.
class GefechtsZaubereintrag {
  /// [zfw] ist ZfW* (Wert + Modifikator) wie in der Probensuche.
  const GefechtsZaubereintrag({
    required this.zauber,
    required this.zfw,
    required this.zuletzt,
  });
  final SpellDef zauber;
  final int zfw;

  /// Gehört zu den zuletzt begonnenen Zaubern dieses Gefechts.
  final bool zuletzt;

  /// Kurzzeile mit ZfW*, Zauberdauer und Kosten aus dem Katalog.
  String get detail => [
    'ZfW* $zfw',
    if (zauber.castingTime.trim().isNotEmpty) zauber.castingTime.trim(),
    if (zauber.aspCost.trim().isNotEmpty) zauber.aspCost.trim(),
  ].join(' · ');
}

/// Gelernte Katalogzauber: zuletzt gewirkte zuerst, danach alphabetisch.
///
/// Nur Zauber mit Wert erscheinen: ein eingeblendeter, noch nicht
/// aktivierter Zauber ist nicht wirkbar (`gefechtsZauberprobe` liefert für
/// ihn `null`). [suche] filtert ohne Groß-/Kleinschreibung nach dem Namen.
List<GefechtsZaubereintrag> gefechtsZauberliste(
  HeroComputedSnapshot snapshot,
  RulesCatalog katalog, {
  List<String> zuletzt = const [],
  String suche = '',
}) {
  final filter = suche.trim().toLowerCase();
  final eintraege = <GefechtsZaubereintrag>[
    for (final z in katalog.spells)
      if (snapshot.hero.spells[z.id] case final e? when e.spellValue != null)
        if (filter.isEmpty || z.name.toLowerCase().contains(filter))
          GefechtsZaubereintrag(
            zauber: z,
            zfw: e.spellValue! + e.modifier,
            zuletzt: zuletzt.contains(z.id),
          ),
  ];
  int rang(GefechtsZaubereintrag e) {
    final i = zuletzt.indexOf(e.zauber.id);
    return i < 0 ? zuletzt.length : i;
  }

  eintraege.sort((a, b) {
    final r = rang(a).compareTo(rang(b));
    if (r != 0) return r;
    return a.zauber.name.toLowerCase().compareTo(b.zauber.name.toLowerCase());
  });
  return eintraege;
}

/// Merkt einen begonnenen Zauber vorn und hält höchstens fünf Einträge.
List<String> gefechtsZuletztGewirkt(List<String> bisher, String zauberId) =>
    [zauberId, ...bisher.where((id) => id != zauberId)].take(5).toList();
