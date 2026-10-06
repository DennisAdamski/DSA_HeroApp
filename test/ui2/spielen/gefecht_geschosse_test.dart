import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_fernkampf_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ladezustand_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_ansicht.dart';

import '../../rules/gefecht_laden_rules_test.dart' as fixture;
import '../shell/karto_test_support.dart';
import 'gefecht_test_support.dart';

// Wendet die echte Änderung auf den aktuellen Snapshot an.
class _Bestand extends GefechtsTestBestand {
  _Bestand(this.aktuell);
  HeroComputedSnapshot aktuell;
  late ProviderContainer container;
  @override
  Future<bool> gefechtsAusruestung({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required CombatConfig Function(CombatConfig) aenderung,
  }) async {
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

Future<ProviderContainer> _oeffnen(WidgetTester tester, _Bestand b) async {
  tester.view.physicalSize = const Size(1200, 1600);
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
  ctl.setzen(
    bestaetigeGefechtsLadung(
      c.read(gefechtProvider('rondra'))!,
      b.aktuell.hero.combatConfig.selectedWeapon,
      true,
    ),
  );
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

List<RangedProjectile> _geschosse(_Bestand b) =>
    b.aktuell.hero.combatConfig.selectedWeapon.rangedProfile.projectiles;

void main() {
  test('Aufheben zählt vom gespeicherten Bestand und verlangt eine Anzahl', () {
    final w = fixture.ladeSnapshot().hero.combatConfig.selectedWeapon;
    final config = fixture.ladeSnapshot().hero.combatConfig;
    final g = w.rangedProfile.projectiles[1];
    final neu = nimmGefechtsGeschosseAuf(config, w, g, 3, geschossIndex: 1);
    final p = neu.selectedWeapon.rangedProfile.projectiles;
    expect(p.map((e) => e.count), [5, 8]);
    expect(
      () => nimmGefechtsGeschosseAuf(config, w, g, 0, geschossIndex: 1),
      throwsArgumentError,
    );
  });

  test('Ladezustand überlebt eine reine Bestandsänderung', () {
    final snap = fixture.ladeSnapshot();
    final w = snap.hero.combatConfig.selectedWeapon;
    final s = bestaetigeGefechtsLadung(
      const Gefechtszustand(iniWurf: 6),
      w,
      true,
    );
    final mehr = nimmGefechtsGeschosseAuf(
      snap.hero.combatConfig,
      w,
      w.rangedProfile.projectiles[0],
      2,
      geschossIndex: 0,
    ).selectedWeapon;
    expect(gefechtsLadezustand(s, mehr), isNull);
    final uebertragen = uebertrageGefechtsLadestand(
      s,
      vorher: w,
      nachher: mehr,
    );
    expect(gefechtsLadezustand(uebertragen, mehr), isTrue);
    final anders = mehr.copyWith(
      rangedProfile: mehr.rangedProfile.copyWith(selectedProjectileIndex: 1),
    );
    expect(
      gefechtsLadezustand(
        uebertrageGefechtsLadestand(s, vorher: w, nachher: anders),
        anders,
      ),
      isNull,
    );
  });

  testWidgets('Gefecht zeigt Geschosse samt Anzahl und hebt mehrere auf', (
    t,
  ) async {
    final b = _Bestand(fixture.ladeSnapshot());
    final c = await _oeffnen(t, b);
    expect(find.text('Geschosse · Armbrust'), findsOneWidget);
    expect(find.text('Bolzen'), findsOneWidget);
    expect(find.text('Brandbolzen'), findsOneWidget);
    expect(find.text('5 Stück'), findsNWidgets(2));

    final knopf = find.byKey(const ValueKey('gefecht-geschoss-aufheben-a-1'));
    await t.ensureVisible(knopf);
    await t.tap(knopf);
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const ValueKey('gefecht-aufheben-anzahl')),
      '3',
    );
    await t.pumpAndSettle();
    expect(find.text('Danach 8 Stück.'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('gefecht-aufheben-bestaetigen')));
    await t.pumpAndSettle();

    expect(_geschosse(b).map((g) => g.count), [5, 8]);
    expect(find.text('8 Stück'), findsOneWidget);
    final s = c.read(gefechtProvider('rondra'))!;
    expect(s.auftrag, isNull);
    expect(
      gefechtsLadezustand(s, b.aktuell.hero.combatConfig.selectedWeapon),
      isTrue,
    );
  });

  testWidgets('Aktives Geschoss lässt sich im Gefecht wechseln', (t) async {
    final b = _Bestand(fixture.ladeSnapshot());
    await _oeffnen(t, b);
    final wahl = find.byTooltip('Brandbolzen verwenden');
    await t.ensureVisible(wahl);
    await t.tap(wahl);
    await t.pumpAndSettle();
    expect(
      b
          .aktuell
          .hero
          .combatConfig
          .selectedWeapon
          .rangedProfile
          .selectedProjectileIndex,
      1,
    );
    expect(find.byTooltip('Bolzen verwenden'), findsOneWidget);
  });
}
