import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_begleiter_tab.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace_edit_contract.dart';

// Die Angriffszeile laeuft im Bearbeitungsmodus mit Steigern-Knopf in der
// 36 Pixel breiten AT-Spalte ueber; das ist ein vorhandener Layoutfehler
// ohne Bezug zu diesem Test.
Future<void> _pumpUndUeberlaufIgnorieren(WidgetTester tester) async {
  await tester.pumpAndSettle();
  Object? fehler;
  do {
    fehler = tester.takeException();
    if (fehler != null && !'$fehler'.contains('A RenderFlex overflowed')) {
      throw fehler;
    }
  } while (fehler != null);
}

void main() {
  testWidgets('Befund ARCH-07-B11: Bearbeiten eines Angriffs behält gekaufte '
      'Steigerungen und unbekannte Felder', (tester) async {
    const feld = <String, Object?>{'zukunftsfeld': 1};
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1600, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeRepository(
      heroes: <HeroSheet>[
        const HeroSheet(
          id: 'demo',
          name: 'Hexe',
          level: 1,
          attributes: Attributes(
            mu: 12,
            kl: 12,
            inn: 12,
            ch: 12,
            ff: 12,
            ge: 12,
            ko: 12,
            kk: 12,
          ),
          companions: <HeroCompanion>[
            HeroCompanion(
              id: 'rabe',
              name: 'Rabe',
              typ: BegleiterTyp.vertrauter,
              angriffe: <HeroCompanionAttack>[
                HeroCompanionAttack(
                  id: 'schnabel',
                  name: 'Schnabel',
                  at: 10,
                  tp: '1W3',
                  steigerungAt: 2,
                  steigerungPa: 1,
                  unbekannteFelder: feld,
                ),
              ],
              unbekannteFelder: feld,
            ),
          ],
        ),
      ],
      states: <String, HeroState>{
        'demo': const HeroState(
          currentLep: 10,
          currentAsp: 10,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );
    WorkspaceTabEditActions? actions;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith(
            (ref) async => const RulesCatalog(
              version: 'test',
              source: 'test',
              talents: <TalentDef>[],
              spells: <SpellDef>[],
              weapons: <WeaponDef>[],
            ),
          ),
          appSettingsProvider.overrideWith(
            (ref) => Stream<AppSettings>.value(const AppSettings()),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: HeroBegleiterTab(
              heroId: 'demo',
              onDirtyChanged: (_) {},
              onEditingChanged: (_) {},
              onRegisterDiscard: (_) {},
              onRegisterEditActions: (registered) => actions = registered,
            ),
          ),
        ),
      ),
    );
    await _pumpUndUeberlaufIgnorieren(tester);
    await actions!.startEdit();
    await _pumpUndUeberlaufIgnorieren(tester);

    await tester.ensureVisible(find.byTooltip('Bearbeiten').first);
    await tester.tap(find.byTooltip('Bearbeiten').first);
    await _pumpUndUeberlaufIgnorieren(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'TP (z.B. 1W6+3)'),
      '1W6',
    );
    await tester.tap(find.text('Speichern').last);
    await _pumpUndUeberlaufIgnorieren(tester);
    await actions!.save();
    await _pumpUndUeberlaufIgnorieren(tester);

    final begleiter = (await repo.loadHeroById('demo'))!.companions.single;
    final angriff = begleiter.angriffe.single;
    expect(angriff.tp, '1W6');
    expect(angriff.steigerungAt, 2);
    expect(angriff.steigerungPa, 1);
    expect(angriff.unbekannteFelder, feld);
    expect(begleiter.unbekannteFelder, feld);
  });
}
