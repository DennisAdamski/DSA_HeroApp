import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_ansicht.dart';

import '../../rules/gefecht_talentprobe_rules_test.dart' show klettern;
import '../shell/karto_test_support.dart';
import 'gefecht_test_support.dart';

const _katalog = RulesCatalog(
  version: 'test',
  source: 'test',
  talents: [klettern],
  spells: [],
  weapons: [],
);

Future<(ProviderContainer, GefechtsTestBestand)> _ansicht(
  WidgetTester tester,
) async {
  tester.view.physicalSize = const Size(1200, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final snapshot = buildHeroComputedSnapshot(
    hero: testHero().copyWith(
      talents: const {'tal_klettern': HeroTalentEntry(talentValue: 7)},
      combatConfig: const CombatConfig(
        weapons: [MainWeaponSlot(id: 'a', name: 'Schwert', distanceClass: 'N')],
      ),
    ),
    state: const HeroState.empty(),
    catalog: _katalog,
    epicAdvantagesActive: false,
  );
  final container = ProviderContainer(
    overrides: [
      heroComputedProvider('rondra').overrideWith((ref) => AsyncData(snapshot)),
      rulesCatalogProvider.overrideWith((ref) async => _katalog),
    ],
  );
  addTearDown(container.dispose);
  container.read(gefechtProvider('rondra').notifier).beginnen(6, dk: 'N');
  final bestand = GefechtsTestBestand();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: GefechtAnsicht(heroId: 'rondra', bestand: bestand),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (container, bestand);
}

Future<void> _waehlen(WidgetTester tester, String name) async {
  await tester.enterText(
    find.byKey(const ValueKey('gefecht-probe-suche')),
    name,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, name).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Talentprobe kostet eine Aktion, Eigenschaftsprobe keine', (
    tester,
  ) async {
    final (container, bestand) = await _ansicht(tester);
    final ctl = container.read(gefechtProvider('rondra').notifier);
    ctl.setzen(
      container.read(gefechtProvider('rondra'))!.copyWith(ansageFolgemalus: 2),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gefecht-probe')));
    await tester.pumpAndSettle();
    await _waehlen(tester, 'Klettern');
    // Vorgabe für Talente: eine Aktion.
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const ValueKey('gefecht-zeitbedarf-aktion')),
          )
          .selected,
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('gefecht-talentprobe-starten')));
    await tester.pumpAndSettle();
    expect(bestand.anfragen.last.type, ProbeType.talent);
    expect(bestand.anfragen.last.basePool, 7);
    expect(bestand.anfragen.last.ruleHint, contains('Ansagefolgemalus'));
    var s = container.read(gefechtProvider('rondra'))!;
    expect(s.angriffeVerbraucht + s.paradenVerbraucht, 1);
    expect(s.ansageFolgemalus, 2);
    expect(s.auftrag, isNull);

    // Strg+K öffnet dieselbe Auswahl; MU kostet keine Aktion.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    await _waehlen(tester, 'MU');
    await tester.tap(find.byKey(const ValueKey('gefecht-talentprobe-starten')));
    await tester.pumpAndSettle();
    expect(bestand.anfragen.last.type, ProbeType.attribute);
    final nachher = container.read(gefechtProvider('rondra'))!;
    expect(
      nachher.angriffeVerbraucht + nachher.paradenVerbraucht,
      s.angriffeVerbraucht + s.paradenVerbraucht,
    );
    expect(nachher.freieVerbraucht, s.freieVerbraucht);
  });

  testWidgets('Talenteinsatz bleibt mit verkürzter Restdauer offen', (
    tester,
  ) async {
    final (container, bestand) = await _ansicht(tester);
    bestand.w20Wert = 1;
    await tester.tap(find.byKey(const ValueKey('gefecht-probe')));
    await tester.pumpAndSettle();
    await _waehlen(tester, 'Klettern');
    await tester.tap(
      find.byKey(const ValueKey('gefecht-zeitbedarf-laengerfristig')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Geplante Aktionen'),
      '20',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gefecht-talentprobe-starten')));
    await tester.pumpAndSettle();
    final s = container.read(gefechtProvider('rondra'))!;
    // TaW* 7 bleibt vollständig übrig: 20 − 7 = 13 Aktionen, eine bezahlt.
    expect(s.handlung, isNotNull);
    expect(s.handlung!.verbleibend, 12);
    expect(s.handlung!.titel, contains('Klettern'));
  });

  testWidgets('Abbruch der Probe bucht nichts', (tester) async {
    final (container, bestand) = await _ansicht(tester);
    bestand.abbrechen = true;
    await tester.tap(find.byKey(const ValueKey('gefecht-probe')));
    await tester.pumpAndSettle();
    await _waehlen(tester, 'Klettern');
    await tester.tap(find.byKey(const ValueKey('gefecht-talentprobe-starten')));
    await tester.pumpAndSettle();
    final s = container.read(gefechtProvider('rondra'))!;
    expect(s.angriffeVerbraucht + s.paradenVerbraucht, 0);
    expect(s.auftrag, isNull);
  });
}
