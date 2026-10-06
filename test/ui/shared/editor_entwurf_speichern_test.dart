import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/editor_entwurf_rules.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/editor_entwurf_speichern.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/zustand_aendern.dart';

import '../../test_support/bogen_test_repository.dart';
import '../../ui2/shell/karto_test_support.dart';

// Gemeinsamer Speicherweg der Editorentwürfe (ARCH-05): Der Entwurf wird mit
// dem frisch geladenen Helden abgeglichen. Überschneiden sich Änderungen,
// entscheidet der Nutzer im Dialog; nichts wird still überschrieben.

const _abenteuer = HeroAdventureEntry(id: 'adv_1', title: 'Feuer im Nebel');

void main() {
  late BogenTestRepository repo;
  late ProviderContainer container;
  late HeroSheet basis;
  bool? ergebnis;
  Object? fehler;

  Future<void> zeige(WidgetTester tester, HeroSheet entwurf) async {
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
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () =>
                    speichereEditorEntwurf(
                      context: context,
                      ref: ref,
                      heroId: 'rondra',
                      abgleich: (aktuell, erzwungen) => uebernimmEditorEntwurf(
                        basis: basis,
                        entwurf: entwurf,
                        aktuell: aktuell,
                        erzwungen: erzwungen,
                        neueId: neueEditorSlotId,
                      ),
                    ).then<void>(
                      (wert) => ergebnis = wert,
                      onError: (Object grund) => fehler = grund,
                    ),
                child: const Text('Speichern'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> speichere(WidgetTester tester) async {
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
  }

  setUp(() async {
    repo = BogenTestRepository(
      heroes: [
        testHero().copyWith(adventures: const [_abenteuer]),
      ],
    );
    basis = await repo.gespeichert('rondra');
    ergebnis = null;
    fehler = null;
  });

  testWidgets('eine fremde Änderung an einem anderen Bereich bleibt', (
    tester,
  ) async {
    await zeige(tester, basis.copyWith(name: 'Rondra die Kühne'));
    repo.fremdeAenderung = (held) => held.copyWith(dukaten: '42');

    await speichere(tester);

    final gespeichert = await repo.gespeichert('rondra');
    expect(ergebnis, isTrue);
    expect(gespeichert.name, 'Rondra die Kühne');
    expect(gespeichert.dukaten, '42');
    expect(find.text(kEditorEntwurfKonfliktTitel), findsNothing);
  });

  testWidgets('„Weiter bearbeiten“ speichert bei Überschneidung nichts', (
    tester,
  ) async {
    await zeige(tester, basis.copyWith(name: 'Rondra die Kühne'));
    repo.fremdeAenderung = (held) => held.copyWith(name: 'Rondra die Weise');

    await speichere(tester);
    expect(find.text(kEditorEntwurfKonfliktTitel), findsOneWidget);
    expect(find.textContaining('Name'), findsOneWidget);
    await tester.tap(find.text(kEditorEntwurfWeiter));
    await tester.pumpAndSettle();

    expect(ergebnis, isFalse);
    expect(repo.bogenSpeicherungen, 0);
  });

  testWidgets('„Meine Fassung speichern“ ersetzt nur den betroffenen Bereich', (
    tester,
  ) async {
    await zeige(tester, basis.copyWith(name: 'Rondra die Kühne'));
    repo.fremdeAenderung = (held) =>
        held.copyWith(name: 'Rondra die Weise', dukaten: '42');

    await speichere(tester);
    await tester.tap(find.text(kEditorEntwurfErzwingen));
    await tester.pumpAndSettle();

    final gespeichert = await repo.gespeichert('rondra');
    expect(ergebnis, isTrue);
    expect(gespeichert.name, 'Rondra die Kühne');
    expect(gespeichert.dukaten, '42');
  });

  testWidgets('ein inzwischen abgeschlossenes Abenteuer ist nicht erzwingbar', (
    tester,
  ) async {
    await zeige(
      tester,
      basis.copyWith(adventures: [_abenteuer.copyWith(title: 'Umbenannt')]),
    );
    repo.fremdeAenderung = (held) => held.copyWith(
      adventures: [
        _abenteuer.copyWith(
          status: HeroAdventureStatus.completed,
          rewardsApplied: true,
        ),
      ],
    );

    await speichere(tester);

    expect(find.text(kEditorEntwurfErzwingen), findsNothing);
    expect(find.textContaining('nicht gespeichert'), findsOneWidget);
    await tester.tap(find.text(kEditorEntwurfWeiter));
    await tester.pumpAndSettle();
    expect(ergebnis, isFalse);
    expect(repo.bogenSpeicherungen, 0);
  });

  testWidgets('während einer Planung wird nichts gespeichert', (tester) async {
    await zeige(tester, basis.copyWith(name: 'Rondra die Kühne'));
    container
        .read(advancementSessionProvider('rondra').notifier)
        .start(hero: testHero(), catalog: testCatalog);

    await speichere(tester);

    expect(repo.bogenSpeicherungen, 0);
    expect(
      fehler,
      isA<StateError>().having(
        (grund) => grund.message,
        'message',
        kBogenWaehrendPlanungGesperrt,
      ),
    );
  });
}
