import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';
import 'package:dsa_heldenverwaltung/ui/widgets/flexible_table.dart';

import '../../test_support/bogen_test_repository.dart';

// Sofortänderungen im Kampf-Tab (ARCH-05): Jede Bedienung im Lesemodus
// arbeitet auf dem gespeicherten Helden. Ein anderer Schreibweg speichert
// nach dem Aufbau (`BogenTestRepository.fremdeAenderung`); seine Felder
// bleiben stehen, getroffen wird der angezeigte Slot, nicht seine Position.

const _pfeile = RangedProjectile(id: 'p1', name: 'Pfeile', count: 10);
const _schwert = MainWeaponSlot(
  id: 'w1',
  name: 'Schwert',
  talentId: 'tal_nah',
  weaponType: 'Schwert',
);
const _bogen = MainWeaponSlot(
  id: 'w2',
  name: 'Kurzbogen',
  talentId: 'tal_fern',
  combatType: WeaponCombatType.ranged,
  rangedProfile: RangedWeaponProfile(
    projectiles: [_pfeile],
    selectedProjectileIndex: 0,
  ),
);
const _dolch = MainWeaponSlot(id: 'w3', name: 'Dolch', talentId: 'tal_dolch');
const _axt = MainWeaponSlot(id: 'w4', name: 'Axt', talentId: 'tal_nah');

const _schild = OffhandEquipmentEntry(
  id: 'oh1',
  name: 'Holzschild',
  type: OffhandEquipmentType.shield,
);
const _buckler = OffhandEquipmentEntry(
  id: 'oh2',
  name: 'Buckler',
  type: OffhandEquipmentType.shield,
);
const _turmschild = OffhandEquipmentEntry(
  id: 'oh3',
  name: 'Turmschild',
  type: OffhandEquipmentType.shield,
);

const _helm = ArmorPiece(id: 'a1', name: 'Helm', rs: 1);
const _kette = ArmorPiece(id: 'a2', name: 'Kettenhemd', rs: 3, be: 2);

CombatConfig _kampf({
  List<MainWeaponSlot> waffen = const [_schwert, _bogen, _dolch],
  int gewaehlt = 1,
  OffhandAssignment nebenhand = const OffhandAssignment(),
  List<OffhandEquipmentEntry> teile = const [_schild, _buckler],
  List<ArmorPiece> ruestung = const [_helm, _kette],
}) {
  return const CombatConfig().copyWith(
    weapons: waffen,
    selectedWeaponIndex: gewaehlt,
    offhandEquipment: teile,
    offhandAssignment: nebenhand,
    armor: ArmorConfig(pieces: ruestung),
  );
}

HeroSheet _held([CombatConfig? kampf]) => HeroSheet(
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
  combatConfig: kampf ?? _kampf(),
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
    TalentDef(
      id: 'tal_fern',
      name: 'Boegen',
      group: 'Kampftalent',
      type: 'Fernkampf',
      weaponCategory: 'Bogen',
      steigerung: 'D',
      attributes: <String>['Intuition', 'Fingerfertigkeit', 'Koerperkraft'],
    ),
    TalentDef(
      id: 'tal_dolch',
      name: 'Dolche',
      group: 'Kampftalent',
      type: 'Nahkampf',
      weaponCategory: 'Dolch',
      steigerung: 'C',
      attributes: <String>['Mut', 'Gewandheit', 'Koerperkraft'],
    ),
  ],
  spells: <SpellDef>[],
  weapons: <WeaponDef>[],
);

void main() {
  late BogenTestRepository repo;

  Future<WorkspaceTabEditActions> zeige(
    WidgetTester tester, [
    CombatConfig? kampf,
  ]) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = BogenTestRepository(
      heroes: [_held(kampf)],
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

  // Scrollt die Liste des offenen Unterreiters, bis [ziel] gebaut ist.
  Future<void> bisSichtbar(WidgetTester tester, Finder ziel) async {
    for (var i = 0; i < 8 && ziel.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -280));
      await tester.pumpAndSettle();
    }
    expect(ziel, findsOneWidget);
  }

  Future<CombatConfig> gespeicherterKampf() async =>
      (await repo.gespeichert('demo')).combatConfig;

  List<String> namen(CombatConfig config) =>
      config.weaponSlots.map((slot) => slot.name).toList();

  final waffenwahl = find.byKey(
    const ValueKey<String>('combat-main-weapon-select-1-3'),
  );
  final nebenhandwahl = find.byKey(
    const ValueKey<String>('combat-offhand-selection'),
  );

  group('Kampfwerte', () {
    testWidgets('Waffenwahl trifft die angezeigte Waffe', (tester) async {
      await zeige(tester);
      // Inzwischen gespeichert: neuer Name, eine Axt vor allen Waffen.
      repo.fremdeAenderung = (held) => held.copyWith(
        name: 'Rondra die Kühne',
        combatConfig: _kampf(waffen: const [_axt, _schwert, _bogen, _dolch]),
      );

      tester.widget<DropdownButtonFormField<int?>>(waffenwahl).onChanged!(2);
      await tester.pumpAndSettle();

      final gespeichert = await repo.gespeichert('demo');
      expect(gespeichert.name, 'Rondra die Kühne');
      expect(namen(gespeichert.combatConfig), [
        'Axt',
        'Schwert',
        'Kurzbogen',
        'Dolch',
      ]);
      expect(gespeichert.combatConfig.selectedWeapon.name, 'Dolch');
    });

    testWidgets('drei schnelle Klicks auf „Geschosse +“ zählen dreimal', (
      tester,
    ) async {
      await zeige(tester);
      // Inzwischen gespeichert: 20 statt der angezeigten 10 Pfeile.
      repo.fremdeAenderung = (held) => held.copyWith(
        combatConfig: _kampf(
          waffen: [
            _schwert,
            _bogen.copyWith(
              rangedProfile: _bogen.rangedProfile.copyWith(
                projectiles: [_pfeile.copyWith(count: 20)],
              ),
            ),
            _dolch,
          ],
        ),
      );
      final plus = find.byKey(
        const ValueKey<String>(
          'combat-active-weapon-projectile-count-increment',
        ),
      );
      await bisSichtbar(tester, plus);

      final knopf = tester.widget<IconButton>(plus);
      for (var i = 0; i < 3; i++) {
        knopf.onPressed!();
      }
      await tester.pumpAndSettle();

      final kampf = await gespeicherterKampf();
      final bogen = kampf.weaponSlots.firstWhere((slot) => slot.id == 'w2');
      expect(bogen.rangedProfile.projectiles.single.count, 23);
    });

    testWidgets('Nebenhandwahl trifft das angezeigte Teil', (tester) async {
      await zeige(tester);
      repo.fremdeAenderung = (held) => held.copyWith(
        combatConfig: _kampf(teile: const [_turmschild, _schild, _buckler]),
      );
      await bisSichtbar(tester, nebenhandwahl);

      tester.widget<DropdownButtonFormField<String>>(nebenhandwahl).onChanged!(
        'equipment:1',
      );
      await tester.pumpAndSettle();

      final kampf = await gespeicherterKampf();
      expect(kampf.offhandEquipment.map((teil) => teil.name), [
        'Turmschild',
        'Holzschild',
        'Buckler',
      ]);
      final index = kampf.offhandAssignment.equipmentIndex;
      expect(kampf.offhandEquipment[index].name, 'Buckler');
    });

    testWidgets('ein Speicherfehler wird gemeldet, die Auswahl springt '
        'zurück', (tester) async {
      await zeige(tester);
      repo.schreibFehler = true;

      await tester.tap(waffenwahl);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dolch').last);
      await tester.pumpAndSettle();

      expect(
        find.text('Waffenwahl nicht gespeichert: Speicher voll'),
        findsOneWidget,
      );
      expect(
        find.descendant(of: waffenwahl, matching: find.text('Kurzbogen')),
        findsOneWidget,
      );
      expect((await gespeicherterKampf()).selectedWeapon.name, 'Kurzbogen');
    });

    testWidgets('im Bearbeitungsmodus wird erst mit Speichern geschrieben', (
      tester,
    ) async {
      final aktionen = await zeige(tester);
      await aktionen.startEdit();
      await tester.pumpAndSettle();

      tester.widget<DropdownButtonFormField<int?>>(waffenwahl).onChanged!(2);
      await tester.pumpAndSettle();
      expect(repo.bogenSpeicherungen, 0);

      await aktionen.save();
      await tester.pumpAndSettle();
      expect(repo.bogenSpeicherungen, 1);
      expect((await gespeicherterKampf()).selectedWeapon.name, 'Dolch');
    });
  });

  group('Waffen', () {
    testWidgets('Entfernen trifft die angezeigte Waffe, die Nebenhand bleibt', (
      tester,
    ) async {
      // Aktiv: Schwert, Nebenhand: Dolch.
      await zeige(
        tester,
        _kampf(gewaehlt: 0, nebenhand: const OffhandAssignment(weaponIndex: 2)),
      );
      await reiter(tester, 'Waffen');
      repo.fremdeAenderung = (held) => held.copyWith(name: 'Rondra die Kühne');

      final entfernen = find.byKey(
        const ValueKey<String>('combat-weapon-remove-1'),
      );
      tester.widget<IconButton>(entfernen).onPressed!();
      await tester.pumpAndSettle();

      final gespeichert = await repo.gespeichert('demo');
      final kampf = gespeichert.combatConfig;
      expect(gespeichert.name, 'Rondra die Kühne');
      expect(namen(kampf), ['Schwert', 'Dolch']);
      expect(kampf.selectedWeapon.name, 'Schwert');
      expect(
        kampf.weaponSlots[kampf.offhandAssignment.weaponIndex].name,
        'Dolch',
      );
    });

    testWidgets('BF in der Tabelle trifft die angezeigte Waffe', (
      tester,
    ) async {
      await zeige(tester);
      await reiter(tester, 'Waffen');
      repo.fremdeAenderung = (held) => held.copyWith(
        combatConfig: _kampf(waffen: const [_axt, _schwert, _bogen, _dolch]),
      );

      // Die aktive Waffe (Kurzbogen) steht in der Tabelle oben, Index 1.
      final bf = find.byKey(const ValueKey<String>('combat-weapon-cell-bf-0'));
      tester.widget<FlexibleTableCommitField>(bf).onCommit('5');
      await tester.pumpAndSettle();

      final kampf = await gespeicherterKampf();
      expect(kampf.weaponSlots.map((slot) => slot.breakFactor), [0, 5, 0, 0]);
    });

    testWidgets('ein Editorergebnis auf eine inzwischen geänderte Waffe wird '
        'abgewiesen', (tester) async {
      await zeige(tester);
      await reiter(tester, 'Waffen');
      await tester.tap(find.text('Schwert').first);
      await tester.pumpAndSettle();
      // Während der Editor offen ist, ändert ein anderer Weg das Schwert.
      repo.fremdeAenderung = (held) => held.copyWith(
        combatConfig: _kampf(
          waffen: [_schwert.copyWith(breakFactor: 3), _bogen, _dolch],
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('combat-weapon-form-save')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Waffe nicht gespeichert: Die Waffe wurde inzwischen geändert.',
        ),
        findsOneWidget,
      );
      expect(repo.bogenSpeicherungen, 0);
    });
  });

  group('Rüstung & Verteidigung', () {
    testWidgets('Entfernen trifft das angezeigte Rüstungsteil', (tester) async {
      await zeige(tester);
      await reiter(tester, 'Rüstung & Verteidigung');
      // Inzwischen gespeichert: umsortiert und um Armschienen ergänzt.
      repo.fremdeAenderung = (held) => held.copyWith(
        combatConfig: _kampf(
          ruestung: const [
            _kette,
            _helm,
            ArmorPiece(id: 'a3', name: 'Armschienen', rs: 1),
          ],
        ),
      );

      final entfernen = find.byKey(
        const ValueKey<String>('combat-armor-remove-0'),
      );
      tester.widget<IconButton>(entfernen).onPressed!();
      await tester.pumpAndSettle();

      final kampf = await gespeicherterKampf();
      expect(kampf.armor.pieces.map((teil) => teil.name), [
        'Kettenhemd',
        'Armschienen',
      ]);
    });

    testWidgets('Entfernen eines Nebenhandteils lässt die Zuordnung '
        'nachrücken', (tester) async {
      await zeige(
        tester,
        _kampf(nebenhand: const OffhandAssignment(equipmentIndex: 1)),
      );
      await reiter(tester, 'Rüstung & Verteidigung');
      final entfernen = find.byKey(
        const ValueKey<String>('combat-offhand-remove-0'),
      );
      await bisSichtbar(tester, entfernen);

      tester.widget<IconButton>(entfernen).onPressed!();
      await tester.pumpAndSettle();

      final kampf = await gespeicherterKampf();
      expect(kampf.offhandEquipment.map((teil) => teil.name), ['Buckler']);
      expect(kampf.offhandAssignment.equipmentIndex, 0);
    });
  });
}
