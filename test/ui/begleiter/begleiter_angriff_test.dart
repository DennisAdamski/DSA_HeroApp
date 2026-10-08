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
                  dk: 'H',
                  at: 10,
                  pa: 5,
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
    await tester.pumpAndSettle();

    await actions!.startEdit();
    await tester.pumpAndSettle();
    expect(find.byTooltip('AT steigern'), findsOneWidget);
    expect(find.byTooltip('PA steigern'), findsOneWidget);

    // Überschriften müssen auch mit Steigerungsbuttons dieselben Spalten
    // wie die Werte belegen; sonst rutscht AT optisch unter DK.
    for (final (label, value) in [('DK', 'H'), ('AT', '10'), ('PA', '5')]) {
      final header = find
          .ancestor(of: find.text(label), matching: find.byType(SizedBox))
          .first;
      final cell = find
          .ancestor(of: find.text(value), matching: find.byType(SizedBox))
          .first;
      expect(
        tester.getRect(cell).center.dx,
        closeTo(tester.getRect(header).center.dx, 0.1),
        reason: '$label muss unter seiner Überschrift stehen',
      );
    }
    expect(
      tester.getTopLeft(find.text('1W3')).dx,
      closeTo(tester.getTopLeft(find.text('TP')).dx, 0.1),
    );
    await tester.ensureVisible(find.byTooltip('Bearbeiten').first);
    await tester.tap(find.byTooltip('Bearbeiten').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'TP (z.B. 1W6+3)'),
      '1W6',
    );
    await tester.tap(find.text('Speichern').last);
    await tester.pumpAndSettle();
    await actions!.save();
    await tester.pumpAndSettle();

    final begleiter = (await repo.loadHeroById('demo'))!.companions.single;
    final angriff = begleiter.angriffe.single;
    expect(angriff.tp, '1W6');
    expect(angriff.steigerungAt, 2);
    expect(angriff.steigerungPa, 1);
    expect(angriff.unbekannteFelder, feld);
    expect(begleiter.unbekannteFelder, feld);
  });
}
