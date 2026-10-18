import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/talent_herleitung_rules.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

/// Talent-ID der Selbstbeherrschung, auf die das Unterdrücken von Wunden würfelt.
const String kSelbstbeherrschungId = 'tal_selbstbeherrschung';

/// Der gespeicherte Heldenstand, aus dem die SB-Probe ihre Werte nimmt;
/// `null`, solange er noch lädt.
HeroComputedSnapshot? sbProbeSnapshot(WidgetRef ref, String heroId) =>
    ref.read(heroComputedProvider(heroId)).valueOrNull;

/// Herleitung des TaW* der Selbstbeherrschung wie bei jeder anderen
/// Talentprobe: mit Modifikatoren, Ausrüstung je Gegenstand und eBE
/// (`talentHerleitungNachId`).
///
/// `null`, solange Snapshot oder Katalog fehlen oder der Held die
/// Selbstbeherrschung nicht führt.
Herleitung? sbProbeHerleitung(WidgetRef ref, String heroId) {
  final snapshot = sbProbeSnapshot(ref, heroId);
  final katalog = ref.read(heroRulesCatalogProvider(heroId)).valueOrNull;
  if (snapshot == null || katalog == null) return null;
  return talentHerleitungNachId(
    snapshot: snapshot,
    talente: katalog.talents,
    talentId: kSelbstbeherrschungId,
    epicAdvantagesActive: ref.read(heroEpicAdvantagesActiveProvider(heroId)),
    talentBeOverride: ref.read(talentBeOverrideProvider(heroId)),
  )?.taw;
}

/// TaW* der Selbstbeherrschung; Summe von [sbProbeHerleitung].
int? sbProbeTaw(WidgetRef ref, String heroId) =>
    sbProbeHerleitung(ref, heroId)?.wert;
