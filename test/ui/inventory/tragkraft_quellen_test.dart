import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_tragkraft_bonus.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory_tab.dart';

import '../../test_support/bogen_test_repository.dart';
import '../../ui2/shell/karto_test_support.dart';

// Tragkraftquellen im Inventar-Tab: Bärenrune und andere dauerhafte Quellen
// schreiben frisch auf den gespeicherten Helden; ein anderer Schreibweg
// (`BogenTestRepository.fremdeAenderung`) bleibt erhalten. Während einer
// Planung ist der Abschnitt gesperrt. Die Spielansicht zeigt in „Dabei“ nur
// noch die Last.

HeroSheet _held({List<HeroTragkraftBonus> quellen = const []}) => HeroSheet(
  id: 'hero-1',
  name: 'Thalion',
  level: 1,
  dukaten: '0',
  attributes: const Attributes(
    mu: 12,
    kl: 11,
    inn: 10,
    ch: 10,
    ff: 11,
    ge: 12,
    ko: 11,
    kk: 12,
  ),
  tragkraftBoni: quellen,
);

Finder _k(String key) => find.byKey(ValueKey<String>(key));

void main() {
  late BogenTestRepository repo;
  late ProviderContainer container;

  Future<void> zeige(WidgetTester tester, HeroSheet held) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = BogenTestRepository(heroes: [held]);
    container = ProviderContainer(
      overrides: [
        heroRepositoryProvider.overrideWithValue(repo),
        rulesCatalogProvider.overrideWith((ref) async => testCatalog),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: HeroInventoryTab(
              heroId: 'hero-1',
              onDirtyChanged: (_) {},
              onEditingChanged: (_) {},
              onRegisterDiscard: (_) {},
              onRegisterEditActions: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<HeroSheet> gespeichert() async => (await repo.loadHeroById('hero-1'))!;

  String tragkraftText(WidgetTester tester) =>
      tester.widget<Text>(_k('inventory-tragkraft-wert')).data!;

  testWidgets('zeigt die Tragkraft unter dem Geld', (tester) async {
    await zeige(tester, _held());
    expect(tragkraftText(tester), 'Tragkraft 12 Stein');
    final geld = tester.getRect(_k('inventory-dukaten-field'));
    final tragkraft = tester.getRect(_k('inventory-tragkraft'));
    expect(tragkraft.top, greaterThanOrEqualTo(geld.bottom));
  });

  testWidgets('Bärenrune: RkP* mal 10 Stein, Hausregel KK +1, frisch', (
    tester,
  ) async {
    await zeige(tester, _held());
    repo.fremdeAenderung = (held) => held.copyWith(name: 'Thalion der Kühne');

    await tester.tap(_k('inventory-tragkraft-baerenrune'));
    await tester.pumpAndSettle();
    await tester.enterText(_k('inventory-tragkraft-baerenrune-rkp'), '7');
    await tester.tap(_k('inventory-tragkraft-baerenrune-kk'));
    await tester.pumpAndSettle();
    await tester.tap(_k('inventory-tragkraft-baerenrune-ok'));
    await tester.pumpAndSettle();

    final held = await gespeichert();
    expect(held.name, 'Thalion der Kühne');
    expect(held.tragkraftBoni, hasLength(1));
    expect(held.tragkraftBoni.single.stein, 70);
    expect(held.tragkraftBoni.single.kk, 1);
    expect(held.tragkraftBoni.single.name, 'Bärenrune (RkP* 7)');
    // 12 + 1 + 70
    expect(tragkraftText(tester), 'Tragkraft 83 Stein');
    expect(find.text('Bärenrune (RkP* 7) · +70 Stein · KK +1'), findsOneWidget);
  });

  testWidgets('Bärenrune verlangt RkP* über 0', (tester) async {
    await zeige(tester, _held());
    await tester.tap(_k('inventory-tragkraft-baerenrune'));
    await tester.pumpAndSettle();
    await tester.tap(_k('inventory-tragkraft-baerenrune-ok'));
    await tester.pumpAndSettle();
    expect(
      find.text('Bitte die RkP* als Zahl über 0 eingeben.'),
      findsOneWidget,
    );
    expect((await gespeichert()).tragkraftBoni, isEmpty);
  });

  testWidgets('andere Quelle anlegen und wieder entfernen', (tester) async {
    await zeige(tester, _held());
    await tester.tap(_k('inventory-tragkraft-quelle'));
    await tester.pumpAndSettle();
    await tester.enterText(
      _k('inventory-tragkraft-quelle-name'),
      'Gürtel der Stärke',
    );
    await tester.enterText(_k('inventory-tragkraft-quelle-stein'), '5');
    await tester.tap(_k('inventory-tragkraft-quelle-ok'));
    await tester.pumpAndSettle();
    expect(
      (await gespeichert()).tragkraftBoni.single.name,
      'Gürtel der Stärke',
    );
    expect(tragkraftText(tester), 'Tragkraft 17 Stein');

    await tester.tap(find.byTooltip('Gürtel der Stärke entfernen'));
    await tester.pumpAndSettle();
    expect((await gespeichert()).tragkraftBoni, isEmpty);
    expect(tragkraftText(tester), 'Tragkraft 12 Stein');
  });

  testWidgets('während einer Planung gesperrt', (tester) async {
    final held = _held(
      quellen: const [HeroTragkraftBonus(id: 'a', name: 'Rune', stein: 10)],
    );
    await zeige(tester, held);
    container
        .read(advancementSessionProvider('hero-1').notifier)
        .start(hero: held, catalog: testCatalog);
    await tester.pumpAndSettle();

    final chip = tester.widget<InputChip>(_k('inventory-tragkraft-quelle-0'));
    expect(chip.onDeleted, isNull);
    final rune = tester.widget<TextButton>(
      _k('inventory-tragkraft-baerenrune'),
    );
    expect(rune.onPressed, isNull);
    expect((await gespeichert()).tragkraftBoni, hasLength(1));
  });
}
