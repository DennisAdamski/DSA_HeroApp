import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

import '../../test_support/bogen_test_repository.dart';

// Entfernen im Kampfbereich fragt „Nur ablegen“ oder „Ganz entfernen“
// (ARCH-03, Entscheidung vom 06.10.2026). Abgelegt bleibt das Exemplar mit
// seinen Angaben und Kampfwerten im Inventar.

const _schwert = MainWeaponSlot(
  id: 'w1',
  name: 'Schwert',
  talentId: 'tal_nah',
  weaponType: 'Schwert',
  tpFlat: 4,
  inventarInstanzId: 'i-schwert',
);
const _dolch = MainWeaponSlot(
  id: 'w2',
  name: 'Dolch',
  talentId: 'tal_nah',
  inventarInstanzId: 'i-dolch',
);
const _helm = ArmorPiece(
  id: 'a1',
  name: 'Helm',
  rs: 1,
  inventarInstanzId: 'i-helm',
);

const _held = HeroSheet(
  id: 'demo',
  name: 'Rondra',
  level: 1,
  attributes: Attributes(
    mu: 14,
    kl: 12,
    inn: 13,
    ch: 11,
    ff: 10,
    ge: 12,
    ko: 14,
    kk: 13,
  ),
  combatConfig: CombatConfig(
    weapons: [_schwert, _dolch],
    armor: ArmorConfig(pieces: [_helm]),
  ),
  inventoryEntries: [
    HeroInventoryEntry(
      gegenstand: 'Schwert',
      itemType: InventoryItemType.ausruestung,
      source: InventoryItemSource.waffe,
      sourceRef: 'w:Schwert',
      slotRef: 'w#w1',
      istAusgeruestet: true,
      instanzId: 'i-schwert',
      beschreibung: 'Erbstück',
    ),
    HeroInventoryEntry(
      gegenstand: 'Dolch',
      itemType: InventoryItemType.ausruestung,
      source: InventoryItemSource.waffe,
      sourceRef: 'w:Dolch',
      slotRef: 'w#w2',
      istAusgeruestet: true,
      instanzId: 'i-dolch',
    ),
    HeroInventoryEntry(
      gegenstand: 'Helm',
      itemType: InventoryItemType.ausruestung,
      source: InventoryItemSource.ruestung,
      sourceRef: 'a:Helm',
      slotRef: 'a#a1',
      instanzId: 'i-helm',
      gewichtGramm: 800,
    ),
  ],
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

void main() {
  late BogenTestRepository repo;

  Future<WorkspaceTabEditActions> zeige(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = BogenTestRepository(
      heroes: [_held],
      states: {
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 0,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );
    WorkspaceTabEditActions? aktionen;
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
              onRegisterEditActions: (registriert) {
                aktionen = registriert;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return aktionen!;
  }

  Future<void> reiter(WidgetTester tester, String titel) async {
    await tester.tap(find.widgetWithText(Tab, titel));
    await tester.pumpAndSettle();
  }

  Future<void> entferne(WidgetTester tester, String key, String antwort) async {
    tester.widget<IconButton>(find.byKey(ValueKey<String>(key))).onPressed!();
    await tester.pumpAndSettle();
    await tester.tap(find.text(antwort));
    await tester.pumpAndSettle();
  }

  HeroInventoryEntry eintrag(HeroSheet held, String instanzId) =>
      held.inventoryEntries.singleWhere((e) => e.instanzId == instanzId);

  testWidgets('„Nur ablegen“ behält die Waffe im Inventar', (tester) async {
    await zeige(tester);
    await reiter(tester, 'Waffen');

    await entferne(tester, 'combat-weapon-remove-0', 'Nur ablegen');

    final gespeichert = await repo.gespeichert('demo');
    expect(gespeichert.combatConfig.weaponSlots.map((w) => w.name), ['Dolch']);
    final schwert = eintrag(gespeichert, 'i-schwert');
    expect(schwert.beschreibung, 'Erbstück');
    expect(schwert.sourceRef, isNull);
    expect(schwert.abgelegt!.waffe!.tpFlat, 4);
  });

  testWidgets('auch die letzte Waffe lässt sich ablegen', (tester) async {
    await zeige(tester);
    await reiter(tester, 'Waffen');

    await entferne(tester, 'combat-weapon-remove-1', 'Ganz entfernen');
    await entferne(tester, 'combat-weapon-remove-0', 'Nur ablegen');

    final gespeichert = await repo.gespeichert('demo');
    expect(gespeichert.combatConfig.weapons, isEmpty);
    expect(eintrag(gespeichert, 'i-schwert').abgelegt, isNotNull);
  });

  testWidgets('Abbrechen ändert nichts', (tester) async {
    await zeige(tester);
    await reiter(tester, 'Waffen');

    await entferne(tester, 'combat-weapon-remove-0', 'Abbrechen');

    expect(repo.bogenSpeicherungen, 0);
  });

  testWidgets('im Bearbeitungsmodus legt Speichern das Rüstungsteil ab', (
    tester,
  ) async {
    final aktionen = await zeige(tester);
    await aktionen.startEdit();
    await tester.pumpAndSettle();
    await reiter(tester, 'Rüstung & Verteidigung');

    await entferne(tester, 'combat-armor-remove-0', 'Nur ablegen');
    expect(repo.bogenSpeicherungen, 0);
    await aktionen.save();
    await tester.pumpAndSettle();

    final gespeichert = await repo.gespeichert('demo');
    expect(gespeichert.combatConfig.armor.pieces, isEmpty);
    final helm = eintrag(gespeichert, 'i-helm');
    expect(helm.gewichtGramm, 800);
    expect(helm.abgelegt!.ruestungsteil!.rs, 1);
  });
}
