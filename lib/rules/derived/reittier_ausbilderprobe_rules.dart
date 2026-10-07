/// Gewürfelte Ausbilderproben der Reittier-Ausbildung (ZBA S. 34–36).
///
/// Der Held würfelt Abrichten, Tierkunde oder Reiten mit der Erschwernis des
/// Ausbildungsschritts bzw. der Lernprobe einer Pferde-SF. Der Request
/// entsteht über denselben Talentprobenbauer wie Probensuche und Gefecht.
library;

import 'package:dsa_heldenverwaltung/catalog/talent_def.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import 'talent_probe_rules.dart';

/// Ergebnis des Probenaufbaus: entweder ein Request oder der Grund, warum
/// nicht gewürfelt werden kann.
class AusbilderprobeAufbau {
  /// Erstellt das Ergebnis.
  const AusbilderprobeAufbau({this.request, this.hinweis});

  /// Fertiger Probenrequest; `null`, wenn [hinweis] belegt ist.
  final ResolvedProbeRequest? request;

  /// Warum nicht gewürfelt werden kann.
  final String? hinweis;
}

/// Baut die Probe auf [talentId] mit [erschwernis] (positiv heißt
/// erschwert) für den Helden aus [snapshot].
AusbilderprobeAufbau ausbilderprobeFuer({
  required HeroComputedSnapshot snapshot,
  required List<TalentDef> talente,
  required String talentId,
  required String talentName,
  required int erschwernis,
  required bool epicAdvantagesActive,
}) {
  TalentDef? talent;
  for (final kandidat in talente) {
    if (kandidat.id == talentId) {
      talent = kandidat;
      break;
    }
  }
  if (talent == null) {
    return AusbilderprobeAufbau(hinweis: '$talentName steht nicht im Katalog.');
  }
  final request = talentprobeFuer(
    snapshot: snapshot,
    talent: talent,
    epicAdvantagesActive: epicAdvantagesActive,
    initialSituationalModifier: -erschwernis,
  );
  if (request == null) {
    return AusbilderprobeAufbau(
      hinweis: 'Der Held führt $talentName nicht; am Tisch würfeln.',
    );
  }
  return AusbilderprobeAufbau(request: request);
}
