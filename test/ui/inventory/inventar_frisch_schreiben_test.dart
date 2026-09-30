import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_inventory_tab.dart';

import '../../test_support/bogen_test_repository.dart';

// Sofortaktionen im Inventar (ARCH-05): Löschen und Geldstand arbeiten auf
// dem gespeicherten Helden. Ein anderer Schreibweg speichert nach dem Aufbau
// (`BogenTestRepository.fremdeAenderung`); seine Felder bleiben stehen,
// Münzschritte zählen vom gespeicherten Betrag.

const _seil = HeroInventoryEntry(gegenstand: 'Seil', anzahl: '1');
const _fackel = HeroInventoryEntry(gegenstand: 'Fackel', anzahl: '3');

HeroSheet _held({String dukaten = '5'}) => HeroSheet(
  id: 'hero-1',
  name: 'Thalion',
  level: 1,
  dukaten: dukaten,
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
  inventoryEntries: const [_seil],
);

void main() {
  late BogenTestRepository repo;

  Future<void> zeige(WidgetTester tester, HeroSheet held) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = BogenTestRepository(heroes: [held]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [heroRepositoryProvider.overrideWithValue(repo)],
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

  Future<void> loescheErstenEintrag(WidgetTester tester) async {
    tester
        .widget<IconButton>(
          find.byKey(const ValueKey<String>('inventory-row-delete-0')),
        )
        .onPressed!
        .call();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Löschen'));
    await tester.pumpAndSettle();
  }

  group('Löschen', () {
    testWidgets('trifft den angezeigten Eintrag, nicht die Position', (
      tester,
    ) async {
      await zeige(tester, _held());
      // Inzwischen wurde vor dem Seil eine Fackel gespeichert.
      repo.fremdeAenderung = (held) => held.copyWith(
        name: 'Thalion der Kühne',
        inventoryEntries: const [_fackel, _seil],
      );

      await loescheErstenEintrag(tester);

      final gespeichert = await repo.gespeichert('hero-1');
      expect(gespeichert.inventoryEntries.map((e) => e.gegenstand), ['Fackel']);
      expect(gespeichert.name, 'Thalion der Kühne');
    });

    testWidgets('ein inzwischen geänderter Eintrag wird gemeldet', (
      tester,
    ) async {
      await zeige(tester, _held());
      repo.fremdeAenderung = (held) =>
          held.copyWith(inventoryEntries: [_seil.copyWith(anzahl: '2')]);

      await loescheErstenEintrag(tester);

      expect(
        find.textContaining('Der Gegenstand wurde inzwischen geändert'),
        findsOneWidget,
      );
      expect(repo.bogenSpeicherungen, 0);
    });
  });

  group('Dukaten', () {
    Finder feld() => find.descendant(
      of: find.byKey(const ValueKey<String>('inventory-dukaten-field')),
      matching: find.byType(TextField),
    );

    testWidgets('schnelle Münzschritte zählen vom gespeicherten Betrag', (
      tester,
    ) async {
      await zeige(tester, _held());
      repo.fremdeAenderung = (held) =>
          held.copyWith(name: 'Thalion der Kühne', dukaten: '7');
      final silber = find.byKey(
        const ValueKey<String>('inventory-dukaten-increment-silber'),
      );

      await tester.tap(silber);
      await tester.tap(silber);
      await tester.tap(silber);
      await tester.pumpAndSettle();

      final gespeichert = await repo.gespeichert('hero-1');
      expect(gespeichert.dukaten, '7,3');
      expect(gespeichert.name, 'Thalion der Kühne');
      expect(tester.widget<TextField>(feld()).controller!.text, '7,3');
    });

    testWidgets('ein eingetippter Betrag wird gesetzt', (tester) async {
      await zeige(tester, _held());
      repo.fremdeAenderung = (held) => held.copyWith(name: 'Thalion der Kühne');

      await tester.enterText(feld(), '12');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final gespeichert = await repo.gespeichert('hero-1');
      expect(gespeichert.dukaten, '12');
      expect(gespeichert.name, 'Thalion der Kühne');
    });

    testWidgets('Tippen und Münzschritt: der Schritt geht nicht verloren', (
      tester,
    ) async {
      await zeige(tester, _held());

      await tester.enterText(feld(), '12');
      await tester.tap(
        find.byKey(
          const ValueKey<String>('inventory-dukaten-increment-dukaten'),
        ),
      );
      await tester.pumpAndSettle();

      expect((await repo.gespeichert('hero-1')).dukaten, '13');
    });

    testWidgets('ein Speicherfehler wird gemeldet', (tester) async {
      await zeige(tester, _held());
      repo.schreibFehler = true;

      await tester.tap(
        find.byKey(
          const ValueKey<String>('inventory-dukaten-increment-silber'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Dukaten nicht gespeichert: Speicher voll'),
        findsOneWidget,
      );
    });
  });
}
