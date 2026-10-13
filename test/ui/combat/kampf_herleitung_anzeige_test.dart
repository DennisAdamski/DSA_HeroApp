import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/kampf_herleitung_details.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview/herleitung_abschnitt.dart';

// Die Berechnungsschritte der Kampfvorschau zeigen die Herleitungen des
// Regelmoduls (ARCH-04, Teilstand 3). Vorher rechnete die Oberfläche selbst
// nach: Unter Axxeleratus fehlte im Ausweichen der PA-Anteil des Zaubers,
// und der Nebenhand fehlte die AT-Basis.

const _attribute = Attributes(
  mu: 14,
  kl: 12,
  inn: 13,
  ch: 11,
  ff: 10,
  ge: 12,
  ko: 14,
  kk: 13,
);

final _held = HeroSheet(
  id: 'demo',
  name: 'Rondra',
  level: 1,
  attributes: _attribute,
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

const _mitAxx = HeroState(
  currentLep: 20,
  currentAsp: 0,
  currentKap: 0,
  currentAu: 20,
  activeSpellEffects: ActiveSpellEffectsState(
    activeEffectIds: <String>[activeSpellEffectAxxeleratus],
  ),
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

// Betrag einer Schrittzeile, gefunden über Bezeichnung und Vorfahren.
Iterable<int> _betraege(WidgetTester tester, String bezeichnung) {
  return tester
      .widgetList<HerleitungsZeile>(
        find.byWidgetPredicate(
          (w) => w is HerleitungsZeile && w.bezeichnung == bezeichnung,
        ),
      )
      .map((zeile) => zeile.wert);
}

Future<void> _zeigeDetails(
  WidgetTester tester,
  CombatPreviewStats c, {
  String titel = 'Berechnungsschritte',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: KampfHerleitungDetails(preview: c)),
      ),
    ),
  );
  await tester.tap(find.text(titel));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Ausweichen zeigt unter Axxeleratus alle Anteile', (
    tester,
  ) async {
    final c = computeCombatPreviewStats(
      _held,
      _mitAxx,
      catalogTalents: _katalog.talents,
    );
    await _zeigeDetails(tester, c);

    // Axxeleratus hebt die PA-Basis in Parade und Ausweichen.
    expect(_betraege(tester, 'Axxeleratus PA'), <int>[2, 2]);
    expect(find.text('= ${c.ausweichen}'), findsWidgets);
    // Die angezeigten Schritte ergeben jeden angezeigten Wert.
    final h = c.herleitungen!;
    for (final herleitung in <Herleitung>[h.at, h.ausweichen, h.kampfIni]) {
      expect(summeDer(herleitung.sichtbareSchritte), herleitung.wert);
    }
    expect(find.text('Rüstungsschutz (RS)'), findsOneWidget);
  });

  testWidgets('Nebenhandwaffe zeigt AT-Basis und Schildarmwunde', (
    tester,
  ) async {
    final held = _held.copyWith(
      combatConfig: const CombatConfig().copyWith(
        weapons: const [
          MainWeaponSlot(id: 'w1', name: 'Schwert', talentId: 'tal_nah'),
          MainWeaponSlot(id: 'w2', name: 'Dolch', talentId: 'tal_nah'),
        ],
        selectedWeaponIndex: 0,
        offhandAssignment: const OffhandAssignment(weaponIndex: 1),
      ),
    );
    final c = computeCombatPreviewStats(
      held,
      _mitAxx,
      catalogTalents: _katalog.talents,
      wunden: const WundEffekte(schildarmAtPaMalus: -2),
    );
    await _zeigeDetails(tester, c, titel: 'Berechnungsschritte (Haupthand)');
    final nebenhand = find.text('Berechnungsschritte (Nebenhand)');
    await tester.ensureVisible(nebenhand);
    await tester.pumpAndSettle();
    await tester.tap(nebenhand);
    await tester.pumpAndSettle();

    final nh = c.offhandPreview!.herleitungen!;
    expect(find.text('= ${nh.at.wert}'), findsWidgets);
    expect(_betraege(tester, 'Wunden Schildarm'), <int>[-2, -2]);
    expect(_betraege(tester, 'AT-Basis').length, 2);
  });

  testWidgets('Schild-Parade erscheint mit Schild-WM und SF', (tester) async {
    final held = _held.copyWith(
      combatConfig: _held.combatConfig.copyWith(
        offhandAssignment: const OffhandAssignment(equipmentIndex: 0),
        offhandEquipment: const <OffhandEquipmentEntry>[
          OffhandEquipmentEntry(
            name: 'Holzschild',
            type: OffhandEquipmentType.shield,
            paMod: 3,
          ),
        ],
        specialRules: const CombatSpecialRules(schildkampfI: true),
      ),
    );
    final c = computeCombatPreviewStats(
      held,
      _mitAxx,
      catalogTalents: _katalog.talents,
    );
    await _zeigeDetails(tester, c, titel: 'Berechnungsschritte (Haupthand)');

    expect(find.text('Schild-Parade'), findsOneWidget);
    expect(find.text('= ${c.shieldPa}'), findsWidgets);
    expect(_betraege(tester, 'Schild-WM'), <int>[3]);
    expect(_betraege(tester, 'SF Schildkampf'), <int>[3]);
  });

  testWidgets('der Kampf-Tab öffnet die Herleitung der Vorschau', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeRepository(heroes: [_held], states: {'demo': _mitAxx});
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

    final details = find.byKey(
      const ValueKey<String>('combat-weapon-calculation-details'),
    );
    await tester.ensureVisible(details);
    await tester.tap(find.text('Berechnungsschritte'));
    await tester.pumpAndSettle();

    expect(_betraege(tester, 'Axxeleratus PA'), <int>[2, 2]);
  });
}
