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

import 'package:dsa_heldenverwaltung/rules/derived/gefecht_laden_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_kampfmittel_rules.dart';

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
  await fuehreGefechtsAuftragAus(
    context: context,
    ref: ref,
    heroId: heroId,
    bestand: bestand,
    k: k,
    auftrag: auftrag,
  );
}

/// Führt auch einen fertig bezahlten Zielauftrag mit frischen Werten einmal aus.
Future<void> fuehreGefechtsAuftragAus({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required KartoGefechtsAdapter bestand,
  required RulesCatalog k,
  required GefechtAuftrag auftrag,
}) async {
  final controller = ref.read(gefechtProvider(heroId).notifier);
  final frisch = ref.read(heroComputedProvider(heroId)).asData?.value;
  final aktuell = ref.read(gefechtProvider(heroId));
  if (frisch == null || aktuell == null) return;
  final zielhandlung = aktuell.handlung?.art == Gefechtshandlungsart.zielen;
  if (zielhandlung &&
      aktuell.handlung!.vorbereitung!.schussauftrag != auftrag) {
    throw StateError('Vorbereiteter Schuss gehört zum ursprünglichen Auftrag.');
  }
  final p = zielhandlung
      ? pruefeGefechtsZielschuss(aktuell, frisch, k)
      : pruefeGefechtAuftrag(aktuell, frisch, k, auftrag);
  final w = gefechtswerteFuer(
    frisch,
    katalog: k,
    kampfmittel: auftrag.kampfmittel,
  );
  if (!p.ausfuehrbar) {
    if (!zielhandlung && w.fernkampf && auftrag.fernkampfansage > 0) {
      final beginn = pruefeGefechtsZielbeginn(aktuell, frisch, k, auftrag);
      if (beginn.ausfuehrbar) {
        controller.setzen(beginneGefechtsZielen(aktuell, frisch, k, auftrag));
        return;
      }
    }
    throw StateError(p.gruende.join(' '));
  }
  final waffe =
      gefechtsKampfmittelFuer(frisch, auftrag.kampfmittel)?.waffe ?? w.waffe;
  final bestaetigt = w.fernkampf && waffe != null
      ? bestaetigeGefechtsLadung(aktuell, waffe, true)
      : aktuell;
  controller.setzen(
    bestaetigt.copyWith(
      dk: auftrag.dk,
      kontext: auftrag.kontext,
      ohneHandlung: zielhandlung,
    ),
  );
  final id = UniqueKey().toString();
  if (!controller.reservieren(id)) return;
  final basisRequest = gefechtRequestFuerAuftrag(auftrag, p);
  final bonus = aktuell.mirakelbonus;
  final request = basisRequest == null
      ? null
      : gefechtsProbeMitBonus(basisRequest, bonus);
  final restHandlung = gefechtHandlungNachAuftrag(
    titel: auftrag.titel,
    dauer: auftrag.dauer,
    pruefung: p,
    probe: auftrag.probe != null ? request : null,
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
    if (request == null || auftrag.probe != null && restHandlung != null) {
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
    final nachher = ref.read(gefechtProvider(heroId));
    if (zielhandlung &&
        gewuerfelt == null &&
        nachher != null &&
        nachher.handlung == null &&
        nachher.auftrag == null) {
      controller.setzen(nachher.copyWith(handlung: aktuell.handlung));
    }
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
