import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/dice_log_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/zustand_aendern.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/epic_wound_relief.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/wund_ini_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/wund_unterdrueckung_dialog.dart';

/// Ändert den **gespeicherten** Wundzustand eines Helden.
///
/// Gemeinsamer Schreibweg von Wunden-Detaildialog, Inspector-Sektion und
/// Inspector-Karte. [aenderung] bekommt den frisch geladenen Wundzustand;
/// relative Schritte (eine Wunde mehr, eine Unterdrückung weniger) zählen
/// dadurch vom gespeicherten Stand aus, und Würfe, Ressourcen oder
/// Zaubereffekte, die seit dem Aufbau gespeichert wurden, bleiben erhalten.
/// [diceLogEntries] werden im selben Speichervorgang angehängt. Fehler
/// erscheinen als Snackbar, das Ergebnis ist dann `null`.
Future<HeroState?> aendereWundZustand({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required WundZustand Function(WundZustand aktuell) aenderung,
  List<DiceLogEntry> diceLogEntries = const <DiceLogEntry>[],
}) {
  return aendereZustandMitMeldung(
    context: context,
    ref: ref,
    heroId: heroId,
    was: 'Wunden',
    aenderung: (aktuell) => aktuell
        .copyWith(wpiZustand: aenderung(aktuell.wpiZustand))
        .withAppendedDiceLogEntries(diceLogEntries),
  );
}

/// Schaltet eine Unterdrückung in [zone] um [anzahl] Stufen weiter.
///
/// [unterdruecken] erhöht, sonst senkt es die Zahl unterdrückter Wunden;
/// `WundZustand.mitUnterdrueckung` hält sie in den Grenzen der Zone.
Future<HeroState?> schalteWundUnterdrueckung({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required WundZone zone,
  required bool unterdruecken,
  int anzahl = 1,
}) {
  final schritt = unterdruecken ? anzahl : -anzahl;
  return aendereWundZustand(
    context: context,
    ref: ref,
    heroId: heroId,
    aenderung: (aktuell) => aktuell.mitUnterdrueckung(
      zone,
      aktuell.unterdrueckteInZone(zone) + schritt,
    ),
  );
}

/// Fügt eine Wunde in [zone] hinzu und bietet danach die Unterdrückung an.
///
/// [angezeigt] ist der Stand der Oberfläche und entscheidet nur, ob die
/// Zone schon voll ist; gespeichert wird auf dem frischen Stand. Kopfwunden
/// fragen zuerst den INI-Wurf ab und protokollieren ihn mit. Der
/// Unterdrückungsdialog sieht den tatsächlich gespeicherten Wundzustand.
Future<void> fuegeWundeHinzu({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required WundZone zone,
  required WundZustand angezeigt,
}) async {
  if (angezeigt.wundenInZone(zone) >= maxWundenProZone) return;

  var iniWuerfelWert = 0;
  var diceLogEntries = const <DiceLogEntry>[];
  if (zone == WundZone.kopf) {
    final iniResult = await showWundIniDialog(context);
    if (iniResult == null || !context.mounted) return;
    iniWuerfelWert = iniResult.value;
    diceLogEntries = <DiceLogEntry>[iniResult.logEntry];
  }

  final gespeichert = await aendereWundZustand(
    context: context,
    ref: ref,
    heroId: heroId,
    aenderung: (aktuell) =>
        aktuell.mitWundeHinzu(zone, iniWuerfelWert: iniWuerfelWert),
    diceLogEntries: diceLogEntries,
  );
  if (gespeichert == null || !context.mounted) return;
  await bieteWundUnterdrueckungAn(
    context: context,
    ref: ref,
    heroId: heroId,
    zone: zone,
    gespeichert: gespeichert,
  );
}

/// Bietet für gerade gespeicherte Wunden in [zone] die Unterdrückung an.
///
/// [neueWunden] sind alle Wunden desselben Angriffs. Sie werden nur
/// gemeinsam unterdrückt, in einem Speichervorgang. [gespeichert] ist der
/// Zustand nach dem Speichern, damit der Dialog den tatsächlich
/// gespeicherten Wundzustand sieht. Gemeinsam genutzt von [fuegeWundeHinzu]
/// und dem Ablauf „Schaden erhalten“.
Future<void> bieteWundUnterdrueckungAn({
  required BuildContext context,
  required WidgetRef ref,
  required String heroId,
  required WundZone zone,
  required HeroState gespeichert,
  int neueWunden = 1,
}) async {
  final hero = ref.read(heroByIdProvider(heroId));
  if (hero == null) return;
  final neuerZustand = gespeichert.wpiZustand;
  final effekte = computeWundEffekte(
    neuerZustand,
    halbierteProbenErschwernis: isEpicWoundReliefActive(ref, hero),
  );
  final unterdruecken = await showWundUnterdrueckungDialog(
    context: context,
    hero: hero,
    wpiZustand: neuerZustand,
    zone: zone,
    wundEffekte: effekte,
    ref: ref,
    heroId: heroId,
    neueWunden: neueWunden,
  );
  if (unterdruecken != true || !context.mounted) return;
  await schalteWundUnterdrueckung(
    context: context,
    ref: ref,
    heroId: heroId,
    zone: zone,
    unterdruecken: true,
    anzahl: neueWunden,
  );
}
