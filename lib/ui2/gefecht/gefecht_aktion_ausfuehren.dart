import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_initiative_provider.dart';
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
import 'gefecht_meisterparade.dart';
import 'gefecht_patzer.dart';
import 'gefecht_klingen.dart';

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
  GefechtsDialogzweck zweck = GefechtsDialogzweck.aktion,
}) async {
  if (k == null) return;
  if (m != null && {'man_klingenwand', 'man_klingensturm'}.contains(m.id)) {
    await zeigeGefechtsKlingenbeginn(
      context: context,
      ref: ref,
      heroId: heroId,
      katalog: k,
      manoever: m,
      snapshot: snapshot,
      kampfmittel: kampfmittel,
    );
    return;
  }
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
      zweck: zweck,
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
  final aktuell = ref.read(gefechtMitInitiativeProvider(heroId));
  if (frisch == null || aktuell == null) return;
  final zielhandlung = aktuell.handlung?.art == Gefechtshandlungsart.zielen;
  if (zielhandlung &&
      aktuell.handlung!.vorbereitung!.schussauftrag != auftrag) {
    throw StateError('Vorbereiteter Schuss gehört zum ursprünglichen Auftrag.');
  }
  final aktuellerAuftrag = zielhandlung
      ? gefechtsAktuellerZielauftrag(aktuell)
      : auftrag;
  final p = zielhandlung
      ? pruefeGefechtsZielschuss(aktuell, frisch, k)
      : pruefeGefechtAuftrag(aktuell, frisch, k, aktuellerAuftrag);
  final w = gefechtswerteFuer(
    frisch,
    katalog: k,
    kampfmittel: aktuellerAuftrag.kampfmittel,
  );
  if (!p.ausfuehrbar) {
    final zielwahl =
        aktuellerAuftrag.fernkampfansage > 0 ||
        aktuellerAuftrag.zielErleichterung > 0;
    if (!zielhandlung && w.fernkampf && zielwahl) {
      final beginn = pruefeGefechtsZielbeginn(
        aktuell,
        frisch,
        k,
        aktuellerAuftrag,
      );
      if (beginn.ausfuehrbar) {
        controller.setzen(
          beginneGefechtsZielen(aktuell, frisch, k, aktuellerAuftrag),
        );
        return;
      }
    }
    throw StateError(p.gruende.join(' '));
  }
  final waffe =
      gefechtsKampfmittelFuer(frisch, aktuellerAuftrag.kampfmittel)?.waffe ??
      w.waffe;
  final bestaetigt = w.fernkampf && waffe != null
      ? bestaetigeGefechtsLadung(aktuell, waffe, true)
      : aktuell;
  controller.setzen(
    bestaetigt.copyWith(
      dk: aktuellerAuftrag.dk,
      kontext: aktuellerAuftrag.kontext,
      ohneHandlung: zielhandlung,
    ),
  );
  final id = UniqueKey().toString();
  if (!controller.reservieren(id)) return;
  final basisRequest = gefechtRequestFuerAuftrag(aktuellerAuftrag, p);
  final bonus = aktuell.mirakelbonus;
  final request = basisRequest == null
      ? null
      : gefechtsProbeMitBonus(basisRequest, bonus);
  final restHandlung = gefechtHandlungNachAuftrag(
    titel: aktuellerAuftrag.titel,
    dauer: aktuellerAuftrag.dauer,
    pruefung: p,
    probe: aktuellerAuftrag.probe != null ? request : null,
  );
  ProbeResult? gewuerfelt;
  void buchen([ProbeResult? result]) {
    if (!controller.abschliessen(id, w, p, erfolg: result?.success)) return;
    gewuerfelt ??= result;
    if (result != null && !w.fernkampf) {
      starteGefechtsPatzer(
        ref: ref,
        heroId: heroId,
        auftragId: id,
        result: result,
        kampfmittel: p.kampfmittel ?? aktuellerAuftrag.kampfmittel,
      );
    }
    final angriff = gefechtsAngriffsergebnisNachBuchung(
      auftragId: id,
      buchungErfolgreich: true,
      erfolg: result?.success == true,
      snapshot: frisch,
      katalog: k,
      auftrag: aktuellerAuftrag,
      pruefung: p,
    );
    if (p.aktion == Gefechtsaktion.angriff ||
        p.aktion == Gefechtsaktion.zusatzaktion &&
            !aktuellerAuftrag.zusatzParade) {
      controller.setzen(
        ergaenzeGefechtsAngriffsergebnis(
          ref.read(gefechtMitInitiativeProvider(heroId))!,
          angriff,
        ).copyWith(ohneZielstand: w.fernkampf),
      );
    }
    if (result != null &&
        request != null &&
        gefechtsBonusPasst(request, bonus)) {
      controller.setzen(
        ref
            .read(gefechtMitInitiativeProvider(heroId))!
            .copyWith(ohneMirakelbonus: true),
      );
    }
    final jetzt = ref.read(gefechtMitInitiativeProvider(heroId))!;
    if (restHandlung != null) {
      controller.setzen(jetzt.copyWith(handlung: restHandlung));
    }
    if (result != null &&
        w.fernkampf &&
        aktuellerAuftrag.aktion == Gefechtsaktion.angriff) {
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
    if (request == null ||
        aktuellerAuftrag.probe != null && restHandlung != null) {
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
    if (gewuerfelt?.success == true && aktuellerAuftrag.distanzSchritte > 0) {
      controller.setzen(
        ref
            .read(gefechtMitInitiativeProvider(heroId))!
            .copyWith(
              dk: naechsteGefechtsDk(
                aktuellerAuftrag.dk,
                aktuellerAuftrag.distanzSchritte,
              ),
            ),
      );
    }
    if (gewuerfelt?.success == true &&
        aktuellerAuftrag.distanzSchritte < 0 &&
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
              .read(gefechtMitInitiativeProvider(heroId))!
              .copyWith(
                dk: naechsteGefechtsDk(
                  aktuellerAuftrag.dk,
                  aktuellerAuftrag.distanzSchritte,
                ),
              ),
        );
      }
    }
  } finally {
    controller.abbrechen(id);
    final nachher = ref.read(gefechtMitInitiativeProvider(heroId));
    if (zielhandlung &&
        gewuerfelt == null &&
        nachher != null &&
        nachher.handlung == null &&
        nachher.auftrag == null) {
      controller.setzen(nachher.copyWith(handlung: aktuell.handlung));
    }
  }
  if (gewuerfelt?.success == false &&
      aktuellerAuftrag.manoever?.id == 'man_meisterparade' &&
      context.mounted) {
    await zeigeMeisterparadeFehlschlag(context, aktuellerAuftrag, frisch);
  }
  if (ref.read(gefechtMitInitiativeProvider(heroId))?.handlung?.art ==
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
