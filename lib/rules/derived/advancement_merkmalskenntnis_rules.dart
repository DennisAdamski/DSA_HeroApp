/// Merkmalskenntnisse als Planungsschritt der Steigerungsrunde.
///
/// Merkmalskenntnisse stehen nicht als Sonderfertigkeit, sondern als eigenes
/// Feld `HeroSheet.merkmalskenntnisse` am Helden. Geplant werden sie als
/// [AdvancementKind.magicAbility] auf den Informationseintrag
/// [kMerkmalskenntnisSfId] mit der Aktion [kMerkmalskenntnisAktion]; die
/// Übernahme ergänzt nur das Feld.
///
/// Regeln (Wege der Helden S. 289): Spruchzauberer; Leiteigenschaft 13 für
/// das zweite Merkmal, 15 für das dritte, 16 für das vierte, 17 für das
/// fünfte usw.; 100/200/300 AP je Klassifikation
/// ([merkmalskenntnisApCost]).
library;

import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';

import 'advancement_options.dart';
import 'magic_acquisition_rules.dart';
import 'requirement_evaluation_rules.dart';
import 'special_ability_variant_rules.dart';

/// Aktionsname im Optionsfeld `action`.
const String kMerkmalskenntnisAktion = 'merkmalskenntnis';

/// Optionsschlüssel des gewählten Merkmals.
const String kMerkmalskenntnisOptionMerkmal = 'merkmal';

/// Katalogeintrag, an dem der Erwerb im Verlauf hängt.
const String kMerkmalskenntnisSfId = 'magsf_merkmalskenntnis_einzelnes_merkmal';

/// Alle Merkmale der drei Klassifikationen in Anzeigereihenfolge.
const List<String> kAlleMerkmale = <String>[
  ...kMerkmaleKlassifikationI,
  ...kMerkmaleKlassifikationII,
  ...kMerkmaleKlassifikationIII,
];

/// Leiteigenschaft, die für die [anzahl]-te Merkmalskenntnis nötig ist;
/// `null` für die erste (WdH S. 289).
int? merkmalskenntnisLeiteigenschaft(int anzahl) {
  if (anzahl <= 1) return null;
  if (anzahl == 2) return 13;
  return 12 + anzahl;
}

bool _bekannt(HeroSheet hero, String merkmal) {
  final gesucht = normalizeSpecialAbilityName(merkmal);
  return hero.merkmalskenntnisse.any(
    (eintrag) => normalizeSpecialAbilityName(eintrag) == gesucht,
  );
}

/// Je Merkmal eine Option; bekannte gelten als erworben.
List<AdvancementOption> buildMerkmalskenntnisOptions(
  AdvancementContext context,
  AdvancementScope scope,
) {
  final merkmale = <String>[
    ...kAlleMerkmale,
    // Bekannte Merkmale außerhalb der Liste (Hausregeln) bleiben sichtbar.
    for (final eigenes in context.hero.merkmalskenntnisse)
      if (!kAlleMerkmale.any(
        (merkmal) =>
            normalizeSpecialAbilityName(merkmal) ==
            normalizeSpecialAbilityName(eigenes),
      ))
        eigenes,
  ];
  return [
    for (final merkmal in merkmale)
      if (switch (scope) {
        AdvancementScope.all => true,
        AdvancementScope.active => _bekannt(context.hero, merkmal),
        AdvancementScope.inactive => !_bekannt(context.hero, merkmal),
      })
        resolveMerkmalskenntnis(context, {
          kMerkmalskenntnisOptionMerkmal: merkmal,
        }),
  ];
}

/// Löst den Erwerb einer Merkmalskenntnis gegen den Vorschauhelden auf.
AdvancementOption resolveMerkmalskenntnis(
  AdvancementContext context,
  Map<String, String> options,
) {
  final merkmal = options[kMerkmalskenntnisOptionMerkmal]?.trim() ?? '';
  final hero = context.hero;
  final bekannt = merkmal.isNotEmpty && _bekannt(hero, merkmal);
  final anzahl = hero.merkmalskenntnisse.length + (bekannt ? 0 : 1);
  final leit = merkmalskenntnisLeiteigenschaft(anzahl);
  final requirements = evaluateRequirements(<SpecialAbilityRequirement>[
    const SpecialAbilityRequirement(art: RequirementArt.spruchzauberer),
    if (leit != null)
      SpecialAbilityRequirement(art: RequirementArt.leiteigenschaft, min: leit),
  ], context.requirementContext);
  String? grund;
  if (merkmal.isEmpty) {
    grund = 'Bitte ein Merkmal wählen.';
  } else if (bekannt) {
    grund = 'Bereits erworben';
  }
  final stufe = merkmal.isEmpty ? 2 : merkmalsklassifikation(merkmal);
  return AdvancementOption(
    kind: AdvancementKind.magicAbility,
    targetId: kMerkmalskenntnisSfId,
    label: 'Merkmalskenntnis $merkmal',
    // Bewusst ohne `ability`: Der Informationseintrag selbst ist kein
    // erwerbbares Ziel, und die SF-Prüfung würde ihn sperren.
    options: {
      ...options,
      'action': kMerkmalskenntnisAktion,
      kMerkmalskenntnisOptionMerkmal: merkmal,
    },
    isOwned: bekannt,
    apCost: merkmal.isEmpty ? null : merkmalskenntnisApCost(merkmal),
    unavailableReason: grund,
    requirements: requirements,
    complexityHint:
        'Klassifikation ${'I' * stufe}: ${merkmalskenntnisApCost(merkmal)} AP '
        '(Wege der Helden S. 289); die erste Merkmalskenntnis ist bei vielen '
        'Professionen enthalten',
  );
}

/// Prüft einen geplanten Merkmalskenntnis-Erwerb.
void validateMerkmalskenntnisEntry(
  HeroAdvancementEntry entry,
  AdvancementOption option,
) {
  if (entry.seSpent != 0 || entry.fromValue != null || entry.toValue != null) {
    throw StateError(
      'Merkmalskenntnisse verwenden keine numerischen Steigerungsschritte.',
    );
  }
  if (!alleVoraussetzungenErfuellt(option.requirements) &&
      entry.options['meisterentscheid'] != 'true') {
    throw StateError(
      'Voraussetzungen fehlen; ein ausdrücklicher Meisterentscheid ist '
      'erforderlich.',
    );
  }
}

/// Ergänzt die Merkmalskenntnis am Vorschauhelden.
HeroSheet applyMerkmalskenntnisEntry(
  HeroSheet hero,
  HeroAdvancementEntry entry,
) {
  final merkmal = entry.options[kMerkmalskenntnisOptionMerkmal]!.trim();
  return hero.copyWith(
    merkmalskenntnisse: [...hero.merkmalskenntnisse, merkmal],
  );
}
