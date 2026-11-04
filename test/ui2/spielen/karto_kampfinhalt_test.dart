import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_hand_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_kampfmittel_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_kachelgroesse.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_kampfinhalt.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_theme.dart';

import '../../rules/gefecht_laden_rules_test.dart' as fixture;

/// Das Panel „Kampfwerte“ der weiten Kampf-Kachel (SPIEL-07) ordnet nur
/// Felder der Kampfvorschau an; die Erwartungen werden daher aus derselben
/// Vorschau abgeleitet und nicht fest einkodiert.
void main() {
  const attribute = Attributes(
    mu: 12,
    kl: 12,
    inn: 12,
    ch: 12,
    ff: 12,
    ge: 12,
    ko: 12,
    kk: 12,
  );
  const schwert = MainWeaponSlot(name: 'Schwert', kkBase: 12, kkThreshold: 3);
  const schild = OffhandEquipmentEntry(
    name: 'Holzschild',
    type: OffhandEquipmentType.shield,
    paMod: 3,
  );
  const mitSchild = CombatConfig(
    mainWeapon: schwert,
    offhandAssignment: OffhandAssignment(equipmentIndex: 0),
    offhandEquipment: <OffhandEquipmentEntry>[schild],
  );

  HeroComputedSnapshot rechne(
    CombatConfig config, [
    Map<WundZone, int> wunden = const <WundZone, int>{},
  ]) {
    return buildHeroComputedSnapshot(
      hero: HeroSheet(
        id: 'h',
        name: 'Test',
        level: 1,
        attributes: attribute,
        combatConfig: config,
      ),
      state: HeroState(
        currentLep: 20,
        currentAsp: 0,
        currentKap: 0,
        currentAu: 20,
        wpiZustand: WundZustand(wundenProZone: wunden),
      ),
      catalog: null,
      epicAdvantagesActive: false,
    );
  }

  Future<void> zeige(
    WidgetTester tester,
    HeroComputedSnapshot werte, {
    KartoKachelGroesse? groesse = KartoKachelGroesse.weit,
    double breite = 760,
    double skalierung = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(breite, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final inhalt = KartoKampfInhalt(proben: const Text('Proben'), werte: werte);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildKartoTheme(
          brightness: Brightness.light,
          centerAppBarTitle: false,
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(skalierung)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: groesse == null
                ? inhalt
                : KartoKachelSteuerung(
                    kennung: 'kampf',
                    groesse: groesse,
                    child: inhalt,
                  ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder k(String schluessel) => find.byKey(ValueKey<String>(schluessel));
  String text(WidgetTester tester, String schluessel) =>
      tester.widget<Text>(k(schluessel)).data!;

  group('Größenstufen', () {
    testWidgets('weit: Probenchips und Panel stehen nebeneinander', (
      tester,
    ) async {
      await zeige(tester, rechne(mitSchild));
      expect(find.text('Proben'), findsOneWidget);
      expect(k('karto-kampf-werte'), findsOneWidget);
      final proben = tester.getRect(find.text('Proben'));
      final panel = tester.getRect(k('karto-kampf-werte'));
      expect(panel.left, greaterThan(proben.right));
    });

    for (final groesse in [
      KartoKachelGroesse.kompakt,
      KartoKachelGroesse.normal,
    ]) {
      testWidgets('${groesse.name}: nur die Probenchips', (tester) async {
        await zeige(tester, rechne(mitSchild), groesse: groesse);
        expect(find.text('Proben'), findsOneWidget);
        expect(k('karto-kampf-werte'), findsNothing);
      });
    }

    testWidgets('außerhalb einer Kachel bleibt es bei den Probenchips', (
      tester,
    ) async {
      await zeige(tester, rechne(mitSchild), groesse: null);
      expect(find.text('Proben'), findsOneWidget);
      expect(k('karto-kampf-werte'), findsNothing);
    });
  });

  group('Werte aus der Kampfvorschau', () {
    testWidgets('INI, TP, RS und BE stammen aus der Vorschau', (tester) async {
      final werte = rechne(mitSchild);
      final c = werte.combatPreviewStats;
      await zeige(tester, werte);
      expect(
        text(tester, 'karto-kampf-ini'),
        '${c.kampfInitiative} + ${c.initiativeDiceSpec.label}',
      );
      expect(
        text(tester, 'karto-kampf-tp'),
        gefechtsAngriffsanzeige(werte)!.tp,
      );
      expect(text(tester, 'karto-kampf-tp'), c.tpExpression);
      expect(text(tester, 'karto-kampf-rs'), '${c.rsTotal}');
      expect(text(tester, 'karto-kampf-be'), '${c.beKampf}');
    });

    testWidgets('die Kopfzeile nennt die belegten Hände', (tester) async {
      final werte = rechne(mitSchild);
      await zeige(tester, werte);
      expect(
        text(tester, 'karto-kampf-haende'),
        gefechtsHandbelegung(werte.hero.combatConfig),
      );
      expect(text(tester, 'karto-kampf-haende'), contains('Schwert'));
      expect(text(tester, 'karto-kampf-haende'), contains('Holzschild'));
    });

    testWidgets('Nahkampf zeigt weder Ladezeit noch Geschoss noch Entfernung', (
      tester,
    ) async {
      await zeige(tester, rechne(mitSchild));
      expect(k('karto-kampf-ladezeit'), findsNothing);
      expect(k('karto-kampf-geschoss'), findsNothing);
      expect(k('karto-kampf-entfernung'), findsNothing);
    });

    testWidgets('Fernkampf zeigt Ladezeit, Geschoss und Entfernung', (
      tester,
    ) async {
      final werte = fixture.ladeSnapshot();
      final c = werte.combatPreviewStats;
      expect(c.isRangedWeapon, isTrue);
      await zeige(tester, werte);
      expect(k('karto-kampf-werte'), findsOneWidget);
      if (c.reloadTimeDisplay.isNotEmpty) {
        expect(
          tester
              .widget<Text>(k('karto-kampf-ladezeit'))
              .textSpan!
              .toPlainText(),
          contains(c.reloadTimeDisplay),
        );
      }
      expect(
        tester.widget<Text>(k('karto-kampf-geschoss')).textSpan!.toPlainText(),
        contains(c.activeProjectileName),
      );
      expect(c.activeProjectileName, 'Bolzen');
      if (c.activeDistanceLabel.isNotEmpty) {
        expect(
          tester
              .widget<Text>(k('karto-kampf-entfernung'))
              .textSpan!
              .toPlainText(),
          contains(c.activeDistanceLabel),
        );
      }
    });
  });

  group('Hinweise', () {
    testWidgets('ohne Wunden und Waffenmeister gibt es keine Hinweiszeilen', (
      tester,
    ) async {
      await zeige(tester, rechne(mitSchild));
      expect(k('karto-kampf-wundabzug-schwertarm'), findsNothing);
      expect(k('karto-kampf-wundabzug-schildarm'), findsNothing);
      expect(k('karto-kampf-waffenmeister'), findsNothing);
    });

    testWidgets('Schwertarmwunde nennt den Abzug mit echtem Minuszeichen', (
      tester,
    ) async {
      final werte = rechne(mitSchild, const {WundZone.rechterArm: 1});
      expect(werte.combatPreviewStats.schwertarmWundMalus, -2);
      await zeige(tester, werte);
      expect(
        text(tester, 'karto-kampf-wundabzug-schwertarm'),
        'Schwertarm: −2 auf AT und PA',
      );
      expect(k('karto-kampf-wundabzug-schildarm'), findsNothing);
    });

    testWidgets('Schildarmwunde nennt den Abzug für Schild und Nebenhand', (
      tester,
    ) async {
      final werte = rechne(mitSchild, const {WundZone.linkerArm: 1});
      expect(werte.combatPreviewStats.schildarmWundMalus, -2);
      await zeige(tester, werte);
      expect(
        text(tester, 'karto-kampf-wundabzug-schildarm'),
        'Schildarm: −2 auf Schild und Nebenhand',
      );
      expect(k('karto-kampf-wundabzug-schwertarm'), findsNothing);
    });
  });

  group('Platz', () {
    final faelle = <String, HeroComputedSnapshot>{
      'Nahkampf mit Schild': rechne(mitSchild),
      'Nahkampf mit zwei Wunden': rechne(mitSchild, const {
        WundZone.rechterArm: 1,
        WundZone.linkerArm: 1,
      }),
      'Fernkampf': fixture.ladeSnapshot(),
    };
    for (final MapEntry(key: name, value: werte) in faelle.entries) {
      for (final breite in [600.0, 760.0, 1100.0]) {
        for (final skalierung in [1.0, 2.0]) {
          testWidgets('$name bei $breite dp, Schrift $skalierung, ohne '
              'Überlauf', (tester) async {
            await zeige(tester, werte, breite: breite, skalierung: skalierung);
            expect(tester.takeException(), isNull);
            expect(k('karto-kampf-werte'), findsOneWidget);
          });
        }
      }
    }
  });
}
