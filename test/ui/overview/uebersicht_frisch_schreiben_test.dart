import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_resource_activation_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';

import '../../test_support/bogen_test_repository.dart';

// Sofortaktionen der Übersicht (ARCH-05): Sie arbeiten auf dem gespeicherten
// Helden. Ein anderer Schreibweg speichert nach dem Aufbau
// (`BogenTestRepository.fremdeAenderung`); seine Felder müssen danach noch
// stehen, und Schritte zählen vom gespeicherten Wert.

const _katalog = RulesCatalog(
  version: 'test',
  source: 'test',
  talents: <TalentDef>[],
  spells: <SpellDef>[],
  weapons: <WeaponDef>[],
);

const _basis = Attributes(
  mu: 14,
  kl: 12,
  inn: 13,
  ch: 11,
  ff: 10,
  ge: 12,
  ko: 14,
  kk: 13,
);

HeroSheet _held() => const HeroSheet(
  id: 'demo',
  name: 'Rondra',
  level: 1,
  apTotal: 1000,
  apSpent: 500,
  apAvailable: 500,
  schemaVersion: 30,
  attributes: _basis,
);

/// Zwischenänderung: Name, ein fremder Grundwert-Modifikator und 100 AP.
HeroSheet _fremd(HeroSheet held) => held.copyWith(
  name: 'Rondra die Kühne',
  apTotal: held.apTotal + 100,
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

  Future<void> zeige(WidgetTester tester, {HeroSheet? held}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repo = BogenTestRepository(
      heroes: [held ?? _held()],
      states: const {
        'demo': HeroState(
          currentLep: 10,
          currentAsp: 0,
          currentKap: 0,
          currentAu: 10,
        ),
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          heroRepositoryProvider.overrideWithValue(repo),
          rulesCatalogProvider.overrideWith((ref) async => _katalog),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: HeroOverviewTab(
              heroId: 'demo',
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

  Future<void> sichtbar(WidgetTester tester, Finder ziel) async {
    await tester.scrollUntilVisible(
      ziel,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  group('AP addieren', () {
    testWidgets('zählt vom gespeicherten Konto', (tester) async {
      await zeige(tester);
      repo.fremdeAenderung = _fremd;
      final knopf = find.byKey(const ValueKey('overview-action-add-ap_total'));
      await sichtbar(tester, knopf);

      await tester.tap(knopf);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '50');
      await tester.tap(find.text('Addieren'));
      await tester.pumpAndSettle();

      final gespeichert = await repo.gespeichert('demo');
      expect(gespeichert.apTotal, 1150);
      _expectFremdesErhalten(gespeichert);
    });

    testWidgets('ein Speicherfehler wird gemeldet', (tester) async {
      await zeige(tester);
      repo.schreibFehler = true;
      final knopf = find.byKey(const ValueKey('overview-action-add-ap_spent'));
      await sichtbar(tester, knopf);

      await tester.tap(knopf);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '5');
      await tester.tap(find.text('Addieren'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('nicht gespeichert: Speicher voll'),
        findsOneWidget,
      );
      expect((await repo.gespeichert('demo')).apSpent, 500);
    });
  });

  group('Ressourcen-Einstellungen', () {
    Future<void> schalteMagieAus(WidgetTester tester) async {
      final oeffnen = find.byKey(
        const ValueKey('overview-resource-settings-open'),
      );
      await sichtbar(tester, oeffnen);
      tester.widget<IconButton>(oeffnen).onPressed!.call();
      await tester.pumpAndSettle();
      tester
          .widget<Switch>(
            find.byKey(const ValueKey('overview-resource-toggle-magic')),
          )
          .onChanged
          ?.call(false);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('overview-resource-settings-save')),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('schreibt nur den umgestellten Schalter', (tester) async {
      await zeige(tester);
      // Ein anderer Weg hat inzwischen Karma eingeschaltet.
      repo.fremdeAenderung = (held) => _fremd(held).copyWith(
        resourceActivationConfig: const HeroResourceActivationConfig(
          divineEnabledOverride: true,
        ),
      );

      await schalteMagieAus(tester);

      final gespeichert = await repo.gespeichert('demo');
      final config = gespeichert.resourceActivationConfig;
      expect(config.magicEnabledOverride, isFalse);
      expect(config.divineEnabledOverride, isTrue);
      _expectFremdesErhalten(gespeichert);
      expect(
        find.byKey(const ValueKey('overview-resource-settings-dialog')),
        findsNothing,
      );
    });

    testWidgets('ein Fehler erscheint im Blatt, das offen bleibt', (
      tester,
    ) async {
      await zeige(tester);
      repo.schreibFehler = true;

      await schalteMagieAus(tester);

      final blatt = find.byKey(
        const ValueKey('overview-resource-settings-dialog'),
      );
      expect(blatt, findsOneWidget);
      expect(
        find.descendant(
          of: blatt,
          matching: find.textContaining(
            'Ressourcen-Einstellungen nicht gespeichert',
          ),
        ),
        findsOneWidget,
      );
    });
  });

  group('Modifikatordialoge', () {
    testWidgets('ein Grundwert ersetzt nur seinen Schlüssel', (tester) async {
      await zeige(tester);
      repo.fremdeAenderung = _fremd;
      final zelle = find.byKey(const ValueKey('overview-stat-modifier-lep'));
      await sichtbar(tester, zelle);

      await tester.tap(zelle);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('stat-modifiers-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('stat-modifier-value-0')),
        '4',
      );
      await tester.enterText(
        find.byKey(const ValueKey('stat-modifier-description-0')),
        'Zäh',
      );
      await tester.tap(find.byKey(const ValueKey('stat-modifiers-save')));
      await tester.pumpAndSettle();

      final gespeichert = await repo.gespeichert('demo');
      expect(gespeichert.statModifiers['lep']!.single.modifier, 4);
      _expectFremdesErhalten(gespeichert);
    });

    testWidgets('eine Eigenschaft ersetzt nur ihren Schlüssel', (tester) async {
      await zeige(tester);
      repo.fremdeAenderung = _fremd;
      final zelle = find.byKey(const ValueKey('overview-effective-mu'));
      await sichtbar(tester, zelle);

      final kachel = find.ancestor(of: zelle, matching: find.byType(InkWell));
      tester.widget<InkWell>(kachel.first).onTap!.call();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('attr-modifiers-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('attr-modifier-value-0')),
        '1',
      );
      await tester.enterText(
        find.byKey(const ValueKey('attr-modifier-description-0')),
        'Segen',
      );
      await tester.tap(find.byKey(const ValueKey('attr-modifiers-save')));
      await tester.pumpAndSettle();

      final gespeichert = await repo.gespeichert('demo');
      expect(gespeichert.attributeModifiers['mu']!.single.modifier, 1);
      _expectFremdesErhalten(gespeichert);
    });
  });

  group('Epischer Status', () {
    Future<void> aktiviere(WidgetTester tester) async {
      final knopf = find.byKey(const ValueKey('overview-action-epic-activate'));
      await sichtbar(tester, knopf);
      await tester.tap(knopf);
      await tester.pumpAndSettle();
      for (final schluessel in const [
        'epic-dialog-mental-kl',
        'epic-dialog-physical-kk',
        'epic-dialog-confirm',
      ]) {
        final ziel = find.byKey(ValueKey<String>(schluessel));
        await tester.ensureVisible(ziel);
        await tester.pumpAndSettle();
        await tester.tap(ziel);
        await tester.pumpAndSettle();
      }
    }

    testWidgets('Start-AP kommen aus dem gespeicherten Helden', (tester) async {
      await zeige(tester);
      repo.fremdeAenderung = (held) => _fremd(held).copyWith(apSpent: 700);

      await aktiviere(tester);

      final gespeichert = await repo.gespeichert('demo');
      expect(gespeichert.isEpisch, isTrue);
      expect(gespeichert.epicStartAp, 700);
      expect(gespeichert.epicMainAttributes.kl, 1);
      _expectFremdesErhalten(gespeichert);
    });

    testWidgets('ein inzwischen epischer Held wird nicht erneut aktiviert', (
      tester,
    ) async {
      await zeige(tester);
      repo.fremdeAenderung = (held) =>
          held.copyWith(isEpisch: true, epicStartAp: 300);

      await aktiviere(tester);

      expect(
        find.text(
          'Epischer Status nicht gespeichert: Der epische Status ist '
          'bereits aktiviert.',
        ),
        findsOneWidget,
      );
      expect(repo.bogenSpeicherungen, 0);
    });
  });

  testWidgets('Hinweis quittieren erhält fremde Felder', (tester) async {
    final bestand = _held().copyWith(
      schemaVersion: 27,
      rawStartAttributes: _basis,
      vorteileText: 'Herausragende Eigenschaft KK 2',
    );
    await zeige(tester, held: bestand);
    repo.fremdeAenderung = _fremd;
    final knopf = find.byKey(const ValueKey('attribute-trait-notice-ack'));
    await sichtbar(tester, knopf);

    await tester.tap(knopf);
    await tester.pumpAndSettle();

    final gespeichert = await repo.gespeichert('demo');
    expect(gespeichert.schemaVersion, 28);
    _expectFremdesErhalten(gespeichert);
  });
}
