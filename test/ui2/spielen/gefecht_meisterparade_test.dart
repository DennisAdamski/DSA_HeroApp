import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_auftrag_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_aktionsdialog.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_ansicht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_wirken.dart';

import '../../rules/gefecht_ansagen_paket2_test.dart' as fixture;
import '../shell/karto_test_support.dart';
import '../../rules/gefecht_meisterparade_rules_test.dart' as mp;
import 'gefecht_test_support.dart';

const meisterparade = ManeuverDef(
  id: 'man_meisterparade',
  name: 'Meisterparade',
  gruppe: 'bewaffnet',
  erschwernis: 'Abwehr +Ansage',
  typ: 'Abwehraktion',
);

void main() {
  testWidgets(
    'Schild-Meisterparade erleichtert echte Zusatzabwehr und bucht genau einmal',
    (tester) async {
      final (container, bestand) = await _ansicht(
        tester,
        bonus: 0,
        schild: true,
      );
      final snap = mp.mpSnapshot(schild: true);
      final schildPa = snap.combatPreviewStats.shieldPa;
      final ctl = container.read(gefechtProvider('rondra').notifier);
      await _oeffnen(tester, 'Meisterparade');
      await tester.enterText(
        find.byKey(const ValueKey('gefecht-meisterparade-ansage')),
        '3',
      );
      await tester.enterText(
        find.byKey(const ValueKey('gefecht-schild-ansagegrenze')),
        '3',
      );
      await tester.pump();
      final starten = find.byKey(const ValueKey('gefecht-auftrag-starten'));
      expect(tester.widget<FilledButton>(starten).onPressed, isNotNull);
      await tester.tap(starten);
      await tester.pumpAndSettle();
      final nachMeisterparade = container.read(gefechtProvider('rondra'))!;
      expect(bestand.anfragen.single.type, ProbeType.combatParry);
      expect(bestand.anfragen.single.title, contains('Schild'));
      expect(bestand.anfragen.single.targets.single.value, schildPa - 3);
      expect(nachMeisterparade.paradenVerbraucht, 1);
      expect(nachMeisterparade.zusatzVerbraucht, 0);
      expect(nachMeisterparade.meisterparadeBonus, 3);
      expect(
        nachMeisterparade.regulaeresParademittel?.art,
        GefechtsKampfmittelArt.schild,
      );
      expect(nachMeisterparade.regulaeresParadepaar, isNotNull);
      expect(nachMeisterparade.kontext.finte, isNull);

      // Ein neuer Angriff ist nötig: die reguläre PA hat die Angriffsdaten gelöscht.
      const kontext = Gefechtskontext(
        angriffsart: Gefechtsangriffsart.nahkampf,
        finte: 1,
        schildWmWirksam: true,
        situationsZuschlag: 0,
      );
      ctl.setzen(nachMeisterparade.copyWith(kontext: kontext));
      await tester.pumpAndSettle();
      final vorZusatz = container.read(gefechtProvider('rondra'))!;
      final auftrag = GefechtAuftrag(
        aktion: Gefechtsaktion.zusatzaktion,
        titel: 'Zusätzliche Schildparade',
        zuschlag: 0,
        dk: 'N',
        dauer: 1,
        kosten: 1,
        zusatzParade: true,
        kampfmittel: nachMeisterparade.regulaeresParademittel,
        kontext: kontext,
      );
      final pruefung = pruefeGefechtAuftrag(
        vorZusatz,
        snap,
        testCatalog,
        auftrag,
      );
      final ohneBonus = pruefeGefechtAuftrag(
        vorZusatz.copyWith(meisterparadeBonus: 0),
        snap,
        testCatalog,
        auftrag,
      );
      expect(pruefung.ausfuehrbar, true);
      expect(ohneBonus.ausfuehrbar, true);
      expect(pruefung.zielwert, ohneBonus.zielwert! + 3);
      expect(pruefung.zielwert, schildPa - 1 + 3);
      final bonusMods = pruefung.modifikatoren
          .where((m) => m.name == 'Meisterparade-Bonus')
          .toList();
      expect(bonusMods, hasLength(1));
      expect(bonusMods.single.wert, -3);
      expect(pruefung.zusatz, 1);
      expect(pruefung.paraden, 0);

      for (final dialogAbbruch in [true, false]) {
        bestand.abbrechen = !dialogAbbruch;
        await _oeffnen(tester, 'Zusätzliche Schildparade');
        expect(
          find.textContaining('Zielwert ${pruefung.zielwert}'),
          findsOneWidget,
        );
        expect(tester.widget<FilledButton>(starten).onPressed, isNotNull);
        await tester.tap(dialogAbbruch ? find.text('Abbrechen') : starten);
        await tester.pumpAndSettle();
        final abgebrochen = container.read(gefechtProvider('rondra'))!;
        expect(abgebrochen.meisterparadeBonus, 3);
        expect(abgebrochen.paradenVerbraucht, 1);
        expect(abgebrochen.zusatzVerbraucht, 0);
        expect(abgebrochen.angriffeVerbraucht, vorZusatz.angriffeVerbraucht);
        expect(abgebrochen.freieVerbraucht, vorZusatz.freieVerbraucht);
        expect(abgebrochen.kontext.finte, 1);
        expect(abgebrochen.auftrag, isNull);
      }
      expect(bestand.anfragen, hasLength(2));
      expect(bestand.anfragen.last.targets.single.value, pruefung.zielwert);

      // Zählt echte Zustandsübergänge, einschließlich des wiederholten Callbacks.
      var bonusEntfernungen = 0;
      var zusatzBuchungen = 0;
      final subscription = container.listen(gefechtProvider('rondra'), (
        vorher,
        nachher,
      ) {
        if (vorher?.meisterparadeBonus == 3 &&
            nachher?.meisterparadeBonus == 0) {
          bonusEntfernungen++;
        }
        if (vorher?.zusatzVerbraucht == 0 && nachher?.zusatzVerbraucht == 1) {
          zusatzBuchungen++;
        }
      });
      addTearDown(subscription.close);
      bestand.abbrechen = false;
      bestand.doppelt = true;
      await _oeffnen(tester, 'Zusätzliche Schildparade');
      await tester.tap(starten);
      await tester.pumpAndSettle();
      final gebucht = container.read(gefechtProvider('rondra'))!;
      expect(bestand.anfragen, hasLength(3));
      expect(bestand.anfragen.last.type, ProbeType.combatParry);
      expect(bestand.anfragen.last.title, contains('Schild'));
      expect(bestand.anfragen.last.targets.single.value, pruefung.zielwert);
      expect(gebucht.paradenVerbraucht, 1);
      expect(gebucht.zusatzVerbraucht, 1);
      expect(gebucht.meisterparadeBonus, 0);
      expect(gebucht.angriffeVerbraucht, vorZusatz.angriffeVerbraucht);
      expect(gebucht.freieVerbraucht, vorZusatz.freieVerbraucht);
      expect(gebucht.kontext.finte, isNull);
      expect(gebucht.auftrag, isNull);
      expect(bonusEntfernungen, 1);
      expect(zusatzBuchungen, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Meisterparade verlangt eigene Zahl und sperrt ungültigen Text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GefechtAktionsdialog(
            zustand: const Gefechtszustand(iniWurf: 6, dk: 'N'),
            werte: fixture.ansageSnapshot(sf: true),
            katalog: testCatalog,
            aktion: Gefechtsaktion.parade,
            titel: 'Meisterparade',
            manoever: meisterparade,
          ),
        ),
      ),
    );
    final feld = find.byKey(const ValueKey('gefecht-meisterparade-ansage'));
    expect(feld, findsOneWidget);
    await tester.enterText(feld, 'abc');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('gefecht-auftrag-starten')),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.textContaining('Meisterparade-Ansage muss eine ganze Zahl'),
      findsWidgets,
    );
  });
  testWidgets(
    'Schildgrenze ist konkrete Zahl und ersetzt keinen Hauptwaffen-TaW',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GefechtAktionsdialog(
              zustand: const Gefechtszustand(
                iniWurf: 6,
                dk: 'N',
                kontext: Gefechtskontext(
                  angriffsart: Gefechtsangriffsart.nahkampf,
                  finte: 0,
                  schildWmWirksam: true,
                  situationsZuschlag: 0,
                ),
              ),
              werte: mp.mpSnapshot(schild: true),
              katalog: testCatalog,
              aktion: Gefechtsaktion.parade,
              titel: 'Meisterparade',
              manoever: mp.meisterparade,
            ),
          ),
        ),
      );
      final ansage = find.byKey(const ValueKey('gefecht-meisterparade-ansage'));
      final grenze = find.byKey(const ValueKey('gefecht-schild-ansagegrenze'));
      await tester.enterText(ansage, '3');
      await tester.pump();
      final button = find.byKey(const ValueKey('gefecht-auftrag-starten'));
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      for (final text in ['abc', '-1', '2', '3']) {
        await tester.enterText(grenze, text);
        await tester.pump();
        expect(
          tester.widget<FilledButton>(button).onPressed == null,
          text != '3',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );
  for (final fall in [
    'Erfolg',
    'Misslingen',
    'Dialogabbruch',
    'Probeabbruch',
  ]) {
    testWidgets('Meisterparade: $fall bucht und verändert Bonus exakt einmal', (
      tester,
    ) async {
      final (container, bestand) = await _ansicht(tester);
      bestand.doppelt = true;
      bestand.abbrechen = fall == 'Probeabbruch';
      bestand.w20Wert = fall == 'Misslingen' ? 20 : 1;
      await _oeffnen(tester, 'Meisterparade');
      await tester.enterText(
        find.byKey(const ValueKey('gefecht-meisterparade-ansage')),
        '3',
      );
      await tester.pump();
      expect(find.textContaining('Zielwert 19'), findsOneWidget);
      await tester.tap(
        fall == 'Dialogabbruch'
            ? find.text('Abbrechen')
            : find.byKey(const ValueKey('gefecht-auftrag-starten')),
      );
      await tester.pumpAndSettle();
      final state = container.read(gefechtProvider('rondra'))!;
      final gebucht = fall == 'Erfolg' || fall == 'Misslingen';
      expect(state.paradenVerbraucht, gebucht ? 1 : 0);
      expect(
        state.meisterparadeBonus,
        fall == 'Erfolg'
            ? 3
            : fall == 'Misslingen'
            ? 0
            : 4,
      );
      expect(state.auftrag, isNull);
      if (fall != 'Dialogabbruch') {
        expect(bestand.anfragen.single.targets.single.value, 19);
      }
      if (fall == 'Misslingen') {
        expect(find.text('Meisterparade misslungen'), findsOneWidget);
        expect(find.textContaining('Folgemalus +3'), findsOneWidget);
        expect(find.textContaining('bis einschließlich'), findsOneWidget);
        await tester.tap(find.text('Am Tisch berücksichtigen'));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'Bonus bleibt über Runde und Hilfsaktion, AT verbraucht ihn ohne TP',
    (tester) async {
      final (container, bestand) = await _ansicht(tester, bonus: 0);
      await _oeffnen(tester, 'Meisterparade');
      await tester.enterText(
        find.byKey(const ValueKey('gefecht-meisterparade-ansage')),
        '3',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('gefecht-auftrag-starten')));
      await tester.pumpAndSettle();
      final ctl = container.read(gefechtProvider('rondra').notifier);
      ctl.setzen(
        naechsteGefechtsrunde(container.read(gefechtProvider('rondra'))!),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('gefecht-meisterparade-bonus')),
        findsOneWidget,
      );
      await _oeffnen(tester, 'Freie Aktion');
      await tester.tap(find.byKey(const ValueKey('gefecht-auftrag-starten')));
      await tester.pumpAndSettle();
      expect(container.read(gefechtProvider('rondra'))!.meisterparadeBonus, 3);
      await _oeffnen(tester, 'Angreifen');
      expect(find.textContaining('Zielwert 14'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('gefecht-auftrag-starten')));
      await tester.pumpAndSettle();
      final state = container.read(gefechtProvider('rondra'))!;
      expect(state.meisterparadeBonus, 0);
      expect(bestand.anfragen.last.targets.single.value, 14);
      expect(state.angriffsergebnisse.single.tpBonus, 0);
      ctl.beenden();
      ctl.beginnen(6);
      expect(container.read(gefechtProvider('rondra'))!.meisterparadeBonus, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Frische Ausführung nutzt aktuellen Bonus statt Dialogvorschau', (
    tester,
  ) async {
    final (container, bestand) = await _ansicht(tester);
    await _oeffnen(tester, 'Angreifen');
    expect(find.textContaining('Zielwert 15'), findsOneWidget);
    container
        .read(gefechtProvider('rondra').notifier)
        .setzen(
          container
              .read(gefechtProvider('rondra'))!
              .copyWith(meisterparadeBonus: 1),
        );
    await tester.tap(find.byKey(const ValueKey('gefecht-auftrag-starten')));
    await tester.pumpAndSettle();
    expect(bestand.anfragen.single.targets.single.value, 12);
    expect(container.read(gefechtProvider('rondra'))!.meisterparadeBonus, 0);
  });
  testWidgets('Mehrstellige Meisterparade-Eingabe hält Fokus und Cursor', (
    tester,
  ) async {
    await _ansicht(tester);
    await _oeffnen(tester, 'Meisterparade');
    final feld = find.byKey(const ValueKey('gefecht-meisterparade-ansage'));
    await tester.ensureVisible(feld);
    await tester.tap(feld);
    final editable = find.descendant(
      of: feld,
      matching: find.byType(EditableText),
    );
    final focus = tester.widget<EditableText>(editable).focusNode;
    for (final wert in ['1', '12']) {
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: wert,
          selection: TextSelection.collapsed(offset: wert.length),
        ),
      );
      await tester.pump();
      final aktuell = tester.widget<EditableText>(editable);
      expect(aktuell.focusNode, same(focus));
      expect(focus.hasFocus, true);
      expect(aktuell.controller.selection.baseOffset, wert.length);
      expect(aktuell.controller.text, wert);
    }
  });
  testWidgets(
    'Verkettete Meisterparaden ersetzen Bonus erst nach erfolgreicher Buchung',
    (tester) async {
      final (container, bestand) = await _ansicht(tester);
      final ctl = container.read(gefechtProvider('rondra').notifier);
      const mirakel = GefechtsProbenbonus('KL', 2);
      ctl.setzen(
        container
            .read(gefechtProvider('rondra'))!
            .copyWith(mirakelbonus: mirakel),
      );
      for (final ansage in [3, 2]) {
        await _oeffnen(tester, 'Meisterparade');
        await tester.enterText(
          find.byKey(const ValueKey('gefecht-meisterparade-ansage')),
          '$ansage',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('gefecht-auftrag-starten')));
        await tester.pumpAndSettle();
        final state = container.read(gefechtProvider('rondra'))!;
        expect(state.meisterparadeBonus, ansage);
        expect(state.mirakelbonus, same(mirakel));
        ctl.setzen(
          naechsteGefechtsrunde(state).copyWith(
            kontext: const Gefechtskontext(
              angriffsart: Gefechtsangriffsart.nahkampf,
              finte: 0,
              situationsZuschlag: 0,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }
      expect(bestand.anfragen.map((a) => a.targets.single.value), [19, 19]);
    },
  );
  testWidgets(
    'Eigenständiger DK-Auftrag verbraucht Bonus auch bei gegnerischer Abwehr ohne Schaden',
    (tester) async {
      final (container, bestand) = await _ansicht(tester);
      await _oeffnen(tester, 'Distanzklasse ändern');
      await tester.tap(find.byKey(const ValueKey('gefecht-auftrag-starten')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abgewehrt'));
      await tester.pumpAndSettle();
      final state = container.read(gefechtProvider('rondra'))!;
      expect(bestand.anfragen.single.targets.single.value, 15);
      expect(state.meisterparadeBonus, 0);
      expect(state.dk, 'N');
      expect(state.angriffsergebnisse.every((e) => e.tpBonus == 0), true);
      expect(
        find.byKey(const ValueKey('gefecht-angriffsschaden')),
        findsNothing,
      );
    },
  );
  for (final abbrechen in [true, false]) {
    testWidgets(
      'Manueller Angriff ${abbrechen ? 'abgebrochen' : 'bestätigt'} konsumiert Bonus erst mit Probe',
      (tester) async {
        final (container, bestand) = await _ansicht(tester);
        await _oeffnen(tester, 'Manuelle Sonderaktion');
        final einordnung = find.byKey(
          const ValueKey('gefecht-manuelle-kampfaktion'),
        );
        await tester.ensureVisible(einordnung);
        await tester.tap(einordnung);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Angriffsaktion').last);
        await tester.pumpAndSettle();
        expect(
          container.read(gefechtProvider('rondra'))!.meisterparadeBonus,
          4,
        );
        if (abbrechen) {
          await tester.tap(find.text('Abbrechen'));
        } else {
          final ziel = find.byWidgetPredicate(
            (w) =>
                w is TextField &&
                w.decoration?.labelText ==
                    'Manuell bestätigter Grundzielwert (optional)',
          );
          await tester.enterText(ziel, '12');
          await tester.pump();
          final entscheidung = find.byWidgetPredicate(
            (w) =>
                w is CheckboxListTile &&
                w.title is Text &&
                (w.title as Text).data ==
                    'Wirkung und Ressourcen dieser Sonderaktion festgelegt.',
          );
          await tester.ensureVisible(entscheidung);
          await tester.tap(entscheidung);
          await tester.pump();
          await tester.tap(
            find.byKey(const ValueKey('gefecht-auftrag-starten')),
          );
        }
        await tester.pumpAndSettle();
        expect(
          container.read(gefechtProvider('rondra'))!.meisterparadeBonus,
          abbrechen ? 4 : 0,
        );
        expect(bestand.anfragen.length, abbrechen ? 0 : 1);
        if (!abbrechen) {
          expect(bestand.anfragen.single.targets.single.value, 16);
        }
      },
    );
  }
}

// Echte Ansicht und Abschlussbrücke; nur Würfelergebnis/Callback steuerbar.
Future<(ProviderContainer, GefechtsTestBestand)> _ansicht(
  WidgetTester tester, {
  int bonus = 4,
  bool schild = false,
}) async {
  tester.view.physicalSize = const Size(1200, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final snap = mp.mpSnapshot(schild: schild);
  const katalog = RulesCatalog(
    version: 'test',
    source: 'test',
    talents: [],
    spells: [],
    weapons: [],
    maneuvers: [mp.meisterparade],
  );
  final container = ProviderContainer(
    overrides: [
      heroComputedProvider('rondra').overrideWith((ref) => AsyncData(snap)),
      rulesCatalogProvider.overrideWith((ref) async => katalog),
    ],
  );
  addTearDown(container.dispose);
  final ctl = container.read(gefechtProvider('rondra').notifier)..beginnen(6);
  ctl.setzen(
    container
        .read(gefechtProvider('rondra'))!
        .copyWith(
          dk: 'N',
          meisterparadeBonus: bonus,
          kontext: const Gefechtskontext(
            angriffsart: Gefechtsangriffsart.nahkampf,
            finte: 0,
            schildWmWirksam: true,
            situationsZuschlag: 0,
          ),
        ),
  );
  final bestand = GefechtsTestBestand()..w20Wert = 1;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: GefechtAnsicht(heroId: 'rondra', bestand: bestand),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (container, bestand);
}

// Sichtbares Bedienelement öffnen, auch nach gescrollten Formularen.
Future<void> _oeffnen(WidgetTester tester, String text) async {
  final entry = find.text(text).first;
  await tester.ensureVisible(entry);
  await tester.tap(entry);
  await tester.pumpAndSettle();
}
