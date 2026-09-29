import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/stat_modifiers.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_spiel_bruecke.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/zustand_aendern.dart';
import 'package:dsa_heldenverwaltung/ui/screens/workspace/wunden_detail_dialog.dart';

import '../../test_support/bogen_test_repository.dart';
import '../../ui2/shell/karto_test_support.dart';

// Sofortaktionen am Bogen in der Spielansicht (ARCH-05): Dauermodifikatoren
// und Wundschwelle arbeiten auf dem gespeicherten Helden. Ein anderer
// Schreibweg speichert nach dem Aufbau der Oberfläche
// (`BogenTestRepository.fremdeAenderung`); seine Felder müssen danach noch
// stehen, und während einer Planung wird nichts geschrieben.

/// Zwischenänderung: neuer Name und ein fremder Grundwert-Modifikator.
HeroSheet _fremd(HeroSheet held) => held.copyWith(
  name: 'Rondra die Kühne',
  persistentMods: held.persistentMods.copyWith(iniBase: 2),
  statModifiers: {
    ...held.statModifiers,
    'au': [HeroTalentModifier(modifier: 3, description: 'Fremd')],
  },
);

void _expectFremdesErhalten(HeroSheet gespeichert) {
  expect(gespeichert.name, 'Rondra die Kühne');
  expect(gespeichert.statModifiers['au']!.single.description, 'Fremd');
}

void main() {
  late BogenTestRepository repo;
  late ProviderContainer container;

  Future<void> zeige(WidgetTester tester, Widget kind) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1600);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
          home: Scaffold(body: SingleChildScrollView(child: kind)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Der UI2-Zustandsblock mit Belastung, Wunden und Statuswerten.
  Widget zustandsblock() => Consumer(
    builder: (context, ref, _) {
      final werte = ref.watch(heroComputedProvider('rondra')).asData?.value;
      if (werte == null) {
        return const SizedBox.shrink();
      }
      return KartoZustandsblock(heroId: 'rondra', werte: werte);
    },
  );

  Finder knopf(String tooltip) => find.byTooltip(tooltip);

  void starteRunde() {
    container
        .read(advancementSessionProvider('rondra').notifier)
        .start(hero: testHero(), catalog: testCatalog);
  }

  setUp(() {
    repo = BogenTestRepository(heroes: [testHero()]);
  });

  group('Inspector-Statuswerte', () {
    testWidgets('ein Schritt zählt vom gespeicherten Wert', (tester) async {
      await zeige(tester, zustandsblock());
      repo.fremdeAenderung = _fremd;

      await tester.tap(knopf('Ini erhöhen'));
      await tester.pumpAndSettle();

      final gespeichert = await repo.gespeichert('rondra');
      expect(gespeichert.persistentMods.iniBase, 3);
      _expectFremdesErhalten(gespeichert);
    });

    testWidgets('drei schnelle Klicks zählen alle', (tester) async {
      await zeige(tester, zustandsblock());

      await tester.tap(knopf('GS erhöhen'));
      await tester.tap(knopf('GS erhöhen'));
      await tester.tap(knopf('GS erhöhen'));
      await tester.pumpAndSettle();

      expect((await repo.gespeichert('rondra')).persistentMods.gs, 3);
    });

    testWidgets('Zurücksetzen trifft nur den eigenen Wert', (tester) async {
      repo = BogenTestRepository(
        heroes: [
          testHero().copyWith(
            persistentMods: const StatModifiers(at: 2, pa: -1),
          ),
        ],
      );
      await zeige(tester, zustandsblock());
      repo.fremdeAenderung = _fremd;

      await tester.tap(knopf('AT zurücksetzen'));
      await tester.pumpAndSettle();

      final gespeichert = await repo.gespeichert('rondra');
      expect(gespeichert.persistentMods.at, 0);
      expect(gespeichert.persistentMods.pa, -1);
      expect(gespeichert.persistentMods.iniBase, 2);
      _expectFremdesErhalten(gespeichert);
    });

    testWidgets('ein Speicherfehler erscheint im Zustandsblock', (
      tester,
    ) async {
      await zeige(tester, zustandsblock());
      repo.schreibFehler = true;

      await tester.tap(knopf('RS erhöhen'));
      await tester.pumpAndSettle();

      expect(find.byKey(kZustandFehlerSchluessel), findsOneWidget);
      expect(
        find.text('RS-Modifikator nicht gespeichert: Speicher voll'),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);

      repo.schreibFehler = false;
      await tester.tap(knopf('RS erhöhen'));
      await tester.pumpAndSettle();
      expect(find.byKey(kZustandFehlerSchluessel), findsNothing);
    });

    testWidgets('während einer Planung gesperrt, BE bleibt bedienbar', (
      tester,
    ) async {
      await zeige(tester, zustandsblock());
      starteRunde();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('inspector-statuswerte-gesperrt')),
        findsOneWidget,
      );
      for (final label in ['Ini', 'GS', 'AW', 'PA', 'AT', 'RS']) {
        final knoepfe = tester.widgetList<IconButton>(
          find.descendant(
            of: find.byKey(ValueKey('workspace-status-row-$label')),
            matching: find.byType(IconButton),
          ),
        );
        for (final knopf in knoepfe) {
          expect(knopf.onPressed, isNull, reason: label);
        }
      }
      await tester.tap(knopf('GS erhöhen'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(repo.bogenSpeicherungen, 0);

      await tester.tap(knopf('BE erhöhen'));
      await tester.pumpAndSettle();
      expect(container.read(talentBeOverrideProvider('rondra')), isNotNull);
    });
  });

  group('Wundschwelle', () {
    Widget wundenKnopf() => Consumer(
      builder: (context, ref, _) => TextButton(
        onPressed: () =>
            showWundenDetailDialog(context: context, heroId: 'rondra'),
        child: const Text('Wunden'),
      ),
    );

    Future<void> setzeModifikator(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Wundschwelle-Modifikatoren'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('stat-modifiers-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('stat-modifier-value-0')),
        '2',
      );
      await tester.enterText(
        find.byKey(const ValueKey('stat-modifier-description-0')),
        'Zäh',
      );
      await tester.tap(find.byKey(const ValueKey('stat-modifiers-save')));
      await tester.pumpAndSettle();
    }

    testWidgets('ersetzt nur den Wundschwellen-Schlüssel', (tester) async {
      await zeige(tester, wundenKnopf());
      await tester.tap(find.text('Wunden'));
      await tester.pumpAndSettle();
      repo.fremdeAenderung = _fremd;

      await setzeModifikator(tester);

      final gespeichert = await repo.gespeichert('rondra');
      final wundschwelle = gespeichert.statModifiers['wundschwelle']!;
      expect(wundschwelle.single.modifier, 2);
      expect(wundschwelle.single.description, 'Zäh');
      _expectFremdesErhalten(gespeichert);
    });

    testWidgets('ein Speicherfehler erscheint im Dialog', (tester) async {
      await zeige(tester, wundenKnopf());
      await tester.tap(find.text('Wunden'));
      await tester.pumpAndSettle();
      repo.schreibFehler = true;

      await setzeModifikator(tester);

      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining(
            'Wundschwelle-Modifikatoren nicht gespeichert',
          ),
        ),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('während einer Planung ist das Zahnrad gesperrt', (
      tester,
    ) async {
      await zeige(tester, wundenKnopf());
      starteRunde();
      await tester.tap(find.text('Wunden'));
      await tester.pumpAndSettle();

      final zahnrad = tester.widget<IconButton>(
        find.byKey(const ValueKey('wunden-wundschwelle-modifikatoren')),
      );
      expect(zahnrad.onPressed, isNull);
      expect(
        zahnrad.tooltip,
        'Wundschwelle-Modifikatoren – während der Planung gesperrt',
      );
    });
  });

  testWidgets('der Einstieg schreibt während einer Planung nichts', (
    tester,
  ) async {
    await zeige(
      tester,
      Consumer(
        builder: (context, ref, _) => TextButton(
          onPressed: () => unawaited(
            aendereHeldMitMeldung(
              context: context,
              ref: ref,
              heroId: 'rondra',
              was: 'Test',
              aenderung: (held) => held.copyWith(name: 'Neu'),
            ),
          ),
          child: const Text('los'),
        ),
      ),
    );
    starteRunde();

    await tester.tap(find.text('los'));
    await tester.pumpAndSettle();

    expect(repo.bogenSpeicherungen, 0);
    expect(
      find.text(
        'Test nicht gespeichert: Während einer Planung ist der Heldenbogen '
        'gesperrt.',
      ),
      findsOneWidget,
    );
  });
}
