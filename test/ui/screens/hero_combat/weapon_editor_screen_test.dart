import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/combat_rules.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/weapon_editor_screen.dart';

void main() {
  const combatTalents = <TalentDef>[
    TalentDef(
      id: 'tal_nah',
      name: 'Schwerter',
      group: 'Kampftalent',
      type: 'Nahkampf',
      weaponCategory: 'Kurzschwert',
      steigerung: 'D',
      attributes: <String>['Mut', 'Gewandtheit', 'Koerperkraft'],
    ),
    TalentDef(
      id: 'tal_fern',
      name: 'Boegen',
      group: 'Kampftalent',
      type: 'Fernkampf',
      weaponCategory: 'Kurzbogen',
      steigerung: 'D',
      attributes: <String>['Intuition', 'Fingerfertigkeit', 'Koerperkraft'],
    ),
  ];

  const catalogWeapons = <WeaponDef>[
    WeaponDef(
      id: 'wpn_kurzschwert',
      name: 'Kurzschwert',
      type: 'Nahkampf',
      combatSkill: 'Schwerter',
      tp: '1W6+2',
    ),
    WeaponDef(
      id: 'wpn_kurzbogen',
      name: 'Kurzbogen',
      type: 'Fernkampf',
      combatSkill: 'Boegen',
      tp: '1W6+4',
      reloadTime: 3,
      rangedDistanceBands: <RangedDistanceBand>[
        RangedDistanceBand(label: 'Nah', tpMod: 2),
        RangedDistanceBand(label: 'Mittel', tpMod: 0),
        RangedDistanceBand(label: 'Weit', tpMod: -1),
        RangedDistanceBand(label: 'Sehr weit', tpMod: -2),
        RangedDistanceBand(label: 'Extrem', tpMod: -4),
      ],
    ),
  ];

  HeroSheet buildHero() {
    return HeroSheet(
      id: 'demo',
      name: 'Rondra',
      level: 7,
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
    );
  }

  CombatPreviewStats previewFor(MainWeaponSlot slot) {
    return computeCombatPreviewStats(
      buildHero(),
      const HeroState(
        currentLep: 10,
        currentAsp: 0,
        currentKap: 0,
        currentAu: 10,
      ),
      overrideConfig: CombatConfig(
        weapons: <MainWeaponSlot>[slot],
        selectedWeaponIndex: 0,
      ),
      catalogTalents: combatTalents,
    );
  }

  Future<void> pumpEditor(
    WidgetTester tester, {
    MainWeaponSlot? initialWeapon,
    bool isNew = false,
    ValueChanged<MainWeaponSlot>? onSaved,
    VoidCallback? onCancel,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: WeaponEditorScreen(
              isNew: isNew,
              initialWeapon: initialWeapon,
              combatTalents: combatTalents,
              effectiveAttributes: buildHero().attributes,
              catalogWeapons: catalogWeapons,
              previewBuilder: previewFor,
              showAppBar: false,
              onSaved: onSaved,
              onCancel: onCancel,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectDropdownByKey(
    WidgetTester tester, {
    required String keyName,
    required String valueText,
  }) async {
    final dropdown = find.byKey(ValueKey<String>(keyName));
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(valueText).last);
    await tester.pumpAndSettle();
  }

  testWidgets('renders melee editor sections', (tester) async {
    await pumpEditor(
      tester,
      initialWeapon: const MainWeaponSlot(
        name: 'Kurzschwert',
        talentId: 'tal_nah',
        weaponType: 'Kurzschwert',
      ),
    );

    expect(find.text('Stammdaten'), findsOneWidget);
    expect(find.text('Schadensprofil'), findsOneWidget);
    expect(find.text('Modifikatoren'), findsOneWidget);
    expect(find.text('Vorschau'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('combat-weapon-form-reload-time')),
      findsNothing,
    );
  });

  testWidgets('shows validation error for empty name', (tester) async {
    await pumpEditor(tester, isNew: true, onSaved: (_) {});

    await tester.tap(
      find.byKey(const ValueKey<String>('combat-weapon-form-save')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Name ist erforderlich.'), findsOneWidget);
  });

  testWidgets('shows ranged section only for ranged setup', (tester) async {
    await pumpEditor(tester, isNew: true, onSaved: (_) {});

    expect(find.text('Fernkampf'), findsNothing);

    await selectDropdownByKey(
      tester,
      keyName: 'combat-weapon-form-combat-type',
      valueText: 'Fernkampf',
    );
    await selectDropdownByKey(
      tester,
      keyName: 'combat-weapon-form-weapon-type',
      valueText: 'Kurzbogen',
    );
    await selectDropdownByKey(
      tester,
      keyName: 'combat-weapon-form-talent',
      valueText: 'Boegen',
    );

    expect(
      find.byKey(const ValueKey<String>('combat-weapon-form-reload-time')),
      findsOneWidget,
    );
  });

  testWidgets('save returns normalized weapon slot', (tester) async {
    MainWeaponSlot? saved;
    await pumpEditor(
      tester,
      isNew: true,
      onSaved: (slot) {
        saved = slot;
      },
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('combat-weapon-form-name')),
      'Testschwert',
    );
    await tester.pumpAndSettle();
    await selectDropdownByKey(
      tester,
      keyName: 'combat-weapon-form-weapon-type',
      valueText: 'Kurzschwert',
    );
    await selectDropdownByKey(
      tester,
      keyName: 'combat-weapon-form-talent',
      valueText: 'Schwerter',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('combat-weapon-form-dice-count')),
      '2',
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('combat-weapon-form-tp-flat')),
      '4',
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('combat-weapon-form-save')),
    );
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.name, 'Testschwert');
    expect(saved!.weaponType, 'Kurzschwert');
    expect(saved!.talentId, 'tal_nah');
    expect(saved!.tpDiceCount, 2);
    expect(saved!.tpFlat, 4);
  });

  testWidgets('cancel with unsaved changes opens discard dialog', (
    tester,
  ) async {
    await pumpEditor(tester, isNew: true, onCancel: () {});

    await tester.enterText(
      find.byKey(const ValueKey<String>('combat-weapon-form-name')),
      'Entwurf',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ungespeicherte'), findsOneWidget);
  });
}
