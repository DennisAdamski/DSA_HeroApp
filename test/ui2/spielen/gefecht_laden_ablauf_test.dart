import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_laden_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_ansicht.dart';

import '../../rules/gefecht_laden_rules_test.dart' as fixture;
import '../../rules/gefecht_laden_review_test.dart' as review;
import '../shell/karto_test_support.dart';
import 'gefecht_test_support.dart';

// Die echte Änderungsfunktion wird auf den aktuellen Snapshot angewendet.
class _Munition extends GefechtsTestBestand {
  _Munition(this.aktuell);
  HeroComputedSnapshot aktuell;
  late ProviderContainer container;
  int uebernahmen = 0;
  bool fehler = true;
  @override
  Future<bool> gefechtsAusruestung({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required CombatConfig Function(CombatConfig) aenderung,
  }) async {
    uebernahmen++;
    if (fehler) return false;
    final neu = aenderung(aktuell.hero.combatConfig);
    aktuell = buildHeroComputedSnapshot(
      hero: aktuell.hero.copyWith(combatConfig: neu),
      state: const HeroState.empty(),
      catalog: testCatalog,
      epicAdvantagesActive: false,
    );
    container.invalidate(heroComputedProvider(heroId));
    return true;
  }
}

Future<ProviderContainer> _oeffnen(
  WidgetTester tester,
  _Munition b, {
  bool geladen = false,
}) async {
  tester.view.physicalSize = const Size(1200, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final c = ProviderContainer(
    overrides: [
      heroComputedProvider('rondra')
          .overrideWith((ref) => AsyncData(b.aktuell)),
      rulesCatalogProvider.overrideWith((ref) async => testCatalog),
    ],
  );
  b.container = c;
  addTearDown(c.dispose);
  final ctl = c.read(gefechtProvider('rondra').notifier)..beginnen(6);
  var s = c
      .read(gefechtProvider('rondra'))!
      .copyWith(kontext: const Gefechtskontext(kontakt: 'Ork', entfernung: 5));
  if (geladen) {
    s = bestaetigeGefechtsLadung(
      s,
      b.aktuell.hero.combatConfig.selectedWeapon,
      true,
    );
  }
  ctl.setzen(s);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        home: GefechtAnsicht(heroId: 'rondra', bestand: b),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

void main() {
  testWidgets(
    'I1 BE-Wechsel während echter Ladezahlung erhält Fortschritt und RG-Abschluss',
    (t) async {
      final b = _Munition(review.reviewLadeSnapshot());
      final c = await _oeffnen(t, b);
      await t.tap(find.text('Laden / Vorbereiten · Armbrust'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('gefecht-laden-anfang')));
      await t.pumpAndSettle();
      await t.tap(find.text('Nicht geladen / nicht bereit').last);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('gefecht-laden-starten')));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Fortsetzen'));
      await t.tap(find.text('Fortsetzen'));
      await t.pumpAndSettle();
      expect(
        c
            .read(gefechtProvider('rondra'))!
            .handlung!
            .vorbereitung!
            .bezahlteAktionen,
        2,
      );
      b.aktuell = review.reviewLadeSnapshot(be: 5);
      c.invalidate(heroComputedProvider('rondra'));
      await t.pumpAndSettle();
      expect(find.text('2 bezahlt · aktuell 4 Aktionen'), findsOneWidget);
      final ctl = c.read(gefechtProvider('rondra').notifier);
      ctl.setzen(naechsteGefechtsrunde(c.read(gefechtProvider('rondra'))!));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Fortsetzen'));
      await t.tap(find.text('Fortsetzen'));
      await t.pumpAndSettle();
      final bezahlt = c.read(gefechtProvider('rondra'))!;
      expect(bezahlt.handlung!.vorbereitung!.bezahlteAktionen, 3);
      expect(
        gefechtsLadezustand(
          bezahlt,
          b.aktuell.hero.combatConfig.selectedWeapon,
        ),
        false,
      );
      b.aktuell = review.reviewLadeSnapshot(be: 5, training: 2);
      c.invalidate(heroComputedProvider('rondra'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Laden abschließen'));
      await t.tap(find.text('Laden abschließen'));
      await t.pumpAndSettle();
      final fertig = c.read(gefechtProvider('rondra'))!;
      expect(fertig.handlung, isNull);
      expect(fertig.angriffeVerbraucht, bezahlt.angriffeVerbraucht);
      expect(fertig.paradenVerbraucht, bezahlt.paradenVerbraucht);
      expect(
        gefechtsLadezustand(fertig, b.aktuell.hero.combatConfig.selectedWeapon),
        true,
      );
      expect(b.anfragen, isEmpty);
      expect(b.uebernahmen, 0);
      expect(t.takeException(), isNull);
    },
  );
  for (final abbrechen in [false, true]) {
    testWidgets(
      'I2 DK-Wechsel in Rundenleiste bleibt bei Schuss Abbruch=$abbrechen erhalten',
      (t) async {
        final b = _Munition(fixture.ladeSnapshot())
          ..abbrechen = abbrechen
          ..w20Wert = 1
          ..fehler = false;
        final c = await _oeffnen(t, b, geladen: true);
        final ctl = c.read(gefechtProvider('rondra').notifier);
        // Der Auftrag entsteht aus dem echten Aktionsdialog mit der alten DK S.
        ctl.setzen(c.read(gefechtProvider('rondra'))!.copyWith(dk: 'S'));
        await t.pumpAndSettle();
        await t.tap(find.text('Angreifen'));
        await t.pumpAndSettle();
        final ansage = find.byKey(const ValueKey('gefecht-fk-ansage'));
        await t.ensureVisible(ansage);
        await t.enterText(ansage, '5');
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('gefecht-auftrag-starten')));
        await t.pumpAndSettle();
        var s = c.read(gefechtProvider('rondra'))!;
        final original = s.handlung!.vorbereitung!.schussauftrag!;
        expect(original.dk, 'S');
        s = bezahleGefechtsVorbereitung(s, b.aktuell);
        s = bezahleGefechtsVorbereitung(naechsteGefechtsrunde(s), b.aktuell);
        ctl.setzen(naechsteGefechtsrunde(s));
        await t.pumpAndSettle();
        // Erreichbarer Live-DK-Wechsel während der vorbereiteten Handlung.
        expect(c.read(gefechtProvider('rondra'))!.dk, 'S');
        final dk = find.byType(DropdownButtonFormField<String>);
        await t.ensureVisible(dk);
        await t.tap(dk);
        await t.pumpAndSettle();
        await t.tap(find.text('Nahkampf').last);
        await t.pumpAndSettle();
        expect(c.read(gefechtProvider('rondra'))!.dk, 'N');
        await t.ensureVisible(find.text('Schuss ausführen'));
        await t.tap(find.text('Schuss ausführen'));
        await t.pumpAndSettle();
        final nachher = c.read(gefechtProvider('rondra'))!;
        expect(nachher.dk, 'N');
        expect(nachher.kontext.kontakt, 'Ork');
        expect(b.anfragen, hasLength(1));
        if (abbrechen) {
          expect(nachher.handlung!.vorbereitung!.schussauftrag, same(original));
          expect(nachher.zielstand!.bezahlteAktionen, 3);
          expect(nachher.angriffeVerbraucht, 0);
          expect(b.uebernahmen, 0);
        } else {
          expect(nachher.handlung, isNull);
          expect(nachher.angriffeVerbraucht, 1);
          expect(b.uebernahmen, 1);
        }
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'KG wandelt verbleibende PA nach Zielen spontan für vorbereiteten Schuss um',
    (t) async {
      final b = _Munition(fixture.ladeSnapshot(kampfgespuer: true))
        ..fehler = false
        ..w20Wert = 1;
      final c = await _oeffnen(t, b, geladen: true);
      final ctl = c.read(gefechtProvider('rondra').notifier);
      var s = beginneGefechtsZielen(
        c.read(gefechtProvider('rondra'))!,
        b.aktuell,
        testCatalog,
        fixture.zielauftrag,
      );
      s = bezahleGefechtsVorbereitung(s, b.aktuell);
      s = bezahleGefechtsVorbereitung(naechsteGefechtsrunde(s), b.aktuell);
      ctl.setzen(s);
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('2 AT'));
      await t.tap(find.text('2 AT'));
      await t.pumpAndSettle();
      expect(c.read(gefechtProvider('rondra'))!.angriffeVerbraucht, 1);
      await t.ensureVisible(find.text('Schuss ausführen'));
      await t.tap(find.text('Schuss ausführen'));
      await t.pumpAndSettle();
      expect(b.anfragen, hasLength(1));
      expect(
        b.anfragen.single.targets.single.value,
        b.aktuell.combatPreviewStats.at - 7,
      );
      expect(c.read(gefechtProvider('rondra'))!.angriffeVerbraucht, 2);
      expect(b.uebernahmen, 1);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'Abgebrochene Schussprobe erhält vollständig bezahlten Originalauftrag',
    (t) async {
      final b = _Munition(fixture.ladeSnapshot())..abbrechen = true;
      final c = await _oeffnen(t, b, geladen: true);
      final ctl = c.read(gefechtProvider('rondra').notifier);
      var s = beginneGefechtsZielen(
        c.read(gefechtProvider('rondra'))!,
        b.aktuell,
        testCatalog,
        fixture.zielauftrag,
      );
      s = bezahleGefechtsVorbereitung(s, b.aktuell);
      s = bezahleGefechtsVorbereitung(naechsteGefechtsrunde(s), b.aktuell);
      ctl.setzen(naechsteGefechtsrunde(s));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Schuss ausführen'));
      await t.tap(find.text('Schuss ausführen'));
      await t.pumpAndSettle();
      final erhalten = c.read(gefechtProvider('rondra'))!;
      expect(
        erhalten.handlung,
        isNotNull,
        reason: 'Abgebrochene Probe darf Originalauftrag nicht verlieren.',
      );
      expect(
        erhalten.handlung!.vorbereitung!.schussauftrag,
        same(fixture.zielauftrag),
      );
      expect(erhalten.zielstand!.bezahlteAktionen, 3);
      expect(erhalten.angriffeVerbraucht, 0);
      expect(b.uebernahmen, 0);
    },
  );
  testWidgets('Beenden prüft zwischenzeitlich offene Schussübernahme erneut', (
    t,
  ) async {
    final b = _Munition(fixture.ladeSnapshot());
    final c = await _oeffnen(t, b);
    await t.tap(find.text('Beenden'));
    await t.pumpAndSettle();
    final ctl = c.read(gefechtProvider('rondra').notifier);
    final laufend = c
        .read(gefechtProvider('rondra'))!
        .copyWith(
          handlung: const Gefechtshandlung(
            titel: 'Schuss · Munition übernehmen',
            verbleibend: 0,
            art: Gefechtshandlungsart.fernkampf,
          ),
        );
    ctl.setzen(laufend);
    await t.tap(find.widgetWithText(FilledButton, 'Beenden'));
    await t.pumpAndSettle();
    expect(
      c.read(gefechtProvider('rondra')),
      isNotNull,
      reason: 'Zwischenzeitlich offener Schuss darf beim Beenden nicht verloren gehen.',
    );
    expect(c.read(gefechtProvider('rondra'))!.handlung, same(laufend.handlung));
    expect(find.textContaining('zuerst abschließen'), findsWidgets);
  });
  testWidgets('Ladedialog erfragt Anfang und Handlung bezahlt über Runden', (
    t,
  ) async {
    final b = _Munition(fixture.ladeSnapshot());
    final c = await _oeffnen(t, b);
    await t.tap(find.text('Laden / Vorbereiten · Armbrust'));
    await t.pumpAndSettle();
    final start = find.byKey(const ValueKey('gefecht-laden-starten'));
    expect(t.widget<FilledButton>(start).onPressed, isNull);
    expect(find.textContaining('Anfänglichen Ladezustand'), findsWidgets);
    await t.tap(find.byKey(const ValueKey('gefecht-laden-anfang')));
    await t.pumpAndSettle();
    await t.tap(find.text('Nicht geladen / nicht bereit').last);
    await t.pumpAndSettle();
    await t.tap(start);
    await t.pumpAndSettle();
    expect(
      c
          .read(gefechtProvider('rondra'))!
          .handlung!
          .vorbereitung!
          .bezahlteAktionen,
      1,
    );
    final callback = t
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Fortsetzen'))
        .onPressed!;
    callback();
    callback();
    await t.pumpAndSettle();
    expect(
      c
          .read(gefechtProvider('rondra'))!
          .handlung!
          .vorbereitung!
          .bezahlteAktionen,
      2,
      reason: 'Doppelcallback derselben Aktion darf nur eine zweite Zahlung buchen.',
    );
    for (var i = 0; i < 2; i++) {
      if (i == 0) {
        final ctl = c.read(gefechtProvider('rondra').notifier);
        ctl.setzen(naechsteGefechtsrunde(c.read(gefechtProvider('rondra'))!));
        await t.pumpAndSettle();
      }
      final weiter = find.text('Fortsetzen');
      await t.ensureVisible(weiter);
      await t.tap(weiter);
      await t.pumpAndSettle();
    }
    expect(c.read(gefechtProvider('rondra'))!.handlung, isNull);
    expect(
      gefechtsLadezustand(
        c.read(gefechtProvider('rondra'))!,
        b.aktuell.hero.combatConfig.selectedWeapon,
      ),
      true,
    );
    expect(b.anfragen, isEmpty);
    expect(b.uebernahmen, 0);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'Zusatz-Zielen zahlt über Runden; Schussretry würfelt und verbraucht einmal',
    (t) async {
      final b = _Munition(fixture.ladeSnapshot())
        ..doppelt = true
        ..w20Wert = 1;
      final c = await _oeffnen(t, b, geladen: true);
      await t.tap(find.text('Angreifen'));
      await t.pumpAndSettle();
      final ansage = find.byKey(const ValueKey('gefecht-fk-ansage'));
      await t.ensureVisible(ansage);
      await t.enterText(ansage, '5');
      await t.pumpAndSettle();
      expect(find.text('Zusatz-Zielen beginnen'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('gefecht-auftrag-starten')));
      await t.pumpAndSettle();
      expect(b.anfragen, isEmpty);
      expect(c.read(gefechtProvider('rondra'))!.zielstand!.bezahlteAktionen, 1);
      await t.ensureVisible(find.text('Fortsetzen'));
      await t.tap(find.text('Fortsetzen'));
      await t.pumpAndSettle();
      final ctl = c.read(gefechtProvider('rondra').notifier);
      ctl.setzen(naechsteGefechtsrunde(c.read(gefechtProvider('rondra'))!));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Fortsetzen'));
      await t.tap(find.text('Fortsetzen'));
      await t.pumpAndSettle();
      expect(c.read(gefechtProvider('rondra'))!.zielstand!.bezahlteAktionen, 3);
      // Die dritte Zielaktion hat die AT dieser Runde bezahlt; Schuss braucht seine eigene Marke.
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Schuss ausführen'),
            )
            .onPressed,
        isNull,
      );
      ctl.setzen(naechsteGefechtsrunde(c.read(gefechtProvider('rondra'))!));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Schuss ausführen'));
      await t.tap(find.text('Schuss ausführen'));
      await t.pumpAndSettle();
      expect(b.anfragen, hasLength(1));
      expect(b.uebernahmen, 1);
      final offen = c.read(gefechtProvider('rondra'))!;
      expect(offen.handlung!.ergebnis, isNotNull);
      expect(offen.angriffsergebnisse, hasLength(1));
      expect(offen.zielstand, isNull);
      expect(offen.angriffeVerbraucht, 1);
      expect(offen.paradenVerbraucht, 0);
      expect(find.text('Handlung abbrechen'), findsNothing);
      b.fehler = false;
      final retry = find.text('Übernahme erneut versuchen');
      await t.ensureVisible(retry);
      await t.tap(retry);
      await t.pumpAndSettle();
      expect(b.anfragen, hasLength(1));
      expect(b.uebernahmen, 2);
      expect(
        b
            .aktuell
            .hero
            .combatConfig
            .selectedWeapon
            .rangedProfile
            .selectedProjectileOrNull!
            .count,
        4,
      );
      expect(c.read(gefechtProvider('rondra'))!.handlung, isNull);
      expect(
        gefechtsLadezustand(
          c.read(gefechtProvider('rondra'))!,
          b.aktuell.hero.combatConfig.selectedWeapon,
        ),
        false,
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Abbruch verwirft Zielzahlung und erstattet keine Marken', (
    t,
  ) async {
    final b = _Munition(fixture.ladeSnapshot());
    final c = await _oeffnen(t, b, geladen: true);
    final ctl = c.read(gefechtProvider('rondra').notifier);
    ctl.setzen(
      beginneGefechtsZielen(
        c.read(gefechtProvider('rondra'))!,
        b.aktuell,
        testCatalog,
        fixture.zielauftrag,
      ),
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Handlung abbrechen'));
    await t.tap(find.text('Handlung abbrechen'));
    await t.pumpAndSettle();
    await t.tap(find.text('Abbruch bestätigen'));
    await t.pumpAndSettle();
    final s = c.read(gefechtProvider('rondra'))!;
    expect(s.handlung, isNull);
    expect(s.zielstand, isNull);
    expect(s.angriffeVerbraucht, 1);
    expect(b.anfragen, isEmpty);
  });
}
