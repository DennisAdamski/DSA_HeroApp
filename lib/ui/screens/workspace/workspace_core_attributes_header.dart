import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';

/// Persistenter Attribut-Header ueber dem Tab-Inhalt im Workspace.
///
/// Zeigt Kurzwerte fuer alle 8 Eigenschaften, Ressourcen (LeP/Au/AsP/KaP)
/// und die aktuelle BE als kompakte Chips an. Wird bei jedem Providerwechsel
/// reaktiv neu gebaut.
class WorkspaceCoreAttributesHeader extends ConsumerWidget {
  const WorkspaceCoreAttributesHeader({
    super.key,
    required this.heroId,
    required this.hero,
  });

  /// ID des darzustellenden Helden.
  final String heroId;

  /// Helddaten als Fallback fuer die Berechnung effektiver Attribute.
  final HeroSheet hero;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveAsync = ref.watch(effectiveAttributesProvider(heroId));
    final stateAsync = ref.watch(heroStateProvider(heroId));
    final derivedAsync = ref.watch(derivedStatsProvider(heroId));
    final combatPreviewAsync = ref.watch(combatPreviewProvider(heroId));
    final talentBeOverride = ref.watch(talentBeOverrideProvider(heroId));
    final effectiveAttributes =
        effectiveAsync.valueOrNull ?? computeEffectiveAttributes(hero);
    final state = stateAsync.valueOrNull;
    final derived = derivedAsync.valueOrNull;
    final activeTalentBe =
        talentBeOverride ?? combatPreviewAsync.valueOrNull?.beKampf;

    // Formatiert Ressourcen als "aktuell/max" oder "-" bei fehlenden Daten.
    String resourceText(int? current, int? max) {
      final currentText = current?.toString() ?? '-';
      final maxText = max?.toString() ?? '-';
      return '$currentText/$maxText';
    }

    final debugModus = ref.watch(debugModusProvider);
    final chips = <String>[
      '${debugModus ? 'mu' : 'MU'}: ${effectiveAttributes.mu}',
      '${debugModus ? 'kl' : 'KL'}: ${effectiveAttributes.kl}',
      '${debugModus ? 'inn' : 'IN'}: ${effectiveAttributes.inn}',
      '${debugModus ? 'ch' : 'CH'}: ${effectiveAttributes.ch}',
      '${debugModus ? 'ff' : 'FF'}: ${effectiveAttributes.ff}',
      '${debugModus ? 'ge' : 'GE'}: ${effectiveAttributes.ge}',
      '${debugModus ? 'ko' : 'KO'}: ${effectiveAttributes.ko}',
      '${debugModus ? 'kk' : 'KK'}: ${effectiveAttributes.kk}',
      '${debugModus ? 'currentLep/maxLep' : 'LeP'}: ${resourceText(state?.currentLep, derived?.maxLep)}',
      '${debugModus ? 'currentAu/maxAu' : 'Au'}: ${resourceText(state?.currentAu, derived?.maxAu)}',
      '${debugModus ? 'currentAsp/maxAsp' : 'AsP'}: ${resourceText(state?.currentAsp, derived?.maxAsp)}',
      '${debugModus ? 'currentKap/maxKap' : 'KaP'}: ${resourceText(state?.currentKap, derived?.maxKap)}',
      '${debugModus ? 'beKampf' : 'BE'}: ${activeTalentBe?.toString() ?? '-'}',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: chips
            .map(
              (entry) => Chip(
                label: Text(entry),
                visualDensity: VisualDensity.compact,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
