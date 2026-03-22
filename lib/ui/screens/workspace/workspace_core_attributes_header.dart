import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/resource_activation_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';

/// Persistenter Attribut-Header ueber dem Tab-Inhalt im Workspace.
///
/// Zeigt Kurzwerte fuer alle 8 Eigenschaften, Ressourcen (LeP/Au/AsP/KaP)
/// und die aktuelle BE als kompakte Chips an. Wird bei jedem Providerwechsel
/// reaktiv neu gebaut.
///
/// Wenn [showVitalRow] auf `false` gesetzt wird, werden die Vital-Karten
/// (LeP/Au/AsP/KaP/BE) ausgeblendet. Nur die Eigenschaften-Pillen (Row 2)
/// bleiben sichtbar. Auf breiten Screens (HeroDeck) wird Row 1 ausgeblendet,
/// da der Inspector die Vitalwerte bereits zeigt.
class WorkspaceCoreAttributesHeader extends ConsumerWidget {
  const WorkspaceCoreAttributesHeader({
    super.key,
    required this.heroId,
    required this.hero,
    this.showVitalRow = true,
  });

  /// ID des darzustellenden Helden.
  final String heroId;

  /// Helddaten als Fallback fuer die Berechnung effektiver Attribute.
  final HeroSheet hero;

  /// Ob die Vital-Karten-Row (LeP/Au/AsP/KaP/BE) angezeigt werden soll.
  /// Standardmaessig `true`. Auf breiten Screens (HeroDeck) wird dieser
  /// Parameter auf `false` gesetzt, da der Inspector die Werte zeigt.
  final bool showVitalRow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveAsync = ref.watch(effectiveAttributesProvider(heroId));
    final stateAsync = ref.watch(heroStateProvider(heroId));
    final derivedAsync = ref.watch(derivedStatsProvider(heroId));
    final combatPreviewAsync = ref.watch(combatPreviewProvider(heroId));
    final resourceActivationAsync = ref.watch(resourceActivationProvider(heroId));
    final talentBeOverride = ref.watch(talentBeOverrideProvider(heroId));
    final effectiveAttributes =
        effectiveAsync.valueOrNull ?? computeEffectiveAttributes(hero);
    final state = stateAsync.valueOrNull;
    final derived = derivedAsync.valueOrNull;
    final resourceActivation =
        resourceActivationAsync.valueOrNull ?? computeHeroResourceActivation(hero);
    final activeTalentBe =
        talentBeOverride ?? combatPreviewAsync.valueOrNull?.beKampf;
    final showMagicResources = resourceActivation.magic.isEnabled;
    final showDivineResources = resourceActivation.divine.isEnabled;

    // Formatiert Ressourcen als "aktuell/max" oder "-" bei fehlenden Daten.
    String resourceText(int? current, int? max) {
      final currentText = current?.toString() ?? '-';
      final maxText = max?.toString() ?? '-';
      return '$currentText/$maxText';
    }

    final debugModus = ref.watch(debugModusProvider);

    // Row 2: Eigenschaften-Pillen (immer sichtbar)
    final attributeChips = <String>[
      '${debugModus ? 'mu' : 'MU'}: ${effectiveAttributes.mu}',
      '${debugModus ? 'kl' : 'KL'}: ${effectiveAttributes.kl}',
      '${debugModus ? 'inn' : 'IN'}: ${effectiveAttributes.inn}',
      '${debugModus ? 'ch' : 'CH'}: ${effectiveAttributes.ch}',
      '${debugModus ? 'ff' : 'FF'}: ${effectiveAttributes.ff}',
      '${debugModus ? 'ge' : 'GE'}: ${effectiveAttributes.ge}',
      '${debugModus ? 'ko' : 'KO'}: ${effectiveAttributes.ko}',
      '${debugModus ? 'kk' : 'KK'}: ${effectiveAttributes.kk}',
    ];

    // Row 1: Vital-Karten (LeP/Au/AsP/KaP/BE) – nur wenn showVitalRow == true
    final vitalChips = <String>[
      '${debugModus ? 'currentLep/maxLep' : 'LeP'}: ${resourceText(state?.currentLep, derived?.maxLep)}',
      '${debugModus ? 'currentAu/maxAu' : 'Au'}: ${resourceText(state?.currentAu, derived?.maxAu)}',
      if (showMagicResources)
        '${debugModus ? 'currentAsp/maxAsp' : 'AsP'}: ${resourceText(state?.currentAsp, derived?.maxAsp)}',
      if (showDivineResources)
        '${debugModus ? 'currentKap/maxKap' : 'KaP'}: ${resourceText(state?.currentKap, derived?.maxKap)}',
      '${debugModus ? 'beKampf' : 'BE'}: ${activeTalentBe?.toString() ?? '-'}',
    ];

    Widget buildChipsScrollRow(List<String> chips) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: chips
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text(entry),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showVitalRow) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: vitalChips
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: Text(entry),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
            const SizedBox(height: 12),
          ],
          buildChipsScrollRow(attributeChips),
        ],
      ),
    );
  }
}
