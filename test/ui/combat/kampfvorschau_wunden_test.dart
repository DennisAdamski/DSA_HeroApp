import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/codex_metric_tile.dart';

// Die Vorschau des Kampf-Tabs rechnet mit denselben Eingaben wie Inspector
// und Spielansicht (`heroComputedProvider`), Wunden eingeschlossen. Bisher
// fehlten sie in AT, PA und INI (Folgeauftrag 1 aus ARCH-05 Teilstand 6).

final _held = HeroSheet(
  id: 'demo',
  name: 'Rondra',
  level: 1,
  attributes: const Attributes(
    mu: 14,
    kl: 12,
    inn: 13,
    ch: 11,
    ff: 10,
    ge: 12,
    ko: 14,
    kk: 13,
  ),
  talents: const {
    'tal_nah': HeroTalentEntry(talentValue: 7, atValue: 4, paValue: 3),
  },
  combatConfig: const CombatConfig().copyWith(
    weapons: const [
      MainWeaponSlot(
        id: 'w1',
        name: 'Schwert',
        talentId: 'tal_nah',
        weaponType: 'Schwert',
      ),
    ],
    selectedWeaponIndex: 0,
  ),
);

const _ohneWunde = HeroState(
  currentLep: 20,
  currentAsp: 0,
  currentKap: 0,
  currentAu: 20,
);

final _mitBauchwunde = _ohneWunde.copyWith(
  wpiZustand: const WundZustand(wundenProZone: {WundZone.bauch: 1}),
);

const _katalog = RulesCatalog(
  version: 'test',
  source: 'test',
  talents: <TalentDef>[
    TalentDef(
      id: 'tal_nah',
      name: 'Schwerter',
      group: 'Kampftalent',
      type: 'Nahkampf',
      weaponCategory: 'Schwert',
      steigerung: 'D',
      attributes: <String>['Mut', 'Gewandheit', 'Koerperkraft'],
    ),
  ],
  spells: <SpellDef>[],
  weapons: <WeaponDef>[],
);

CombatPreviewStats _erwartet(HeroState zustand) {
  return buildHeroComputedSnapshot(
    hero: _held,
    state: zustand,
    catalog: _katalog,
    epicAdvantagesActive: true,
  ).combatPreviewStats;
}

void main() {
  Future<void> zeige(WidgetTester tester, HeroState zustand) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeRepository(heroes: [_held], states: {'demo': zustand});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => _katalog),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: HeroCombatTab(
              heroId: 'demo',
              onDirtyChanged: (_) {},
              onEditingChanged: (_) {},
              onRegisterDiscard: (_) {},
              onRegisterEditActions: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String kachel(WidgetTester tester, String label) {
    return tester
        .widgetList<CodexMetricTile>(find.byType(CodexMetricTile))
        .firstWhere((tile) => tile.label == label)
        .value;
  }

  test('die Bauchwunde senkt AT, PA und INI im Snapshot', () {
    final ohne = _erwartet(_ohneWunde);
    final mit = _erwartet(_mitBauchwunde);
    expect(mit.at, lessThan(ohne.at));
    expect(mit.paMitIniParadeMod, lessThan(ohne.paMitIniParadeMod));
    expect(
      mit.kombinierteHeldenWaffenIni,
      lessThan(ohne.kombinierteHeldenWaffenIni),
    );
  });

  testWidgets('Kampfwerte zeigen AT, PA und INI samt Wunde', (tester) async {
    await zeige(tester, _mitBauchwunde);
    final erwartet = _erwartet(_mitBauchwunde);

    expect(kachel(tester, 'AT'), '${erwartet.at}');
    expect(kachel(tester, 'PA'), '${erwartet.paMitIniParadeMod}');
    expect(kachel(tester, 'Kampf-INI'), '${erwartet.kampfInitiative}');
  });

  testWidgets('die Waffentabelle rechnet dieselbe INI samt Wunde', (
    tester,
  ) async {
    await zeige(tester, _mitBauchwunde);
    await tester.tap(find.widgetWithText(Tab, 'Waffen'));
    await tester.pumpAndSettle();

    final ini = tester.widget<Text>(
      find.byKey(const ValueKey<String>('combat-weapon-cell-ini-0')),
    );
    expect(ini.data, '${_erwartet(_mitBauchwunde).kombinierteHeldenWaffenIni}');
  });
}
