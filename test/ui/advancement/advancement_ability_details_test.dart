import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/catalog_crypto.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_entry.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/config/adaptive_dialog.dart';
import 'package:dsa_heldenverwaltung/ui/screens/advancement/advancement_ability_details.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/protected_content_helpers.dart';

const _catalog = RulesCatalog(
  version: 'test',
  source: 'test',
  talents: [],
  spells: [],
  weapons: [],
  maneuvers: [ManeuverDef(id: 'man', name: 'Freies Manöver')],
);

void main() {
  // Der echte adaptive Dialog prüft zugleich lange Inhalte auf schmalen Geräten.
  Future<void> open(
    WidgetTester tester,
    SpecialAbilityEntry ability, {
    String? password,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [catalogContentPasswordProvider.overrideWithValue(password)],
        child: MaterialApp(
          home: Scaffold(
            body: AdaptiveInputDialog(
              actions: const [],
              title: ability.name,
              content: AdvancementAbilityDetails(
                ability: ability,
                catalog: _catalog,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('SF-Details zeigen Regeltext, Varianten und Quellen scrollbar', (
    tester,
  ) async {
    await open(
      tester,
      const SpecialAbilityDef(
        id: 'sf',
        name: 'Kenntnis',
        beschreibung: 'Kurze Beschreibung',
        erklarungLang: 'Der vollständige Regeltext.',
        voraussetzungen: 'Voraussetzung aus dem Regelwerk',
        verbreitung: 'Selten',
        quelle: 'Regelbuch',
        seite: '123',
        mehrfachwaehlbar: true,
        varianten: ['Wald', 'Wüste'],
        variantenGruppen: [
          SpecialAbilityVariantGroup(
            label: 'Vertiefung',
            ap: 75,
            varianten: ['Gebirge'],
          ),
        ],
        apErstwerb: 100,
        apFolgeerwerb: 50,
      ),
    );
    for (final text in [
      'Kurze Beschreibung',
      'Der vollständige Regeltext.',
      'Voraussetzung aus dem Regelwerk',
      'Selten',
      'Regelbuch',
      '123',
      'Wald\nWüste',
      'Vertiefung · 75 AP',
      'Gebirge',
      '100 AP',
      '50 AP',
    ]) {
      expect(find.text(text), findsOneWidget);
    }
    await tester.ensureVisible(find.text('50 AP'));
    await tester.pumpAndSettle();
    expect(find.text('50 AP').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kampf-SF zeigen Manövernamen und katalogisierte Boni', (
    tester,
  ) async {
    await open(
      tester,
      const CombatSpecialAbilityDef(
        id: 'kampf',
        name: 'Stil',
        aktiviertManoeverIds: ['man'],
        kampfwertBoni: [
          CombatSpecialAbilityBonusDef(
            giltFuerTalent: 'beide',
            atBonus: 1,
            paBonus: 2,
            iniMod: -1,
          ),
        ],
      ),
    );
    expect(find.text('Freies Manöver'), findsOneWidget);
    expect(find.text('Kampfwert-Boni · Raufen und Ringen'), findsOneWidget);
    expect(find.text('AT: 1 · PA: 2 · INI: -1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Geschützte Regeltexte benötigen das passende Passwort', (
    tester,
  ) async {
    final encrypted = encryptCatalogValue(
      'Geheimer Regeltext',
      'test-password',
    );
    final ability = SpecialAbilityDef(
      id: 'sf',
      name: 'Geheim',
      erklarungLang: encrypted,
    );
    await open(tester, ability);
    expect(find.text(lockedContentHint), findsOneWidget);
    expect(find.text(encrypted), findsNothing);
    expect(find.text('Geheimer Regeltext'), findsNothing);
    await open(tester, ability, password: 'test-password');
    expect(find.text('Geheimer Regeltext'), findsOneWidget);
    expect(find.text(lockedContentHint), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
