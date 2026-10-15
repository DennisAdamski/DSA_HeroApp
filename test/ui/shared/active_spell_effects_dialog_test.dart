import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';
import 'package:dsa_heldenverwaltung/domain/spell_effect_instance.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/test_support/fake_repository.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/active_spell_effects_dialog.dart';

import '../../test_support/real_catalog.dart';

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
    List<Override> overrides = const <Override>[],
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
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          ...overrides,
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showActiveSpellEffectsDialog(
                  context: context,
                  heroId: 'demo',
                ),
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
    expect(
      state!.activeSpellEffects.isActive(activeSpellEffectArmatrutz),
      isTrue,
    );
    final detail = state.activeSpellEffects.detailFor(
      activeSpellEffectArmatrutz,
    );
    expect(detail.amount, 3);
    expect(detail.duration?.amount, 2);
    expect(detail.duration?.remaining, 2);
    expect(detail.duration?.unit, SpellDurationUnit.spielrunden);
  });

  testWidgets('Bearbeiten und Abschalten erhalten Felder einer neueren '
      'App-Version', (tester) async {
    const feld = <String, Object?>{'zukunftsfeld': 1};
    final effects = const ActiveSpellEffectsState(unbekannteFelder: feld)
        .withToggled(activeSpellEffectArmatrutz, true)
        .withToggled(activeSpellEffectAttributo, true)
        .withDetail(
          activeSpellEffectArmatrutz,
          ActiveSpellEffectDetail(
            amount: 3,
            duration: SpellDuration(
              amount: 4,
              unit: SpellDurationUnit.spielrunden,
              unbekannteFelder: feld,
            ),
            unbekannteFelder: feld,
          ),
        );
    final repo = await openDialog(
      tester,
      initialState: const HeroState(
        currentLep: 30,
        currentAsp: 30,
        currentKap: 0,
        currentAu: 20,
        tempAttributeMods: AttributeModifiers(kk: 2, unbekannteFelder: feld),
      ).copyWith(activeSpellEffects: effects),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>(
          'active-spell-edit-value-effect_spell_armatrutz',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('armatrutz-input-rs')),
      '5',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('armatrutz-duration-amount')),
      '6',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('armatrutz-input-confirm')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey<String>('active-spell-toggle-effect_spell_attributo'),
      ),
    );
    await tester.pumpAndSettle();
    // Die Herkunft der gespeicherten Boni ist nicht erkennbar: Rückfrage.
    await tester.tap(
      find.byKey(const ValueKey<String>('attributo-boni-entfernen')),
    );
    await tester.pumpAndSettle();

    final state = (await repo.loadHeroState('demo'))!;
    final detail = state.activeSpellEffects.detailFor(
      activeSpellEffectArmatrutz,
    );
    expect(detail.amount, 5);
    expect(detail.duration?.amount, 6);
    expect(detail.unbekannteFelder, feld);
    expect(detail.duration?.unbekannteFelder, feld);
    expect(state.activeSpellEffects.unbekannteFelder, feld);
    expect(
      state.activeSpellEffects.isActive(activeSpellEffectAttributo),
      isFalse,
    );
    expect(state.tempAttributeMods.kk, 0);
    expect(state.tempAttributeMods.unbekannteFelder, feld);
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

    expect(find.text('noch 4 von 4 Kampfrunden'), findsOneWidget);

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

  testWidgets('Attributo aus: Boni behalten bleibt auf Wunsch stehen', (
    tester,
  ) async {
    final repo = await openDialog(
      tester,
      initialState:
          const HeroState(
            currentLep: 30,
            currentAsp: 30,
            currentKap: 0,
            currentAu: 20,
            tempAttributeMods: AttributeModifiers(mu: 2),
          ).copyWith(
            activeSpellEffects: const ActiveSpellEffectsState().withToggled(
              activeSpellEffectAttributo,
              true,
            ),
          ),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('active-spell-toggle-effect_spell_attributo'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('attributo-boni-behalten')),
    );
    await tester.pumpAndSettle();

    final state = (await repo.loadHeroState('demo'))!;
    expect(
      state.activeSpellEffects.isActive(activeSpellEffectAttributo),
      isFalse,
    );
    expect(state.tempAttributeMods.mu, 2);
  });

  testWidgets(
    'Weitere Attributo-Quelle lässt sich anlegen und einzeln beenden',
    (tester) async {
      final repo = await openDialog(
        tester,
        initialState: const HeroState(
          currentLep: 30,
          currentAsp: 30,
          currentKap: 0,
          currentAu: 20,
          tempAttributeMods: AttributeModifiers(ge: 4),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('spell-instance-attributo-hinzu')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('attributo-input-MU')),
        '3',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('attributo-input-confirm')),
      );
      await tester.pumpAndSettle();

      var state = (await repo.loadHeroState('demo'))!;
      expect(state.activeSpellEffects.instanzen, hasLength(1));
      expect(state.activeSpellEffects.instanzen.single.attributeMods.mu, 3);
      final id = state.activeSpellEffects.instanzen.single.id;

      await tester.tap(
        find.byKey(ValueKey<String>('spell-instance-beenden-$id')),
      );
      await tester.pumpAndSettle();

      state = (await repo.loadHeroState('demo'))!;
      expect(state.activeSpellEffects.instanzen, isEmpty);
      // Manuelle Boni bleiben vom Ende der Quelle unberührt.
      expect(state.tempAttributeMods.ge, 4);
    },
  );

  testWidgets('Blitz lässt sich als Quelle anlegen und zeigt Hinweis, Ende', (
    tester,
  ) async {
    final katalog = await tester.runAsync(ladeEchtenRegelkatalog);
    final repo = await openDialog(tester, overrides: katalog!.overrides);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('spell-instance-zauber-hinzu')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('spell-effect-input-zauber')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blitz dich find').last);
    await tester.pumpAndSettle();
    // Ohne ZfP* ist „Hinzufügen“ gesperrt.
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey<String>('spell-effect-input-confirm')),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('spell-effect-input-zfp')),
      '5',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('spell-effect-input-zfw')),
      '12',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('spell-effect-input-quelle')),
      'Alrik',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('spell-effect-input-confirm')),
    );
    await tester.pumpAndSettle();

    var state = (await repo.loadHeroState('demo'))!;
    final instanz = state.activeSpellEffects.instanzen.single;
    expect(instanz.effectId, 'spell_blitz_dich_find');
    expect(instanz.zfpStern, 5);
    expect(instanz.zfw, 12);
    expect(instanz.quelle, 'Alrik');
    expect(
      find.byKey(const ValueKey<String>('spell-effect-orientieren-hinweis')),
      findsOneWidget,
    );
    expect(find.textContaining('ZfP* 5, ZfW 12'), findsOneWidget);

    await tester.tap(
      find.byKey(ValueKey<String>('spell-instance-beenden-${instanz.id}')),
    );
    await tester.pumpAndSettle();

    state = (await repo.loadHeroState('demo'))!;
    expect(state.activeSpellEffects.instanzen, isEmpty);
    expect(
      find.byKey(const ValueKey<String>('spell-effect-orientieren-hinweis')),
      findsNothing,
    );
  });

  testWidgets('Falkenauge braucht ein Ziel und schlägt ZfW Kampfrunden vor', (
    tester,
  ) async {
    final katalog = await tester.runAsync(ladeEchtenRegelkatalog);
    final repo = await openDialog(tester, overrides: katalog!.overrides);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('spell-instance-zauber-hinzu')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('spell-effect-input-zauber')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Falkenauge Meisterschuss').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('spell-effect-input-zfp')),
      '5',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('spell-effect-input-zfw')),
      '9',
    );
    await tester.pumpAndSettle();
    // Ohne Ziel bleibt „Hinzufügen“ gesperrt.
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey<String>('spell-effect-input-confirm')),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('spell-effect-input-ziel')),
      'Ork',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('spell-effect-input-confirm')),
    );
    await tester.pumpAndSettle();

    final instanz = (await repo.loadHeroState('demo'))!
        .activeSpellEffects
        .instanzen
        .single;
    expect(instanz.effectId, 'spell_falkenauge_meisterschuss');
    expect(instanz.ziel, 'Ork');
    expect(instanz.duration?.amount, 9);
    expect(instanz.duration?.unit, SpellDurationUnit.kampfrunden);
    expect(find.textContaining('Ziel: Ork'), findsOneWidget);
  });

  testWidgets('Ängste lindern: Einsetzen verbraucht erst nach der Auswertung', (
    tester,
  ) async {
    final katalog = await tester.runAsync(ladeEchtenRegelkatalog);
    final repo = await openDialog(
      tester,
      overrides: katalog!.overrides,
      initialState:
          const HeroState(
            currentLep: 30,
            currentAsp: 30,
            currentKap: 0,
            currentAu: 20,
          ).copyWith(
            activeSpellEffects: const ActiveSpellEffectsState().copyWith(
              instanzen: const [
                SpellEffectInstance(
                  id: 'angst',
                  effectId: 'spell_aengste_lindern',
                  zfpStern: 6,
                ),
              ],
            ),
          ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('spell-instance-einsetzen-angst')),
    );
    await tester.pumpAndSettle();
    // Probe offen, Startwert +6; Dialog schließen ohne Auswertung.
    expect(find.text('Eigenschaftsprobe: MU'), findsWidgets);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    var state = (await repo.loadHeroState('demo'))!;
    expect(state.activeSpellEffects.instanzen, hasLength(1));

    await tester.tap(
      find.byKey(const ValueKey<String>('spell-instance-einsetzen-angst')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manuell'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('probe-dialog-die-0')),
      '7',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Auswerten'));
    await tester.pumpAndSettle();

    state = (await repo.loadHeroState('demo'))!;
    expect(state.activeSpellEffects.instanzen, isEmpty);
  });

  Future<void> waehleZauber(WidgetTester tester, String name) async {
    await tester.tap(
      find.byKey(const ValueKey<String>('spell-instance-zauber-hinzu')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('spell-effect-input-zauber')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  HeroState schildZustand({int rest = 14, bool unterdrueckt = false}) {
    return const HeroState(
      currentLep: 30,
      currentAsp: 30,
      currentKap: 0,
      currentAu: 20,
    ).copyWith(
      activeSpellEffects: const ActiveSpellEffectsState().copyWith(
        instanzen: [
          SpellEffectInstance(
            id: 'schild',
            effectId: 'spell_gardianum_zauberschild',
            zfpStern: 4,
            amount: 14,
            schutzRest: rest == 14 ? null : rest,
            unterdrueckt: unterdrueckt,
          ),
        ],
      ),
    );
  }

  testWidgets('Gardianum: Vorrat folgt Variante, AsP und ZfP*', (tester) async {
    final katalog = await tester.runAsync(ladeEchtenRegelkatalog);
    final repo = await openDialog(tester, overrides: katalog!.overrides);
    await tester.pumpAndSettle();

    await waehleZauber(tester, 'Gardianum Zauberschild');
    await tester.enterText(
      find.byKey(const ValueKey<String>('spell-effect-input-zfp')),
      '5',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('spell-effect-input-zfw')),
      '12',
    );
    // Unter 3 AsP gibt es keinen belegten Vorrat.
    await tester.enterText(
      find.byKey(const ValueKey<String>('spell-effect-input-asp')),
      '2',
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey<String>('spell-effect-input-confirm')),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('spell-effect-input-asp')),
      '6',
    );
    await tester.pumpAndSettle();
    expect(find.text('Schutzvorrat: 16 TP'), findsOneWidget);

    await tester.tap(find.text('Persönlicher Schild'));
    await tester.pumpAndSettle();
    expect(find.text('Schutzvorrat: 21 TP'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('spell-effect-input-confirm')),
    );
    await tester.pumpAndSettle();

    final instanz = (await repo.loadHeroState('demo'))!
        .activeSpellEffects
        .instanzen
        .single;
    expect(instanz.effectId, 'spell_gardianum_zauberschild');
    expect(instanz.amount, 21);
    expect(instanz.schutzRest, isNull);
    expect(instanz.duration?.unit, SpellDurationUnit.spielrunden);
    expect(find.textContaining('Schutz 21 / 21 TP'), findsOneWidget);
  });

  testWidgets('Gardianum: ZfW unter 11 warnt beim persönlichen Schild nur', (
    tester,
  ) async {
    final katalog = await tester.runAsync(ladeEchtenRegelkatalog);
    await openDialog(tester, overrides: katalog!.overrides);
    await tester.pumpAndSettle();

    await waehleZauber(tester, 'Gardianum Zauberschild');
    await tester.enterText(
      find.byKey(const ValueKey<String>('spell-effect-input-zfw')),
      '9',
    );
    await tester.tap(find.text('Persönlicher Schild'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey<String>('spell-effect-input-varianten-hinweis'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'Gardianum fängt einen Treffer auf und bietet den Durchschlag an',
    (tester) async {
      final katalog = await tester.runAsync(ladeEchtenRegelkatalog);
      final repo = await openDialog(
        tester,
        overrides: katalog!.overrides,
        initialState: schildZustand(),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('spell-instance-einsetzen-schild')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Schutzvorrat: 14 TP'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey<String>('schild-auffang-tp')),
        '20',
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Fängt 14 TP auf · Rest 0 TP · Durchschlag 6 TP'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('schild-auffang-bestaetigen')),
      );
      await tester.pumpAndSettle();

      final schild = (await repo.loadHeroState('demo'))!
          .activeSpellEffects
          .instanzen
          .single;
      expect(schild.schutzRest, 0);
      expect(find.textContaining('Durchschlag: 6 TP'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('schild-durchschlag-buchen')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('schaden-dialog')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey<String>('schaden-tp')))
            .controller!
            .text,
        '6',
      );
    },
  );

  testWidgets('ein veränderter Vorrat verhindert eine Doppelbuchung', (
    tester,
  ) async {
    final katalog = await tester.runAsync(ladeEchtenRegelkatalog);
    final repo = await openDialog(
      tester,
      overrides: katalog!.overrides,
      initialState: schildZustand(),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('spell-instance-einsetzen-schild')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('schild-auffang-tp')),
      '5',
    );
    await tester.pumpAndSettle();
    // Zwischenzeitlich wird der Vorrat anderswo verändert.
    await repo.saveHeroState('demo', schildZustand(rest: 9));
    await tester.tap(
      find.byKey(const ValueKey<String>('schild-auffang-bestaetigen')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('schild-abweichung')),
      findsOneWidget,
    );
    final schild = (await repo.loadHeroState('demo'))!
        .activeSpellEffects
        .instanzen
        .single;
    expect(schild.schutzRest, 9);
  });

  testWidgets('der Schutzvorrat lässt sich begrenzt korrigieren', (
    tester,
  ) async {
    final katalog = await tester.runAsync(ladeEchtenRegelkatalog);
    final repo = await openDialog(
      tester,
      overrides: katalog!.overrides,
      initialState: schildZustand(rest: 8),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('spell-instance-schutz-edit-schild')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('schild-rest-feld')),
      '15',
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey<String>('schild-rest-bestaetigen')),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('schild-rest-feld')),
      '3',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('schild-rest-bestaetigen')),
    );
    await tester.pumpAndSettle();

    final schild = (await repo.loadHeroState('demo'))!
        .activeSpellEffects
        .instanzen
        .single;
    expect(schild.schutzRest, 3);
    expect(find.textContaining('Schutz 3 / 14 TP'), findsOneWidget);
  });

  testWidgets('ein aufgezehrter Schild bietet kein Auffangen mehr an', (
    tester,
  ) async {
    final katalog = await tester.runAsync(ladeEchtenRegelkatalog);
    await openDialog(
      tester,
      overrides: katalog!.overrides,
      initialState: schildZustand(rest: 0),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('spell-instance-einsetzen-schild')),
      findsNothing,
    );
    expect(find.textContaining('aufgezehrt'), findsOneWidget);
  });

  testWidgets('der Effektdialog öffnet den Heilzauber-Dialog', (tester) async {
    final katalog = await tester.runAsync(ladeEchtenRegelkatalog);
    await openDialog(tester, overrides: katalog!.overrides);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('spell-heilung-erhalten')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('heilung-dialog')),
      findsOneWidget,
    );
  });
}
