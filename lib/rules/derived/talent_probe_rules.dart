import 'package:dsa_heldenverwaltung/catalog/talent_def.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import 'epic_main_attribute_rules.dart';
import 'probe_request_rules.dart';
import 'ruestung_be_rules.dart';
import 'talent_value_rules.dart';

/// Aufgelöste Werte einer Talentprobe des Helden.
class TalentProbenwert {
  /// Hält Probenziele, TaW* und die Grundlagen seiner Berechnung.
  const TalentProbenwert({
    required this.ziele,
    required this.taw,
    required this.ebe,
    required this.spezialisierung,
  });

  /// Drei Eigenschaften mit ihren Probenwerten (Wunden eingerechnet).
  final List<ProbeTargetValue> ziele;

  /// TaW* = TaW + Modifikator + eBE + Inventarbonus.
  final int taw;

  /// Effektive Behinderung des Talents (negativ oder 0).
  final int ebe;

  /// Der Held führt eine Spezialisierung für dieses Talent.
  final bool spezialisierung;
}

/// Löst Eigenschaftsnamen in Probenziele mit den aktuellen Werten auf.
///
/// Unbekannte Namen werden ausgelassen; Aufrufer prüfen die erwartete Anzahl.
List<ProbeTargetValue> probenzieleFuer(
  Attributes werte,
  List<String> eigenschaften,
) => List<ProbeTargetValue>.unmodifiable([
  for (final name in eigenschaften)
    if (parseAttributeCode(name) case final code?)
      ProbeTargetValue(
        label: attributeCodeKey(code),
        value: readAttributeValue(werte, code),
      ),
]);

/// TaW* einer Talentprobe, identisch für Probensuche und Gefecht.
///
/// Berücksichtigt die effektive Behinderung aus der Kampf-BE (oder der
/// vorübergehenden Talentansicht [talentBeOverride]), die epische
/// KK-Halbierung, den Talentmodifikator und Inventarboni. [eigenschaften]
/// ersetzt die Katalogkette (etwa die gottspezifische Liturgieprobe).
/// `null`, wenn der Held das Talent nicht führt oder die Kette nicht genau
/// drei Eigenschaften ergibt.
TalentProbenwert? talentProbenwertFuer({
  required HeroComputedSnapshot snapshot,
  required TalentDef talent,
  required bool epicAdvantagesActive,
  int? talentBeOverride,
  List<String>? eigenschaften,
}) {
  final hero = snapshot.hero;
  final eintrag = hero.talents[talent.id];
  if (eintrag == null) return null;
  final ziele = probenzieleFuer(
    snapshot.probenEigenschaften,
    eigenschaften ?? talent.attributes,
  );
  if (ziele.length != 3) return null;
  final ebe = computeTalentEbe(
    baseBe: talentBeOverride ?? snapshot.combatPreviewStats.beKampf,
    talentBeRule: talent.be,
    reductionMultiplier: epicTalentEbeMultiplier(
      ruleActive: epicAdvantagesActive,
      isEpisch: hero.isEpisch,
      mainAttributes: hero.epicMainAttributes,
      talentAttributes: talent.attributes,
    ),
  );
  final taw = computeTalentComputedTaw(
    talentValue: eintrag.talentValue,
    modifier: eintrag.modifier,
    ebe: ebe,
    inventoryMod: snapshot.inventoryTalentMods[talent.id] ?? 0,
  );
  return TalentProbenwert(
    ziele: ziele,
    taw: taw,
    ebe: ebe,
    spezialisierung:
        eintrag.combatSpecializations.isNotEmpty ||
        eintrag.specializations.trim().isNotEmpty,
  );
}

/// Talentprobe des Helden über den gemeinsamen Probenbauer.
///
/// [initialSituationalModifier] belegt den Probendialog vor; negativ heißt
/// erschwert (Konvention des Probenmodells).
ResolvedProbeRequest? talentprobeFuer({
  required HeroComputedSnapshot snapshot,
  required TalentDef talent,
  required bool epicAdvantagesActive,
  int? talentBeOverride,
  int initialSituationalModifier = 0,
}) {
  final wert = talentProbenwertFuer(
    snapshot: snapshot,
    talent: talent,
    epicAdvantagesActive: epicAdvantagesActive,
    talentBeOverride: talentBeOverride,
  );
  if (wert == null) return null;
  return buildTalentProbeRequest(
    title: talent.name,
    targets: wert.ziele,
    basePool: wert.taw,
    hasSpecialization: wert.spezialisierung,
    initialSituationalModifier: initialSituationalModifier,
  );
}
