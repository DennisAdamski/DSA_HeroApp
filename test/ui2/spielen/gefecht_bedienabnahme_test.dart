import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_einstieg.dart';

import '../../rules/gefecht_talentprobe_rules_test.dart' show klettern;
import '../shell/karto_test_support.dart';
import 'gefecht_test_support.dart';

// Bedienabnahme der Vervollständigung (G8): Ein Gefecht beginnt über den
// echten Einstieg und läuft eine typische Runde ohne Formulareingaben durch.
// Die Probe selbst liefert die Testbrücke; im echten Dialog kämen je Probe
// „Würfeln“ und „Schließen“ hinzu.

const _katalog = RulesCatalog(
  version: 'test',
  source: 'test',
  talents: [klettern],
  spells: [],
  weapons: [],
);

void main() {
  testWidgets(
    'Runde: Gefecht beginnen, AT, PA, Talentprobe, neue Runde, Ende',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final snapshot = buildHeroComputedSnapshot(
        hero: testHero().copyWith(
          talents: const {'tal_klettern': HeroTalentEntry(talentValue: 7)},
          combatConfig: const CombatConfig(
            weapons: [
              MainWeaponSlot(id: 'a', name: 'Schwert', distanceClass: 'NS'),
            ],
          ),
        ),
        state: const HeroState(
          currentLep: 30,
          currentAsp: 0,
          currentKap: 0,
          currentAu: 30,
        ),
        catalog: _katalog,
        epicAdvantagesActive: false,
      );
      final container = ProviderContainer(
        overrides: [
          heroComputedProvider('rondra')
              .overrideWith((ref) => AsyncData(snapshot)),
          rulesCatalogProvider.overrideWith((ref) async => _katalog),
        ],
      );
      addTearDown(container.dispose);
      final bestand = GefechtsTestBestand();
      var taps = 0;
      Future<void> tippe(Finder f) async {
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        await tester.tap(f);
        await tester.pumpAndSettle();
        taps++;
      }

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: GefechtEinstieg(
                heroId: 'rondra',
                werte: snapshot,
                bestand: bestand,
                aktion: (f) => f(),
                vorBearbeitung: () async => true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Beginn: INI-Wurf über die Brücke, Start-DK aus der Waffe (NS → N).
      await tippe(find.byKey(const ValueKey('gefecht-beginnen')));
      expect(bestand.anfragen.single.type, ProbeType.initiative);
      var s = container.read(gefechtProvider('rondra'))!;
      expect(s.dk, 'N');
      expect(find.text('Gefecht'), findsOneWidget);

      // Attacke ohne jede Eingabe: Knopf und „Würfeln“.
      taps = 0;
      await tippe(find.textContaining('Angreifen').first);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('gefecht-auftrag-starten')),
          matching: find.textContaining('Würfeln · '),
        ),
        findsOneWidget,
      );
      await tippe(find.byKey(const ValueKey('gefecht-auftrag-starten')));
      expect(taps, 2);
      s = container.read(gefechtProvider('rondra'))!;
      expect(s.angriffeVerbraucht, 1);
      expect(bestand.anfragen.last.type, ProbeType.combatAttack);

      // Parade ohne Angriffsart oder Finte einzutippen.
      taps = 0;
      await tippe(find.textContaining('Parieren').first);
      await tippe(find.byKey(const ValueKey('gefecht-auftrag-starten')));
      expect(taps, 2);
      s = container.read(gefechtProvider('rondra'))!;
      expect(s.paradenVerbraucht, 1);
      expect(s.kontext.finte, 0);

      // Reaktive Eigenschaftsprobe kostet keine Aktion.
      await tippe(find.byKey(const ValueKey('gefecht-probe')));
      await tester.enterText(
        find.byKey(const ValueKey('gefecht-probe-suche')),
        'GE',
      );
      await tester.pumpAndSettle();
      await tippe(find.widgetWithText(ListTile, 'GE').first);
      await tippe(find.byKey(const ValueKey('gefecht-talentprobe-starten')));
      expect(bestand.anfragen.last.type, ProbeType.attribute);

      // Neue Runde setzt die Marken zurück.
      await tippe(find.text('Nächste Runde'));
      s = container.read(gefechtProvider('rondra'))!;
      expect(s.runde, 2);
      expect(s.angriffeVerbraucht + s.paradenVerbraucht, 0);

      // Beenden verwirft die Sitzung und schließt die Ansicht.
      await tippe(find.widgetWithText(TextButton, 'Beenden'));
      await tippe(find.widgetWithText(FilledButton, 'Beenden'));
      expect(container.read(gefechtProvider('rondra')), isNull);
      expect(find.byKey(const ValueKey('gefecht-beginnen')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
