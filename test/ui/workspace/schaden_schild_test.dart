import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/spell_effect_instance.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/schaden/schaden_dialog.dart';

import '../../test_support/real_catalog.dart';

const _held = HeroSheet(
  id: 'demo',
  name: 'Rondra',
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
);

HeroState _zustand({List<SpellEffectInstance> schilde = const []}) {
  return const HeroState(
    currentLep: 30,
    currentAsp: 0,
    currentKap: 0,
    currentAu: 20,
  ).copyWith(
    activeSpellEffects: const ActiveSpellEffectsState().copyWith(
      instanzen: schilde,
    ),
  );
}

Finder _key(String schluessel) => find.byKey(ValueKey<String>(schluessel));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<FakeRepository> zeigePanel(
    WidgetTester tester,
    HeroState zustand,
  ) async {
    final katalog = await tester.runAsync(ladeEchtenRegelkatalog);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeRepository(heroes: [_held], states: {'demo': zustand});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          ...katalog!.overrides,
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SchadenPanel(heroId: 'demo', onUebernommen: (_) {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  const schild = SpellEffectInstance(
    id: 'schild',
    effectId: 'spell_gardianum_zauberschild',
    zfpStern: 4,
    amount: 14,
  );

  testWidgets('ohne Zauberschild gibt es keinen Auffangknopf', (tester) async {
    await zeigePanel(tester, _zustand());

    expect(_key('schaden-schild-schild'), findsNothing);
  });

  testWidgets('ein unterdrückter Zauberschild wird nicht angeboten', (
    tester,
  ) async {
    await zeigePanel(
      tester,
      _zustand(schilde: [schild.copyWith(unterdrueckt: true)]),
    );

    expect(_key('schaden-schild-schild'), findsNothing);
  });

  testWidgets('der Durchschlag ersetzt die TP des Schadensdialogs', (
    tester,
  ) async {
    final repo = await zeigePanel(tester, _zustand(schilde: [schild]));

    await tester.enterText(_key('schaden-tp'), '20');
    await tester.pump();
    await tester.tap(_key('schaden-schild-schild'));
    await tester.pumpAndSettle();
    // Die TP des Panels sind im Auffangdialog vorbelegt.
    expect(
      tester.widget<TextField>(_key('schild-auffang-tp')).controller!.text,
      '20',
    );
    await tester.tap(_key('schild-auffang-bestaetigen'));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(_key('schaden-tp')).controller!.text, '6');
    final gespeichert = (await repo.loadHeroState('demo'))!
        .activeSpellEffects
        .instanzen
        .single;
    expect(gespeichert.schutzRest, 0);
    // Der Schild ist aufgezehrt und wird nicht mehr angeboten.
    expect(_key('schaden-schild-schild'), findsNothing);
  });

  testWidgets('ein kleiner Treffer bleibt ganz im Schild', (tester) async {
    final repo = await zeigePanel(tester, _zustand(schilde: [schild]));

    await tester.tap(_key('schaden-schild-schild'));
    await tester.pumpAndSettle();
    await tester.enterText(_key('schild-auffang-tp'), '5');
    await tester.pumpAndSettle();
    await tester.tap(_key('schild-auffang-bestaetigen'));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(_key('schaden-tp')).controller!.text, '0');
    final gespeichert = (await repo.loadHeroState('demo'))!
        .activeSpellEffects
        .instanzen
        .single;
    expect(gespeichert.schutzRest, 9);
    expect(_key('schaden-schild-schild'), findsOneWidget);
  });

  testWidgets('Abbrechen des Auffangdialogs ändert nichts', (tester) async {
    final repo = await zeigePanel(tester, _zustand(schilde: [schild]));

    await tester.tap(_key('schaden-schild-schild'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    final gespeichert = (await repo.loadHeroState('demo'))!
        .activeSpellEffects
        .instanzen
        .single;
    expect(gespeichert.schutzRest, isNull);
  });
}
