import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_angriff.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_fremdwirkung.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_gegner.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_begegnung_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_initiative_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_ansicht.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_fremdwirkung.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_manoeverfolge.dart';

import '../../test_support/bogen_test_repository.dart';
import '../shell/karto_test_support.dart';
import 'gefecht_test_support.dart';

// Review R13: Gefechtsdialoge auf dem schmalsten üblichen Telefon
// (320 × 568 logische Pixel) ohne Überlauf.

const _schmal = Size(320, 568);
const _langerName = 'Ork-Häuptling Grimmzahn der Unbezwingbare';

HeroSheet _held() => testHero().copyWith(
  combatConfig: const CombatConfig(
    weapons: [
      MainWeaponSlot(
        id: 'a',
        name: 'Schwert',
        distanceClass: 'N',
        breakFactor: 1,
      ),
    ],
  ),
  inventoryEntries: const [
    HeroInventoryEntry(
      gegenstand: 'Heiltrank',
      anzahl: '2',
      itemType: InventoryItemType.verbrauchsgegenstand,
    ),
  ],
);

void _schmalesFenster(WidgetTester tester) {
  tester.view.physicalSize = _schmal;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

// Gefechtsansicht im schmalen Fenster mit einem Gegner.
Future<ProviderContainer> _ansicht(WidgetTester tester) async {
  _schmalesFenster(tester);
  final held = _held();
  const zustand = HeroState(
    currentLep: 30,
    currentAsp: 0,
    currentKap: 0,
    currentAu: 30,
  );
  final repo = BogenTestRepository(heroes: [held], states: {'rondra': zustand});
  final snapshot = buildHeroComputedSnapshot(
    hero: held,
    state: zustand,
    catalog: testCatalog,
    epicAdvantagesActive: false,
  );
  final c = ProviderContainer(
    overrides: [
      heroRepositoryProvider.overrideWithValue(repo),
      heroComputedProvider('rondra').overrideWith((ref) => AsyncData(snapshot)),
      rulesCatalogProvider.overrideWith((ref) async => testCatalog),
    ],
  );
  addTearDown(c.dispose);
  c.read(gefechtProvider('rondra').notifier).beginnen(6, dk: 'N');
  c
      .read(gefechtBegegnungProvider.notifier)
      .speichern(
        const Gefechtsgegner(
          id: 'g',
          name: _langerName,
          lep: 20,
          rs: 3,
          ini: 9,
        ),
      );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        home: GefechtAnsicht(heroId: 'rondra', bestand: GefechtsTestBestand()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

Future<void> _tippe(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

// Leere Seite im schmalen Fenster; liefert den Kontext für Dialoge.
Future<(BuildContext, ProviderContainer)> _leer(WidgetTester tester) async {
  _schmalesFenster(tester);
  final c = ProviderContainer();
  addTearDown(c.dispose);
  late BuildContext kontext;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) {
              kontext = ctx;
              return const SizedBox();
            },
          ),
        ),
      ),
    ),
  );
  return (kontext, c);
}

void main() {
  testWidgets('Ansicht mit Gegner und gemeinsamer Initiative', (tester) async {
    final c = await _ansicht(tester);
    c
        .read(gefechtInitiativeProvider.notifier)
        .hinzufuegen('rondra', zeitpunktVorbei: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Gemeinsame nächste Runde'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Manuelle Korrektur mit langer Verlustart', (tester) async {
    await _ansicht(tester);
    await _tippe(tester, find.text('Manuelle Korrektur'));
    await _tippe(tester, find.text('Ungeklärter Verlust'));
    await _tippe(tester, find.text('Kampfverlust (rückgewinnbar)').last);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Probenwahl, Zeitbedarf und Aktionswahl', (tester) async {
    await _ansicht(tester);
    await _tippe(tester, find.byKey(const ValueKey('gefecht-leiste-probe')));
    expect(tester.takeException(), isNull);
    await _tippe(tester, find.text('MU'));
    expect(tester.takeException(), isNull);
    await _tippe(tester, find.text('Abbrechen'));
    await _tippe(tester, find.byKey(const ValueKey('gefecht-aktionswahl')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Inventar und Benutzung', (tester) async {
    await _ansicht(tester);
    await _tippe(tester, find.byKey(const ValueKey('gefecht-inventar')));
    expect(tester.takeException(), isNull);
    await _tippe(tester, find.widgetWithText(TextButton, 'Benutzen'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Gegnerdialog und Treffer', (tester) async {
    await _ansicht(tester);
    await _tippe(tester, find.text('Werte ändern'));
    expect(tester.takeException(), isNull);
    await _tippe(tester, find.text('Abbrechen'));
    await _tippe(tester, find.text('Treffer übernehmen'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Bruchtestanlass mit drei langen Antworten', (tester) async {
    await _ansicht(tester);
    await _tippe(tester, find.text('Bruchtest'));
    await _tippe(tester, find.textContaining('Schwert · a'));
    expect(find.text('Tatsächlicher Bruchtestanlass'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Gegenprobe des Umreißens mit langem Standvorteil', (
    tester,
  ) async {
    _schmalesFenster(tester);
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c
        .read(gefechtBegegnungProvider.notifier)
        .speichern(
          const Gefechtsgegner(id: 'g', name: 'Ork', lep: 20, rs: 3, ini: 9),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          home: Scaffold(
            body: GefechtManoeverfolge(
              heroId: 'rondra',
              e: const Gefechtsangriffsergebnis(
                auftragId: 'x',
                kampfmittel: GefechtsKampfmittelwahl(
                  GefechtsKampfmittelArt.hauptwaffe,
                  'a',
                ),
                waffenname: 'Schwert',
                schaden: null,
                abwehrmalus: 0,
                tpBonus: 0,
                gegnerId: 'g',
                manoeverId: 'man_umreissen',
                abwehrGeklaert: true,
                folgeTp: 3,
              ),
              bestand: GefechtsTestBestand(),
              gesperrt: false,
              onAktion: (a) => a(),
            ),
          ),
        ),
      ),
    );
    await _tippe(tester, find.text('Gegnerische GE-Probe'));
    await _tippe(tester, find.text('Keiner'));
    await _tippe(tester, find.text('Herausragende Balance (+8)').last);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Fulminictus: Fremdziel und Schadenswurf', (tester) async {
    final (kontext, _) = await _leer(tester);
    zeigeGefechtsFremdziel(
      context: kontext,
      zauberId: 'spell_fulminictus_donnerkeil',
      gegner: const [
        Gefechtsgegner(id: 'g', name: _langerName, lep: 20, rs: 3, ini: 9),
      ],
      verfuegbareAsp: 20,
      gegnerId: 'g',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    Navigator.of(kontext).pop();
    await tester.pumpAndSettle();
    const probe = ResolvedProbeRequest(
      type: ProbeType.spell,
      title: 'Fulminictus',
      subtitle: '',
      ruleHint: '',
      diceSpec: DiceSpec(count: 3, sides: 20),
      basePool: 8,
      targets: [
        ProbeTargetValue(label: 'KL', value: 14),
        ProbeTargetValue(label: 'GE', value: 12),
        ProbeTargetValue(label: 'KO', value: 13),
      ],
    );
    zeigeGefechtsFremdwirkungswurf(
      context: kontext,
      ziel: const GefechtsFremdwirkung(
        zauberId: 'spell_fulminictus_donnerkeil',
        gegnerId: 'g',
        verfuegbareAsp: 20,
      ),
      probe: evaluateProbe(
        probe,
        const ProbeRollInput(
          mode: ProbeRollMode.manual,
          diceValues: [5, 5, 5],
          situationalModifier: 0,
          specializationApplied: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
