import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_wirken.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ablauf_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_wirken_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';

import 'gefecht_wirkdialog.dart';
import 'gefecht_wirkabschluss.dart';

/// Der Startdialog liefert ein ausdrücklich bestätigtes, flüchtiges Regelprofil.
Future<void> zeigeGefechtsWirken({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required KartoGefechtsAdapter bestand,
  SpellDef? zauber,
  TalentDef? talent,
}) async {
  final snapshot = ref.read(heroComputedProvider(heroId)).asData?.value;
  final s = ref.read(gefechtProvider(heroId));
  if (snapshot == null || s == null || s.handlung != null) return;
  final profil = await showDialog<(Gefechtshandlungsart, GefechtsWirkprofil)>(
    context: context,
    builder: (_) => GefechtWirkdialog(
      snapshot: snapshot,
      zustand: s,
      zauber: zauber,
      talent: talent,
    ),
  );
  if (profil == null || !context.mounted) return;
  final frisch = ref.read(heroComputedProvider(heroId)).asData?.value;
  if (frisch == null ||
      frisch.hero != snapshot.hero ||
      frisch.state != snapshot.state) {
    throw StateError('Held inzwischen geändert; Wirkprofil erneut bestätigen.');
  }
  await starteGefechtsWirken(
    context: context,
    ref: ref,
    heroId: heroId,
    bestand: bestand,
    art: profil.$1,
    profil: profil.$2,
  );
}

/// Reserviert die erste Marke und friert das erste Ergebnis genau einmal ein.
Future<void> starteGefechtsWirken({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required KartoGefechtsAdapter bestand,
  required Gefechtshandlungsart art,
  required GefechtsWirkprofil profil,
}) async {
  final s = ref.read(gefechtProvider(heroId));
  final snapshot = ref.read(heroComputedProvider(heroId)).asData?.value;
  if (s == null || snapshot == null || s.handlung != null || profil.dauer < 1) {
    return;
  }
  final w = gefechtswerteFuer(snapshot);
  final p = pruefeManuelleGefechtsaktion(s, w, kosten: 1);
  if (p.status == Gefechtsfreigabe.gesperrt ||
      snapshot.wundEffekte.kampfunfaehig) {
    throw StateError('Wirken nicht möglich. ${p.gruende.join(' ')}');
  }
  final energie = profil.karmal
      ? snapshot.state.currentKap
      : snapshot.state.currentAsp;
  if (energie < profil.kosten) {
    throw StateError('Nicht genügend Energie für die geplanten Kosten.');
  }
  if (art == Gefechtshandlungsart.zauber &&
      snapshot.derivedStats.maxAu > 0 &&
      snapshot.state.currentAu <= 0) {
    throw StateError('Ohne Ausdauer kein Zaubern.');
  }
  final controller = ref.read(gefechtProvider(heroId).notifier);
  final id = UniqueKey().toString();
  if (!controller.reservieren(id)) return;
  void buchen([ProbeResult? r]) {
    if (!controller.abschliessen(id, w, p)) return;
    final dauer = r != null && art == Gefechtshandlungsart.zauber
        ? gefechtsWirkdauer(
            profil.dauer,
            erfolg: r.success,
            zauberkontrolle: profil.zauberkontrolle,
          )
        : profil.dauer;
    controller.setzen(
      ref
          .read(gefechtProvider(heroId))!
          .copyWith(
            karmaleFehlversuche: profil.neueSpielrunde ? {} : null,
            ohneMirakelbonus:
                r != null && gefechtsBonusPasst(profil.probe, s.mirakelbonus),
            handlung: Gefechtshandlung(
              titel: profil.probe.title,
              verbleibend: dauer - 1,
              art: art,
              wirken: profil,
              ergebnis: r,
            ),
          ),
    );
  }

  try {
    if (profil.endprobe && profil.dauer > 1) {
      buchen();
    } else {
      await bestand.gefechtsProbe(
        context: context,
        ref: ref,
        heroId: heroId,
        request: gefechtsProbeMitBonus(profil.probe, s.mirakelbonus),
        onResolved: buchen,
      );
    }
  } finally {
    controller.abbrechen(id);
  }
  if (context.mounted &&
      ref.read(gefechtProvider(heroId))?.handlung?.verbleibend == 0) {
    await zeigeGefechtsWirkabschluss(
      context: context,
      ref: ref,
      heroId: heroId,
    );
  }
}

/// Fortsetzen benötigt eine Marke, aber niemals eine zweite Startprobe.
Future<void> setzeGefechtsWirkenFort({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required KartoGefechtsAdapter bestand,
}) async {
  final s = ref.read(gefechtProvider(heroId));
  final h = s?.handlung;
  final snapshot = ref.read(heroComputedProvider(heroId)).asData?.value;
  if (s == null || h?.wirken == null || snapshot == null) return;
  if (h!.verbleibend == 0) {
    await zeigeGefechtsWirkabschluss(
      context: context,
      ref: ref,
      heroId: heroId,
    );
    return;
  }
  final w = gefechtswerteFuer(snapshot);
  final p = pruefeManuelleGefechtsaktion(
    s,
    w,
    kosten: 1,
    handlungFortsetzen: true,
  );
  if (p.status == Gefechtsfreigabe.gesperrt) {
    throw StateError(p.gruende.join(' '));
  }
  final controller = ref.read(gefechtProvider(heroId).notifier);
  final id = UniqueKey().toString();
  if (!controller.reservieren(id)) return;
  void buchen([ProbeResult? r]) {
    if (!controller.abschliessen(id, w, p)) return;
    controller.setzen(
      ref
          .read(gefechtProvider(heroId))!
          .copyWith(
            handlung: h.copyWith(verbleibend: h.verbleibend - 1, ergebnis: r),
            ohneMirakelbonus:
                r != null &&
                gefechtsBonusPasst(h.wirken!.probe, s.mirakelbonus),
          ),
    );
  }

  try {
    if (h.verbleibend == 1 && h.ergebnis == null && h.wirken!.endprobe) {
      await bestand.gefechtsProbe(
        context: context,
        ref: ref,
        heroId: heroId,
        request: gefechtsProbeMitBonus(h.wirken!.probe, s.mirakelbonus),
        onResolved: buchen,
      );
    } else {
      buchen();
    }
  } finally {
    controller.abbrechen(id);
  }
  if (context.mounted &&
      ref.read(gefechtProvider(heroId))?.handlung?.verbleibend == 0) {
    await zeigeGefechtsWirkabschluss(
      context: context,
      ref: ref,
      heroId: heroId,
    );
  }
}
