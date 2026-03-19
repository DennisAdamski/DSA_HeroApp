import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/rules/derived/talent_value_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_rules.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/probe_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/probe_request_factory.dart';

/// Zeigt nach dem Hinzufuegen einer Wunde einen Dialog, der sofortige
/// Unterdrueckung via SB-Probe oder direkte Bestaetigung anbietet.
///
/// Gibt `true` zurueck wenn die Wunde unterdrueckt werden soll,
/// `false` oder `null` wenn sie aktiv bleibt.
Future<bool?> showWundUnterdrueckungDialog({
  required BuildContext context,
  required dynamic hero,
  required WundZustand wpiZustand,
  required WundZone zone,
  required WundEffekte wundEffekte,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _WundUnterdrueckungDialog(
      hero: hero,
      wpiZustand: wpiZustand,
      zone: zone,
      wundEffekte: wundEffekte,
    ),
  );
}

class _WundUnterdrueckungDialog extends StatelessWidget {
  const _WundUnterdrueckungDialog({
    required this.hero,
    required this.wpiZustand,
    required this.zone,
    required this.wundEffekte,
  });

  final dynamic hero;
  final WundZustand wpiZustand;
  final WundZone zone;
  final WundEffekte wundEffekte;

  @override
  Widget build(BuildContext context) {
    final gesamtWunden = wpiZustand.gesamtWunden;
    final erschwernis = computeSbUnterdrueckungErschwernis(
      gesamtWunden: gesamtWunden,
    );

    final sbEntry = (hero.talents as Map<String, HeroTalentEntry>?)
        ?['tal_selbstbeherrschung'];
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
      title: const Text('Wunde unterdrücken?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$zoneLabel — SB-Probe erschwert um '
            '4 × $gesamtWunden = $erschwernis',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: hatSb
                ? () {
                    final effectiveAttrs = computeEffectiveAttributes(hero);
                    const sbCodes = [
                      AttributeCode.mu,
                      AttributeCode.ko,
                      AttributeCode.kk,
                    ];
                    final targets = sbCodes
                        .map((code) => ProbeTargetValue(
                              label: code.name.toUpperCase(),
                              value:
                                  readAttributeValue(effectiveAttrs, code),
                            ))
                        .toList();
                    showProbeDialog(
                      context: context,
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
            label: Text(hatSb
                ? 'SB-Probe (TaW $sbTaw)'
                : 'SB nicht erlernt'),
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
