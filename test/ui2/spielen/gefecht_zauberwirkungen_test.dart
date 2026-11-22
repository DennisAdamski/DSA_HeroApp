import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/spell_duration.dart';
import 'package:dsa_heldenverwaltung/domain/spell_effect_instance.dart';
import 'package:dsa_heldenverwaltung/domain/active_spell_effects_state.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_modifiers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/active_spell_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spell_effect_protection_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';

import '../../test_support/fake_repository.dart';

import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_ansicht.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';

import '../shell/karto_test_support.dart';
import 'gefecht_test_support.dart';

SpellEffectInstance _attributo() => SpellEffectInstance(
  id: 'a1',
  effectId: activeSpellEffectAttributo,
  vorgangsId: 'v-a1',
  attributeMods: const AttributeModifiers(mu: 2),
  duration: SpellDuration(amount: 3, unit: SpellDurationUnit.kampfrunden),
);

SpellEffectInstance _schild() => SpellEffectInstance(
  id: 'g1',
  effectId: kGardianumZauberId,
  vorgangsId: 'v-g1',
  quelle: 'Rondra',
  amount: 10,
  schutzRest: 10,
  duration: SpellDuration(amount: 5, unit: SpellDurationUnit.kampfrunden),
);

class _Repo extends FakeRepository {
  _Repo(List<SpellEffectInstance> instanzen)
    : super(
        heroes: [testHero()],
        states: {
          'rondra': HeroState(
            currentLep: 30,
            currentAsp: 20,
            currentKap: 15,
            currentAu: 30,
            activeSpellEffects: ActiveSpellEffectsState(instanzen: instanzen),
            unbekannteFelder: const {'future': 42},
          ),
        },
      );
}

Future<({_Repo repo, GefechtsTestBestand bestand})> _oeffne(
  WidgetTester tester,
  List<SpellEffectInstance> instanzen,
) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repo = _Repo(instanzen);
  final bestand = GefechtsTestBestand();
  final container = ProviderContainer(
    overrides: [
      heroRepositoryProvider.overrideWithValue(repo),
      rulesCatalogProvider.overrideWith((ref) async => testCatalog),
    ],
  );
  addTearDown(container.dispose);
  container.read(gefechtProvider('rondra').notifier).beginnen(6);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: GefechtAnsicht(heroId: 'rondra', bestand: bestand),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (repo: repo, bestand: bestand);
}

Future<void> _tippe(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'zeigt jede laufende Wirkung mit Dauer, Quelle und Schutzvorrat',
    (tester) async {
      await _oeffne(tester, [_attributo(), _schild()]);
      expect(
        find.byKey(const ValueKey('gefecht-zauberwirkungen-rondra')),
        findsOne,
      );
      expect(find.byKey(const ValueKey('gefecht-wirkung-a1')), findsOneWidget);
      expect(find.byKey(const ValueKey('gefecht-wirkung-g1')), findsOneWidget);
      expect(find.textContaining('Quelle: Rondra'), findsOneWidget);
      expect(find.textContaining('Boni: MU+2'), findsOneWidget);
      // Zählt jede Wirkung, nicht nur die drei Bestandseffekte.
      expect(find.textContaining('2 laufend'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ohne Wirkung bleibt das Anlegen erreichbar', (tester) async {
    await _oeffne(tester, const []);
    expect(find.text('Keine Zauberwirkung läuft.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('gefecht-wirkung-attributo-hinzu')),
      findsOneWidget,
    );
  });

  testWidgets('Dauer −1, Unterdrücken und Beenden schreiben frisch', (
    tester,
  ) async {
    final o = await _oeffne(tester, [_attributo(), _schild()]);

    await _tippe(tester, const ValueKey('gefecht-wirkung-minus-a1'));
    var z = (await o.repo.loadHeroState('rondra'))!;
    expect(
      z.activeSpellEffects.instanzen
          .firstWhere((i) => i.id == 'a1')
          .duration!
          .remaining,
      2,
    );

    await _tippe(tester, const ValueKey('gefecht-wirkung-wirkt-g1'));
    z = (await o.repo.loadHeroState('rondra'))!;
    expect(
      z.activeSpellEffects.instanzen
          .firstWhere((i) => i.id == 'g1')
          .unterdrueckt,
      isTrue,
    );

    await _tippe(tester, const ValueKey('gefecht-wirkung-beenden-a1'));
    z = (await o.repo.loadHeroState('rondra'))!;
    expect([for (final i in z.activeSpellEffects.instanzen) i.id], ['g1']);
    // Fremde Felder und Werte bleiben beim frischen Schreiben erhalten.
    expect(z.unbekannteFelder['future'], 42);
    expect(z.currentLep, 30);
    expect(find.byKey(const ValueKey('gefecht-wirkung-a1')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dauer und Anlegen laufen über die Bestandsbrücke', (
    tester,
  ) async {
    final o = await _oeffne(tester, [_attributo()]);

    await _tippe(tester, const ValueKey('gefecht-wirkung-dauer-edit-a1'));
    expect(o.bestand.wirkungsAufrufe.last, (GefechtsWirkungAktion.dauer, 'a1'));
    await tester.tap(find.text('Abbrechen').last);
    await tester.pumpAndSettle();

    await _tippe(tester, const ValueKey('gefecht-wirkung-attributo-hinzu'));
    expect(o.bestand.wirkungsAufrufe.last, (
      GefechtsWirkungAktion.attributoHinzufuegen,
      null,
    ));
    await tester.tap(find.text('Abbrechen').last);
    await tester.pumpAndSettle();

    // Abbruch legt nichts an und ändert nichts.
    final z = (await o.repo.loadHeroState('rondra'))!;
    expect(z.activeSpellEffects.instanzen.single.duration!.remaining, 3);
    expect(tester.takeException(), isNull);
  });
}
