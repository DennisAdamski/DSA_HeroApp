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
    // Unbelegte Unterbrechungsregeln werden explizit geklärt, nicht geraten.
    final kosten = await _abbruchKosten(context, h.wirken!.karmal);
    if (kosten == null || !context.mounted) return;
    final aktuell = ref.read(gefechtProvider(heroId));
    if (aktuell == null || aktuell.handlung != h || aktuell.auftrag != null) {
      return;
    }
    controller.setzen(
      aktuell.copyWith(
        handlung: h.copyWith(
          verbleibend: 0,
          gescheitert: true,
          abbruchKosten: kosten,
        ),
      ),
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

// Ein Abbruchprofil benötigt bestätigte Kosten und Folgen, aber keinen Wurf.
Future<int?> _abbruchKosten(BuildContext context, bool karmal) async {
  final eingabe = TextEditingController();
  var bestaetigt = false;
  final kosten = await showDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, aktualisieren) {
        final wert = int.tryParse(eingabe.text);
        return AlertDialog(
          title: const Text('Unterbrechung manuell klären'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: eingabe,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText:
                        'Bestätigte Unterbrechungskosten (${karmal ? 'KaP' : 'AsP'})',
                  ),
                  onChanged: (_) => aktualisieren(() {
                    bestaetigt = false;
                  }),
                ),
                CheckboxListTile(
                  value: bestaetigt,
                  title: const Text(
                    'Unterbrechungsfolgen am Spieltisch geklärt',
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
              child: const Text('Fortführen'),
            ),
            FilledButton(
              onPressed: bestaetigt && wert != null && wert >= 0
                  ? () => Navigator.pop(context, wert)
                  : null,
              child: const Text('Manuellen Abschluss vorbereiten'),
            ),
          ],
        );
      },
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 300));
  eingabe.dispose();
  return kosten;
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
      request: gefechtsProbeMitBonus(
        modifiziereGefechtsWirkprobe(
          request,
          gefechtsStoerungszuschlag(zuschlag, konzentrationsstaerke: konz),
        ),
        s.mirakelbonus,
      ),
      onResolved: (r) {
        if (abgewickelt) return;
        abgewickelt = true;
        ctl.abbrechen(id);
        if (gefechtsBonusPasst(request, s.mirakelbonus)) {
          ctl.setzen(
            ref.read(gefechtProvider(heroId))!.copyWith(ohneMirakelbonus: true),
          );
        }
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
