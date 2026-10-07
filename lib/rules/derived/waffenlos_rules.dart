// Waffenloser Kampf (WdS S. 89–91, Aventurisches Arsenal S. 150).
//
// Jeder Held kann ohne Waffe kämpfen: Raufen (Hände, Füße, Kopf) und Ringen
// (Griffe, Würfe) sind Basistalente. Beide sind Zweihandtechniken und stehen
// deshalb nur waffenlos kampfbereit als eigenes Kampfmittel bereit; neben
// einer Waffe nur mit Kampftechnik für deren Manöver (WdS S. 90). Die Werte
// entstehen über die gewöhnliche Kampfvorschau mit einem virtuellen,
// nie gespeicherten Waffenslot; damit wirken Talent, eBE, Wunden, Modifikatoren
// und aktive waffenlose Kampfstile (`unarmed_style_rules.dart`) genau wie bei
// einer Waffe.

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/rules/derived/unarmed_style_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/waffenlos_slot_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_rules.dart';

export 'waffenlos_slot_rules.dart';

/// Kampfwerte eines waffenlosen Talents mit den wirksamen Kampfstilen.
class WaffenloseKampfwerte {
  const WaffenloseKampfwerte({
    required this.talent,
    required this.slot,
    required this.vorschau,
    required this.stil,
    required this.stilIds,
    required this.stilnamen,
    required this.manoeverIds,
    this.nebenWaffe = false,
  });

  final WaffenlosesTalent talent;
  final MainWeaponSlot slot;

  /// Kampfvorschau mit [slot] als Hauptwaffe und leerer Nebenhand.
  final CombatPreviewStats vorschau;

  /// Für dieses Talent wirksame Stilboni (bereits in [vorschau] enthalten).
  final UnarmedStyleEffects stil;

  /// Katalog-IDs und Namen aller aktiven waffenlosen Kampfstile des Helden.
  final List<String> stilIds, stilnamen;

  /// Von den aktiven Kampfstilen freigeschaltete Manöver.
  final Set<String> manoeverIds;

  /// Neben einer Waffe: nur Manöver der Kampftechnik, um 2 erschwert.
  final bool nebenWaffe;

  /// Mindestens eine waffenlose Kampftechnik ist aktiv.
  bool get kampftechnikAktiv => stilIds.isNotEmpty;
}

/// Rechnet Raufen und Ringen, wenn der Held waffenlos kampfbereit ist oder
/// neben seiner Waffe eine waffenlose Kampftechnik beherrscht; sonst leer.
List<WaffenloseKampfwerte> computeWaffenloseKampfwerte({
  required HeroSheet hero,
  required HeroState state,
  required List<TalentDef> catalogTalents,
  required List<ManeuverDef> catalogManeuvers,
  required List<CombatSpecialAbilityDef> catalogCombatSpecialAbilities,
  required ModifierParseResult parsedModifiers,
  required Attributes effectiveAttributes,
  required DerivedStats derivedStats,
  required WundEffekte wunden,
  required bool epicAdvantagesRuleActive,
}) {
  final config = hero.combatConfig;
  final aktiv = config.specialRules.activeCombatSpecialAbilityIds.toSet();
  final stile = [
    for (final a in catalogCombatSpecialAbilities)
      if (a.isUnarmedCombatStyle && aktiv.contains(a.id)) a,
  ];
  final nebenWaffe = !waffenlosKampfbereit(config);
  if (nebenWaffe && stile.isEmpty) return const [];
  final stil = computeActiveUnarmedStyleEffects(
    specialRules: config.specialRules,
    catalogCombatSpecialAbilities: catalogCombatSpecialAbilities,
    catalogManeuvers: catalogManeuvers,
    activeTalentName: '',
  );
  return [
    for (final talent in WaffenlosesTalent.values)
      () {
        final slot = nebenWaffe
            ? waffenloserSlot(talent)
                  .copyWith(name: '${talent.talentName} (waffenloses Manöver)')
            : waffenloserSlot(talent);
        return WaffenloseKampfwerte(
          talent: talent,
          slot: slot,
          vorschau: computeCombatPreviewStats(
            hero,
            state,
            overrideConfig: config.copyWith(
              weapons: [slot],
              selectedWeaponIndex: 0,
              offhandAssignment: const OffhandAssignment(),
            ),
            catalogTalents: catalogTalents,
            catalogManeuvers: catalogManeuvers,
            catalogCombatSpecialAbilities: catalogCombatSpecialAbilities,
            parsedModifiers: parsedModifiers,
            effectiveAttributes: effectiveAttributes,
            derivedStats: derivedStats,
            wunden: wunden,
            epicAdvantagesRuleActive: epicAdvantagesRuleActive,
          ),
          stil: computeActiveUnarmedStyleEffects(
            specialRules: config.specialRules,
            catalogCombatSpecialAbilities: catalogCombatSpecialAbilities,
            catalogManeuvers: catalogManeuvers,
            activeTalentName: talent.talentName,
          ),
          stilIds: [for (final a in stile) a.id],
          stilnamen: [for (final a in stile) a.name],
          manoeverIds: stil.activatedManeuverIds.toSet(),
          nebenWaffe: nebenWaffe,
        );
      }(),
  ];
}

/// Besonderheiten der Kampfstile, die am Tisch abgewickelt werden (WdS S. 90 f.).
const Map<String, String> kWaffenloseStilBesonderheiten = {
  'ksf_gladiatorenstil':
      'Gladiatorenstil: bis zu 3 echte TP je Schlag stattdessen als TP(A).',
  'ksf_hammerfaust':
      'Hammerfaust: TP(A) wahlweise als Strukturschaden; Ausfall mit Raufen.',
  'ksf_hruruzat':
      'Hruruzat: Tritte richten 2W6 TP(A) an, ein Pasch ist ein Zat '
      '(weiterer Schadenswurf).',
  'ksf_mercenario':
      'Mercenario: gegen Bewaffnete in DK Nahkampf AT nur +3 statt +6; '
      'parierte Distanzverkürzung ohne Schaden.',
  'ksf_unauer_schule':
      'Unauer Schule: alle Entwinden-Manöver um 2 Punkte erleichtert.',
};

/// Erklärt Grundwert und Tischregeln eines waffenlosen Kampfmittels.
List<String> waffenloseHinweise(WaffenloseKampfwerte w) => [
  if (w.nebenWaffe)
    'Neben einer Waffe (WdS S. 90): nur Manöver der Kampftechnik statt einer '
        'bewaffneten Aktion, um 2 erschwert, mit der Waffe parierbar; '
        'nichts, das beide Hände braucht (Würgegriff); nicht mit '
        'Linkhand-Zusatzaktionen kombinierbar.',
  if (w.stil.atBonus != 0 || w.stil.paBonus != 0)
    'Kampfstil (${w.stilnamen.join(', ')}): AT +${w.stil.atBonus}, '
        'PA +${w.stil.paBonus} im Grundwert (je höchstens +2).',
  if (!w.nebenWaffe && w.kampftechnikAktiv)
    'Kampftechnik: Wechsel zwischen Raufen und Ringen ohne Position.',
  if (!w.kampftechnikAktiv)
    'Ohne waffenlose Kampftechnik: je KR Raufen oder Ringen festlegen, '
        'Wechsel kostet eine Aktion Position; nur Standard-AT/PA.',
  'Gegen Bewaffnete (optional, WdS S. 89; AA S. 150): AT −1, PA −2; gelungene PA '
      'gegen eine Waffe außerhalb von DK Handgemenge: halber Schaden. '
      'Fernkampf und Lanzen nicht waffenlos parierbar. Panzerhandschuh, '
      'beschlagene Stiefel oder Metallhelm: +2 TP(A) auf Schläge, Tritte, '
      'Kopfstöße.',
  for (final id in w.stilIds) ?kWaffenloseStilBesonderheiten[id],
];
