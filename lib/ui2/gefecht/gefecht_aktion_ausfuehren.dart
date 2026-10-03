import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_auftrag_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ablauf_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_kontext_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_angriff_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';

import 'gefecht_aktionsdialog.dart';
import 'gefecht_orientieren.dart';
import 'gefecht_schuss.dart';

import 'package:dsa_heldenverwaltung/rules/derived/gefecht_wirken_rules.dart';

/// Verwendet dieselbe Freigabe für Kontextdialog, einmalige Probe und Folgen.
Future<void> fuehreGefechtsaktionAus({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required KartoGefechtsAdapter bestand,
  required Gefechtszustand s,
  required HeroComputedSnapshot snapshot,
  RulesCatalog? k,
  required Gefechtsaktion aktion,
  required String titel,
  ManeuverDef? m,
  ResolvedProbeRequest? probe,
  bool manuell = false,
  String? beschreibung,
  GefechtsKampfmittelwahl? kampfmittel,
  bool zusatzParade = false,
}) async {
  final controller = ref.read(gefechtProvider(heroId).notifier);

  if (k == null) return;
  if (aktion == Gefechtsaktion.orientieren ||
      aktion == Gefechtsaktion.position && s.desorientiert) {
    await zeigeOrientieren(
      context: context,
      ref: ref,
      heroId: heroId,
      bestand: bestand,
      position: aktion == Gefechtsaktion.position,
    );
    return;
  }
  if (beschreibung != null) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titel),
        content: SingleChildScrollView(child: Text(beschreibung)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Weiter'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
  }
  final auftrag = await showDialog<GefechtAuftrag>(
    context: context,
    builder: (_) => GefechtAktionsdialog(
      zustand: s,
      werte: snapshot,
      katalog: k,
      aktion: aktion,
      titel: titel,
      manoever: m,
      probe: probe,
      manuell: manuell,
      kampfmittel: kampfmittel,
      zusatzParade: zusatzParade,
    ),
  );
  if (auftrag == null || !context.mounted) return;
  final frisch = ref.read(heroComputedProvider(heroId)).asData?.value;
  final aktuell = ref.read(gefechtProvider(heroId));
  if (frisch == null || aktuell == null) return;
  final p = pruefeGefechtAuftrag(aktuell, frisch, k, auftrag);
  final w = gefechtswerteFuer(
    frisch,
    katalog: k,
    kampfmittel: auftrag.kampfmittel,
  );
  if (!p.ausfuehrbar) {
    throw StateError(p.gruende.join(' '));
  }
  controller.setzen(aktuell.copyWith(dk: auftrag.dk, kontext: auftrag.kontext));
  final id = UniqueKey().toString();
  if (!controller.reservieren(id)) return;
  final basisRequest = gefechtRequestFuerAuftrag(auftrag, p);
  final bonus = aktuell.mirakelbonus;
  final request = basisRequest == null
      ? null
      : gefechtsProbeMitBonus(basisRequest, bonus);
  final restHandlung = gefechtHandlungNachAuftrag(
    titel: titel,
    dauer: auftrag.dauer,
    pruefung: p,
    probe: probe != null ? request : null,
  );
  ProbeResult? gewuerfelt;
  void buchen([ProbeResult? result]) {
    if (!controller.abschliessen(id, w, p, erfolg: result?.success)) return;
    gewuerfelt ??= result;
    final angriff = gefechtsAngriffsergebnisNachBuchung(
      auftragId: id,
      buchungErfolgreich: true,
      erfolg: result?.success == true,
      snapshot: frisch,
      katalog: k,
      auftrag: auftrag,
      pruefung: p,
    );
    if (p.aktion == Gefechtsaktion.angriff ||
        p.aktion == Gefechtsaktion.zusatzaktion && !auftrag.zusatzParade) {
      controller.setzen(
        ergaenzeGefechtsAngriffsergebnis(
          ref.read(gefechtProvider(heroId))!,
          angriff,
        ).copyWith(ohneZielstand: w.fernkampf),
      );
    }
    if (result != null &&
        request != null &&
        gefechtsBonusPasst(request, bonus)) {
      controller.setzen(
        ref.read(gefechtProvider(heroId))!.copyWith(ohneMirakelbonus: true),
      );
    }
    final jetzt = ref.read(gefechtProvider(heroId))!;
    if (restHandlung != null) {
      controller.setzen(jetzt.copyWith(handlung: restHandlung));
    }
    if (result != null &&
        w.fernkampf &&
        auftrag.aktion == Gefechtsaktion.angriff) {
      controller.setzen(
        jetzt.copyWith(
          handlung: Gefechtshandlung(
            titel: 'Schuss · Munition übernehmen',
            verbleibend: 0,
            art: Gefechtshandlungsart.fernkampf,
            ergebnis: result,
            waffe: w.waffe,
          ),
        ),
      );
    }
  }

  try {
    // Längere Zauber werden erst nach ihrer bestätigten Dauer ausgewertet.
    if (request == null || probe != null && restHandlung != null) {
      buchen();
    } else {
      await bestand.gefechtsProbe(
        context: context,
        ref: ref,
        heroId: heroId,
        request: request,
        onResolved: buchen,
      );
    }
    if (gewuerfelt?.success == true && auftrag.distanzSchritte > 0) {
      controller.setzen(
        ref
            .read(gefechtProvider(heroId))!
            .copyWith(
              dk: naechsteGefechtsDk(auftrag.dk, auftrag.distanzSchritte),
            ),
      );
    }
    if (gewuerfelt?.success == true &&
        auftrag.distanzSchritte < 0 &&
        context.mounted) {
      final abgewehrt = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Annäherung abwickeln'),
          content: const Text(
            'Kein Schaden. Hat der Gegner erfolgreich abgewehrt? Die freie Aktion Schritt am Spieltisch berücksichtigen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Abgewehrt'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Nicht abgewehrt'),
            ),
          ],
        ),
      );
      if (abgewehrt == false) {
        controller.setzen(
          ref
              .read(gefechtProvider(heroId))!
              .copyWith(
                dk: naechsteGefechtsDk(auftrag.dk, auftrag.distanzSchritte),
              ),
        );
      }
    }
  } finally {
    controller.abbrechen(id);
  }
  if (ref.read(gefechtProvider(heroId))?.handlung?.art ==
          Gefechtshandlungsart.fernkampf &&
      context.mounted) {
    await uebernimmGefechtsSchuss(
      context: context,
      ref: ref,
      heroId: heroId,
      bestand: bestand,
    );
  }
}
