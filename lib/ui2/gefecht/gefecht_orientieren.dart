import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_orientieren_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_wirken_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_initiative_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';

/// Fragt nur die am Spieltisch fehlende Ungestörtheit ab.
Future<void> zeigeOrientieren({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required KartoGefechtsAdapter bestand,
  bool position = false,
}) async {
  final snapshot = ref.read(heroComputedProvider(heroId)).asData?.value;
  final s = ref.read(gefechtMitInitiativeProvider(heroId));
  if (snapshot == null || s == null) return;
  final plan = orientierungFuer(snapshot, position: position);
  final werte = gefechtswerteFuer(snapshot);
  final danach = uebernimmOrientierung(
    s,
    maximum: orientierungsmaximum(snapshot),
    erfolg: true,
    position: position,
  );
  final p = pruefeOrientierung(
    s,
    gefechtswerteFuer(snapshot),
    position: position,
  );
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(position ? 'Position + Orientieren' : 'Orientieren'),
      content: Text(
        '${plan.dauer} reguläre Aktionen. '
        '${plan.probe?.subtitle ?? 'Aufmerksamkeit: ohne Probe.'}\n'
        '${plan.probe == null ? '' : 'IN-Zielwert: ${plan.probe!.targets.single.value}\n'}'
        'INI: ${gefechtsInitiative(s, werte)} → '
        '${gefechtsInitiative(danach, werte)} bei Erfolg.\n'
        'Erfolg übernimmt das INI-Maximum und behebt Kampfverluste. '
        'Wund- und Zaubermali bleiben erhalten.\n'
        '${p.gruende.join('\n')}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: p.status == Gefechtsfreigabe.gesperrt
              ? null
              : () => Navigator.pop(context, true),
          child: const Text('Ungestört beginnen'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final controller = ref.read(gefechtProvider(heroId).notifier);
  final aktuell = ref.read(gefechtMitInitiativeProvider(heroId));
  if (aktuell == null || aktuell.handlung != null) return;
  // Nur ein typisierter Fortsetzen-Pfad darf diese Resthandlung bearbeiten.
  controller.setzen(
    aktuell.copyWith(
      handlung: Gefechtshandlung(
        titel: position ? 'Position + Orientieren' : 'Orientieren',
        verbleibend: plan.dauer,
        art: position
            ? Gefechtshandlungsart.positionOrientieren
            : Gefechtshandlungsart.orientieren,
      ),
    ),
  );
  await fuehreOrientierungFort(
    context: context,
    ref: ref,
    heroId: heroId,
    bestand: bestand,
  );
}

/// Prüft frische Heldendaten und würfelt ausschließlich die letzte Aktion.
Future<void> fuehreOrientierungFort({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required KartoGefechtsAdapter bestand,
}) async {
  final s = ref.read(gefechtMitInitiativeProvider(heroId));
  final snapshot = ref.read(heroComputedProvider(heroId)).asData?.value;
  final h = s?.handlung;
  if (s == null || snapshot == null || h == null) return;
  final position = h.art == Gefechtshandlungsart.positionOrientieren;
  final w = gefechtswerteFuer(snapshot);
  final p = pruefeOrientierung(s, w, position: position, fortsetzen: true);
  if (p.status == Gefechtsfreigabe.gesperrt) {
    throw StateError(p.gruende.join(' '));
  }
  final controller = ref.read(gefechtProvider(heroId).notifier);
  final id = UniqueKey().toString();
  if (!controller.reservieren(id)) return;
  final plan = orientierungFuer(snapshot, position: position);
  void buchen(bool erfolg) {
    if (!controller.abschliessen(id, w, p)) return;
    var neu = ref.read(gefechtMitInitiativeProvider(heroId))!;
    if (h.verbleibend > 1) {
      neu = neu.copyWith(
        handlung: Gefechtshandlung(
          titel: h.titel,
          verbleibend: h.verbleibend - 1,
          art: h.art,
        ),
      );
    } else {
      neu = uebernimmOrientierung(
        neu,
        maximum: orientierungsmaximum(snapshot),
        erfolg: erfolg,
        position: position,
      ).copyWith(ohneHandlung: true);
    }
    controller.setzen(neu);
  }

  try {
    if (h.verbleibend > 1 || plan.probe == null) {
      buchen(true);
    } else {
      await bestand.gefechtsProbe(
        context: context,
        ref: ref,
        heroId: heroId,
        request: gefechtsProbeMitBonus(
          plan.probe!,
          s.mirakelbonus,
          ansageFolgemalus: s.ansageFolgemalus,
        ),
        onResolved: (r) {
          if (ref.read(gefechtMitInitiativeProvider(heroId))?.auftrag != id) {
            return;
          }
          buchen(r.success);
          if (gefechtsBonusPasst(plan.probe!, s.mirakelbonus)) {
            controller.setzen(
              ref
                  .read(gefechtMitInitiativeProvider(heroId))!
                  .copyWith(ohneMirakelbonus: true),
            );
          }
        },
      );
    }
  } finally {
    controller.abbrechen(id);
  }
}
