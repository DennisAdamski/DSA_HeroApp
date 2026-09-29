import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/state/async_value_compat.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/rules/derived/talent_value_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_rules.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/dice_log_persistence.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/probe_request_factory.dart';

/// Zeigt nach neuen Wunden eines Angriffs einen Dialog, der sofortige
/// Unterdrueckung via SB-Probe oder direkte Bestaetigung anbietet.
///
/// [neueWunden] sind alle Wunden, die derselbe Angriff geschlagen hat; sie
/// werden nur gemeinsam unterdrueckt, nie einzeln. Die Erschwernis folgt
/// `computeSbUnterdrueckungErschwernis`.
///
/// Gibt `true` zurueck wenn die Wunden unterdrueckt werden sollen,
/// `false` oder `null` wenn sie aktiv bleiben.
Future<bool?> showWundUnterdrueckungDialog({
  required BuildContext context,
  required dynamic hero,
  required WundZustand wpiZustand,
  required WundZone zone,
  required WundEffekte wundEffekte,
  required WidgetRef ref,
  required String heroId,
  int neueWunden = 1,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _WundUnterdrueckungDialog(
      hero: hero,
      wpiZustand: wpiZustand,
      zone: zone,
      wundEffekte: wundEffekte,
      ref: ref,
      heroId: heroId,
      neueWunden: neueWunden,
    ),
  );
}

class _WundUnterdrueckungDialog extends StatelessWidget {
  const _WundUnterdrueckungDialog({
    required this.hero,
    required this.wpiZustand,
    required this.zone,
    required this.wundEffekte,
    required this.ref,
    required this.heroId,
    required this.neueWunden,
  });

  final dynamic hero;
  final WundZustand wpiZustand;
  final WundZone zone;
  final WundEffekte wundEffekte;
  final WidgetRef ref;
  final String heroId;
  final int neueWunden;

  @override
  Widget build(BuildContext context) {
    final gesamtWunden = wpiZustand.gesamtWunden;
    final erschwernis = computeSbUnterdrueckungErschwernis(
      gesamtWunden: gesamtWunden,
      neueWunden: neueWunden,
    );
    final herleitung = neueWunden == 1
        ? '4 × $gesamtWunden = $erschwernis'
        : '$erschwernis ($neueWunden Wunden aus einem Treffer)';

    final sbEntry =
        (hero.talents
            as Map<String, HeroTalentEntry>?)?['tal_selbstbeherrschung'];
    final hatSb = sbEntry != null && sbEntry.talentValue != null;
    final sbTaw = hatSb
        ? computeTalentComputedTaw(
            talentValue: sbEntry.talentValue,
            modifier: sbEntry.modifier,
            ebe: 0,
          )
        : 0;

    final zoneLabel = wundZoneLabel[zone] ?? zone.name;

    return AlertDialog(
      title: Text(
        neueWunden == 1
            ? 'Wunde unterdrücken?'
            : '$neueWunden Wunden unterdrücken?',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$zoneLabel — SB-Probe erschwert um $herleitung',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: hatSb
                ? () {
                    final effectiveAttrs = computeEffectiveAttributes(
                      hero,
                      catalog: ref.read(rulesCatalogProvider).valueOrNull,
                    );
                    const sbCodes = [
                      AttributeCode.mu,
                      AttributeCode.ko,
                      AttributeCode.kk,
                    ];
                    final targets = sbCodes
                        .map(
                          (code) => ProbeTargetValue(
                            label: code.name.toUpperCase(),
                            value: readAttributeValue(effectiveAttrs, code),
                          ),
                        )
                        .toList();
                    showLoggedProbeDialog(
                      context: context,
                      ref: ref,
                      heroId: heroId,
                      request: buildTalentProbeRequest(
                        title: 'Selbstbeherrschung (Wunde unterdrücken)',
                        targets: targets,
                        basePool: sbTaw,
                        wundMalus:
                            wundEffekte.talentProbeMalus + (-erschwernis),
                      ),
                    );
                  }
                : null,
            icon: const Icon(Icons.casino),
            label: Text(hatSb ? 'SB-Probe (TaW $sbTaw)' : 'SB nicht erlernt'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Nein'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Ja'),
        ),
      ],
    );
  }
}
