import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

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

    final chips = <String>[
      'MU: ${effectiveAttributes.mu}',
      'KL: ${effectiveAttributes.kl}',
      'IN: ${effectiveAttributes.inn}',
      'CH: ${effectiveAttributes.ch}',
      'FF: ${effectiveAttributes.ff}',
      'GE: ${effectiveAttributes.ge}',
      'KO: ${effectiveAttributes.ko}',
      'KK: ${effectiveAttributes.kk}',
      'LEP: ${resourceText(state?.currentLep, derived?.maxLep)}',
      'AU: ${resourceText(state?.currentAu, derived?.maxAu)}',
      'ASP: ${resourceText(state?.currentAsp, derived?.maxAsp)}',
      'KAP: ${resourceText(state?.currentKap, derived?.maxKap)}',
      'BE: ${activeTalentBe?.toString() ?? '-'}',
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
