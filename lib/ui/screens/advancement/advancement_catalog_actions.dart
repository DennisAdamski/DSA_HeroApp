import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_impact_panel.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/catalog/special_ability_def.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_options.dart';
import 'package:dsa_heldenverwaltung/rules/derived/magic_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/special_ability_variant_rules.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_selection_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/special_ability_variant_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/erwerb_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/steigerungs_dialog.dart';

/// Erfasst einen Planungsbefehl mit den tatsächlich bestätigten Kosten und SE.
/// Die Dialoge verändern weder den gespeicherten Helden noch die Sitzung.
Future<HeroAdvancementEntry?> showAdvancementPlanDialog({
  required BuildContext context,
  required AdvancementSession session,
  required AdvancementOption option,
}) async {
  final selectedOptions = Map<String, String>.from(option.options);
  final selected = await _selectAcquisitionOptions(
    context: context,
    session: session,
    option: option,
    options: selectedOptions,
  );
  if (!selected || !context.mounted) return null;
  final resolved = resolveAdvancementOption(
    hero: session.preview,
    catalog: session.catalog,
    kind: option.kind,
    targetId: option.targetId,
    options: selectedOptions,
  );
  if (resolved == null) {
    throw StateError('Dieser Eintrag ist nicht mehr verfügbar.');
  }
  final unavailable = resolved.unavailableReason;
  if (unavailable != null) throw StateError(unavailable);
  if (resolved.isValueAdvancement) {
    return _planValue(context, session, resolved, selectedOptions);
  }
  return _planAbility(context, session, resolved, selectedOptions);
}

// Optionen werden vor der Kostenberechnung ausdrücklich gewählt.
Future<bool> _selectAcquisitionOptions({
  required BuildContext context,
  required AdvancementSession session,
  required AdvancementOption option,
  required Map<String, String> options,
}) async {
  if (option.kind == AdvancementKind.spell && option.currentValue < 0) {
    final spell = session.catalog.spells.firstWhere(
      (spell) => spell.id == option.targetId,
    );
    final choices = allLearningOptionsForHero(
      spell.availability,
      session.preview.representationen,
    );
    final selected =
        await showAdvancementSelectionDialog<SpellAvailabilityEntry>(
          context: context,
          title: 'Zauber-Repräsentation wählen',
          description: option.label,
          choices: choices,
          label: (entry) => entry.displayLabel,
        );
    if (selected == null || !context.mounted) return false;
    options['learnedRepresentation'] = selected.learnedRepresentation;
    options['learnedTradition'] = selected.tradition;
  }
  final ability = option.ability;
  if (ability is SpecialAbilityDef && ability.mehrfachwaehlbar) {
    final hero = session.preview;
    final ownedNames = [
      ...hero.talentSpecialAbilities.map((entry) => entry.name),
      ...hero.magicSpecialAbilities.map((entry) => entry.name),
    ];
    final variant = await showAdaptiveInputDialog<String>(
      context: context,
      builder: (_) => SpecialAbilityVariantDialog(
        ability: ability,
        bereitsBelegt: ownedVariantsFor(ownedNames, ability.name),
      ),
    );
    if (variant == null || variant.trim().isEmpty) return false;
    options['variant'] = variant.trim();
  }
  return true;
}

// Der bestehende Dialog liefert AP, SE und Lernoptionen als Erwerbsnachweis.
Future<HeroAdvancementEntry?> _planValue(
  BuildContext context,
  AdvancementSession session,
  AdvancementOption option,
  Map<String, String> options,
) async {
  final result = await showSteigerungsDialog(
    context: context,
    bezeichnung: option.label,
    aktuellerWert: option.currentValue,
    effektiveKomplexitaet: option.learnCost!,
    verfuegbareAp: session.preview.apAvailable,
    maxWert: option.maxValue,
    seAnzahl: option.seAvailable,
    startWert: option.startValue,
    komplexitaetsHinweis: option.complexityHint,
    episch: session.preview.isEpisch,
    istHaupteigenschaft: option.isMainAttribute,
    lehrmeisterVerfuegbar: true,
    previewBuilder: option.kind == AdvancementKind.attribute
        ? (context, target) => AdvancementImpactPanel(
            session: session,
            attribute: parseAttributeCode(option.targetId)!,
            targetValue: target,
          )
        : null,
    confirmLabel: 'Vormerken',
  );
  if (result == null || !context.mounted) return null;
  options['learnCost'] =
      result.effektiveKomplexitaet?.name ?? option.learnCost!.name;
  _recordTeacher(options, result.lehrmeisterTaW, result.dukaten);
  return _entry(
    session: session,
    option: option,
    options: options,
    fromValue: option.currentValue,
    toValue: result.neuerWert,
    apCost: result.apKosten,
    seSpent: result.seVerbraucht,
  );
}

// Meisterentscheide bleiben als explizite Option im historischen Befehl.
Future<HeroAdvancementEntry?> _planAbility(
  BuildContext context,
  AdvancementSession session,
  AdvancementOption option,
  Map<String, String> options,
) async {
  final result = await showErwerbDialog(
    context: context,
    bezeichnung: option.label,
    kostenHinweis: option.ability?.kosten,
    vorgeschlageneApKosten: option.apCost,
    verfuegbareAp: session.preview.apAvailable,
    voraussetzungen: option.requirements,
    episch: session.preview.isEpisch,
    epischerInhalt: option.ability?.nurEpisch ?? false,
    lehrmeisterUeblich: true,
    confirmLabel: 'Vormerken',
  );
  if (result == null) return null;
  if (result.meisterentscheid) options['meisterentscheid'] = 'true';
  _recordTeacher(options, result.lehrmeisterTaW, result.dukaten);
  return _entry(
    session: session,
    option: option,
    options: options,
    apCost: result.apKosten,
  );
}

// Zusatzkosten werden dokumentiert; die Sitzung bucht ausschließlich AP und SE.
void _recordTeacher(Map<String, String> options, int? teacher, double? ducats) {
  if (teacher != null) options['lehrmeisterTaW'] = '$teacher';
  if (ducats != null) options['dukaten'] = '$ducats';
}

// Zeit und Identität gehören zum bestätigten Befehl, nicht zum Katalogeintrag.
HeroAdvancementEntry _entry({
  required AdvancementSession session,
  required AdvancementOption option,
  required Map<String, String> options,
  required int apCost,
  int? fromValue,
  int? toValue,
  int seSpent = 0,
}) => HeroAdvancementEntry(
  id: const Uuid().v4(),
  sessionId: session.sessionId,
  createdAt: DateTime.now().toUtc(),
  kind: option.kind,
  targetId: option.targetId,
  label: option.label,
  fromValue: fromValue,
  toValue: toValue,
  apCost: apCost,
  seSpent: seSpent,
  options: options,
);
