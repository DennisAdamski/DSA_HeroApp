import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_options.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_specialization_rules.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/talent_specialization_name_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/erwerb_dialog.dart';

/// Erfasst eine Spezialisierung als Erwerbsbefehl ohne unmittelbare Speicherung.
Future<HeroAdvancementEntry?> showAdvancementSpecializationDialog({
  required BuildContext context,
  required AdvancementSession session,
  required String talentId,
}) async {
  final rules = AdvancementContext(
    hero: session.preview,
    catalog: session.catalog,
  );
  final choices = advancementSpecializationChoices(rules, talentId);
  final old = session.preview.talents[talentId]!;
  final owned = advancementTalentSpecializations(old);
  final available = choices.where((name) => !owned.contains(name)).toList();
  final talentName = session.catalog.talents
      .where((def) => def.id == talentId)
      .map((def) => def.name)
      .firstOrNull;
  final name = await showAdaptiveInputDialog<String>(
    context: context,
    builder: (_) => TalentSpecializationNameDialog(
      choices: available,
      useSelection: choices.isNotEmpty,
      talentName: talentName,
      hint: advancementSpecializationHint(rules, talentId),
      owned: owned,
    ),
  );
  if (name == null || !context.mounted) return null;
  final options = {'action': 'specialization', 'specialization': name.trim()};
  final option = resolveTalentSpecialization(rules, talentId, options)!;
  if (option.unavailableReason != null) {
    throw StateError(option.unavailableReason!);
  }
  final result = await showErwerbDialog(
    context: context,
    bezeichnung: option.label,
    vorgeschlageneApKosten: option.apCost,
    kostenHinweis: option.complexityHint,
    verfuegbareAp: session.preview.apAvailable,
    episch: session.preview.isEpisch,
    lehrmeisterUeblich: true,
    lehrmeisterVerdoppeltOhneIhn: true,
    confirmLabel: 'Vormerken',
  );
  if (result == null) return null;
  return HeroAdvancementEntry(
    id: const Uuid().v4(),
    sessionId: session.sessionId,
    createdAt: DateTime.now().toUtc(),
    kind: AdvancementKind.talent,
    targetId: talentId,
    label: option.label,
    apCost: result.apKosten,
    options: {
      ...option.options,
      if (result.lehrmeisterTaW != null)
        'lehrmeisterTaW': '${result.lehrmeisterTaW}',
      if (result.dukaten != null) 'dukaten': '${result.dukaten}',
    },
  );
}
