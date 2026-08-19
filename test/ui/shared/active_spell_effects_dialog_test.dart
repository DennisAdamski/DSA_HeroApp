import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/active_spell_effects_dialog.dart';

void main() {
  HeroSheet buildHero() {
    return HeroSheet(
      id: 'demo',
      name: 'Testheld',
      level: 5,
      attributes: const Attributes(
        mu: 12,
        kl: 12,
        inn: 12,
        ch: 12,
        ff: 12,
        ge: 12,
        ko: 12,
        kk: 12,
      ),
      talents: const <String, HeroTalentEntry>{},
      combatConfig: const CombatConfig(),
      vorteileText: '',
      nachteileText: '',
    );
  }

  /// Oeffnet den Dialog fuer aktive Zaubereffekte auf einem leeren Screen.
  Future<FakeRepository> openDialog(
    WidgetTester tester, {
    HeroState? initialState,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = FakeRepository(
      heroes: <HeroSheet>[buildHero()],
      states: <String, HeroState>{
        'demo':
            initialState ??
            const HeroState(
              currentLep: 30,
              currentAsp: 30,
              currentKap: 0,
              currentAu: 20,
            ),
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [heroRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showActiveSpellEffectsDialog(context: context, heroId: 'demo'),
                child: const Text('öffnen'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('öffnen'));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('Armatrutz erscheint als aktivierbarer Zaubereffekt', (
    tester,
  ) async {
    await openDialog(tester);

    expect(
      find.byKey(const ValueKey<String>('active-spell-effects-dialog')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('active-spell-toggle-effect_spell_armatrutz'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Armatrutz speichert RS und Wirkungsdauer beim Aktivieren', (
    tester,
  ) async {
    final repo = await openDialog(tester);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('active-spell-toggle-effect_spell_armatrutz'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('armatrutz-input-rs')),
      '3',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('armatrutz-duration-amount')),
      '2',
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('armatrutz-input-confirm')),
    );
    await tester.pumpAndSettle();

    final state = await repo.loadHeroState('demo');
    expect(state!.activeSpellEffects.isActive(activeSpellEffectArmatrutz), isTrue);
    final detail = state.activeSpellEffects.detailFor(activeSpellEffectArmatrutz);
    expect(detail.amount, 3);
    expect(detail.duration?.amount, 2);
    expect(detail.duration?.remaining, 2);
    expect(detail.duration?.unit, SpellDurationUnit.spielrunden);
  });

  testWidgets('Der Kostenhinweis folgt der Eingabe von RS und ZfP*', (
    tester,
  ) async {
    await openDialog(tester);

    await tester.tap(
      find.byKey(
        const ValueKey<String>('active-spell-toggle-effect_spell_armatrutz'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('armatrutz-input-rs')),
      '5',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('armatrutz-input-zfp')),
      '6',
    );
    await tester.pumpAndSettle();

    final hint = tester.widget<Text>(
      find.byKey(const ValueKey<String>('armatrutz-input-cost-hint')),
    );
    expect(hint.data, contains('22 AsP'));
  });

  testWidgets('Die Restlaufzeit laesst sich herunterzaehlen', (tester) async {
    final effects = const ActiveSpellEffectsState()
        .withToggled(activeSpellEffectArmatrutz, true)
        .withDetail(
          activeSpellEffectArmatrutz,
          ActiveSpellEffectDetail(
            amount: 3,
            duration: SpellDuration(
              amount: 4,
              unit: SpellDurationUnit.kampfrunden,
            ),
          ),
        );
    final repo = await openDialog(
      tester,
      initialState: const HeroState(
        currentLep: 30,
        currentAsp: 30,
        currentKap: 0,
        currentAu: 20,
      ).copyWith(activeSpellEffects: effects),
    );

    expect(
      find.text('noch 4 von 4 Kampfrunden'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>(
          'active-spell-duration-advance-effect_spell_armatrutz',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = await repo.loadHeroState('demo');
    final duration = state!.activeSpellEffects
        .detailFor(activeSpellEffectArmatrutz)
        .duration;
    expect(duration?.remaining, 3);
    expect(find.text('noch 3 von 4 Kampfrunden'), findsOneWidget);
  });

  testWidgets('Abgelaufener Armatrutz zeigt den Ablauf an', (tester) async {
    final effects = const ActiveSpellEffectsState()
        .withToggled(activeSpellEffectArmatrutz, true)
        .withDetail(
          activeSpellEffectArmatrutz,
          ActiveSpellEffectDetail(
            amount: 3,
            duration: SpellDuration(
              amount: 2,
              remaining: 0,
              unit: SpellDurationUnit.spielrunden,
            ),
          ),
        );
    await openDialog(
      tester,
      initialState: const HeroState(
        currentLep: 30,
        currentAsp: 30,
        currentKap: 0,
        currentAu: 20,
      ).copyWith(activeSpellEffects: effects),
    );

    expect(find.text('abgelaufen (2 Spielrunden)'), findsOneWidget);
  });
}
