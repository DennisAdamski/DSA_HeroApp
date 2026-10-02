import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_magie_rules.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_wirken_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_requirement_context.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';

import 'gefecht_wirkabschluss.dart';

/// Ein begonnener Zauber wird bei Abbruch als offener Kostenabschluss erhalten.
Future<void> brecheGefechtsHandlungAb({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
}) async {
  final s = ref.read(gefechtProvider(heroId));
  final h = s?.handlung;
  if (s == null || h == null || s.auftrag != null) return;
  if (h.art == Gefechtshandlungsart.fernkampf || h.kostenUebernommen) {
    throw StateError(
      'Offene Übernahme zuerst abschließen; verbrauchte Folgen bleiben verbindlich.',
    );
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Handlung abbrechen?'),
      content: Text(
        h.wirken != null
            ? 'Dauer endet. Kosten und Unterbrechungsfolgen sind anschließend zu bestätigen; '
                  'die eingefrorene Probe wird nicht wiederholt.'
            : 'Die Restdauer endet; bereits verbrauchte Aktionen bleiben verbraucht.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Fortführen'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Abbruch bestätigen'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final controller = ref.read(gefechtProvider(heroId).notifier);
  if (h.wirken != null) {
    if (h.ergebnis == null) {
      throw StateError(
        'Karmale Unterbrechungsfolgen und Probe manuell klären.',
      );
    }
    controller.setzen(
      s.copyWith(handlung: h.copyWith(verbleibend: 0, gescheitert: true)),
    );
    await zeigeGefechtsWirkabschluss(
      context: context,
      ref: ref,
      heroId: heroId,
    );
  } else {
    controller.setzen(s.copyWith(ohneHandlung: true));
  }
}

/// Störungen würfeln Selbstbeherrschung und erhalten die ursprüngliche Zauberprobe.
Future<void> stoereGefechtsWirken({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required KartoGefechtsAdapter bestand,
}) async {
  final s = ref.read(gefechtProvider(heroId));
  final h = s?.handlung;
  final snapshot = ref.read(heroComputedProvider(heroId)).asData?.value;
  final katalog = ref.read(rulesCatalogProvider).asData?.value;
  if (s == null ||
      h?.wirken == null ||
      snapshot == null ||
      katalog == null ||
      h!.verbleibend == 0) {
    return;
  }
  if (h.art != Gefechtshandlungsart.zauber) {
    throw StateError(
      'Karmale Unterbrechungsregel aus dem konkreten Profil manuell klären.',
    );
  }
  final controller = TextEditingController(text: '7');
  var bestaetigt = false;
  final zuschlag = await showDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, aktualisieren) => AlertDialog(
        title: const Text('Störung prüfen'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Störung: SP / ZfP* / bestätigter Zuschlag',
                ),
                onChanged: (_) => aktualisieren(() {
                  bestaetigt = false;
                }),
              ),
              CheckboxListTile(
                value: bestaetigt,
                title: const Text(
                  'Neue Mali und Auswirkungen auf ZfP* geprüft',
                ),
                onChanged: (v) => aktualisieren(() {
                  bestaetigt = v!;
                }),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: bestaetigt && int.tryParse(controller.text) != null
                ? () => Navigator.pop(context, int.parse(controller.text))
                : null,
            child: const Text('Selbstbeherrschung prüfen'),
          ),
        ],
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 300));
  controller.dispose();
  if (zuschlag == null || !context.mounted) return;
  final talent = katalog.talents
      .where((t) => t.id == 'tal_selbstbeherrschung')
      .firstOrNull;
  if (talent == null) throw StateError('Selbstbeherrschungsprofil fehlt.');
  final request = gefechtsTalentprobe(snapshot, talent);
  if (request == null) throw StateError('Selbstbeherrschungswerte fehlen.');
  final konz = heroSpecialAbilityNames(
    snapshot.hero,
    catalog: katalog,
  ).any((n) => n.toLowerCase().startsWith('konzentrationsstärke'));
  final ctl = ref.read(gefechtProvider(heroId).notifier);
  final id = UniqueKey().toString();
  if (!ctl.reservieren(id)) return;
  var abgewickelt = false;
  try {
    await bestand.gefechtsProbe(
      context: context,
      ref: ref,
      heroId: heroId,
      request: modifiziereGefechtsWirkprobe(
        request,
        gefechtsStoerungszuschlag(zuschlag, konzentrationsstaerke: konz),
      ),
      onResolved: (r) {
        if (abgewickelt) return;
        abgewickelt = true;
        ctl.abbrechen(id);
        if (!r.success) {
          ctl.setzen(
            ref
                .read(gefechtProvider(heroId))!
                .copyWith(
                  handlung: h.copyWith(verbleibend: 0, gescheitert: true),
                ),
          );
        }
      },
    );
  } finally {
    ctl.abbrechen(id);
  }
  if (context.mounted &&
      ref.read(gefechtProvider(heroId))?.handlung?.gescheitert == true) {
    await zeigeGefechtsWirkabschluss(
      context: context,
      ref: ref,
      heroId: heroId,
    );
  }
}
