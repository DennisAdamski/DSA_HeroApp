import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_patzer.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_bestands_adapter_impl.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/probe_engine_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_patzer_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/shell/karto_gefechts_adapter.dart';

import '../shell/karto_test_support.dart';
import '../../test_support/bogen_test_repository.dart';

void main() {
  testWidgets('Flüchtige Patzerkarte ist ohne Sitzung gesperrt', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: GefechtPatzer(
              heroId: 'rondra',
              bestand: () => const KartoBestandsAdapterImpl(),
              gesperrt: true,
              onAktion: (aktion) => aktion(),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Bruchtest'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Bruchtest'))
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'Abbruch verbraucht nichts; Kontroll-/Tabellencallback jeweils einmal',
    (tester) async {
      final fixture = await _start(tester);
      final f = fixture.adapter;
      final c = fixture.container;
      f.wuerfe.add(null);
      await tester.tap(find.text('Patzer-Kontrollwurf'));
      await tester.pumpAndSettle();
      expect(c.read(gefechtProvider('rondra'))!.paradenVerbraucht, 0);
      expect(c.read(gefechtPatzerProvider('rondra')).patzer!.kontrolle, isNull);
      f.wuerfe.add([20]);
      await tester.tap(find.text('Patzer-Kontrollwurf'));
      await tester.pumpAndSettle();
      expect(c.read(gefechtPatzerProvider('rondra')).verloreneRunde, 1);
      expect(c.read(gefechtProvider('rondra'))!.paradenVerbraucht, 2);
      f.wuerfe.add([3, 4]);
      await tester.tap(find.text('Patzertabelle · 2W6'));
      await tester.pumpAndSettle();
      expect(c.read(gefechtPatzerProvider('rondra')).patzer!.tabelle, 7);
      await tester.tap(find.text('Patzerfolgen übernehmen'));
      await tester.pumpAndSettle();
      expect(c.read(gefechtProvider('rondra'))!.iniVerlust, 2);
      expect(c.read(gefechtPatzerProvider('rondra')).patzer!.erledigt, true);
      expect(f.proben, 3);
      c.read(gefechtProvider('rondra').notifier).beenden();
      expect(c.read(gefechtPatzerProvider('rondra')).patzer, isNull);
    },
  );

  testWidgets(
    'Gelungene Kontrolle bleibt ursprünglicher Fehlschlag ohne Restverlust',
    (tester) async {
      final f = await _start(tester);
      f.adapter.wuerfe.add([1]);
      await tester.tap(find.text('Patzer-Kontrollwurf'));
      await tester.pumpAndSettle();
      final stand = f.container.read(gefechtPatzerProvider('rondra'));
      expect(stand.patzer!.erledigt, true);
      expect(stand.patzer!.original.success, false);
      expect(stand.verloreneRunde, isNull);
      expect(f.container.read(gefechtProvider('rondra'))!.paradenVerbraucht, 0);
    },
  );

  testWidgets(
    'Bruchtest friert Wurf ein, weist frische BF-Änderung ab und wiederholt Schreiben',
    (tester) async {
      final f = await _start(tester, patzer: false);
      await tester.tap(find.text('Bruchtest'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Schwert · w1 · BF 3'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('Ansage ≥10 / Schildspalter / Waffe zerbrechen'),
      );
      await tester.pumpAndSettle();
      f.adapter.wuerfe.add([3, 4]);
      await tester.tap(find.text('Bruchtest · 2W6'));
      await tester.pumpAndSettle();
      f.adapter.fehler = true;
      await tester.tap(find.text('Bruchtestergebnis übernehmen'));
      await tester.pumpAndSettle();
      expect(f.adapter.config.weaponSlots.single.breakFactor, 3);
      expect(f.container.read(gefechtPatzerProvider('rondra')).bruch!.wurf, 7);
      f.adapter.fehler = false;
      f.adapter.config = f.adapter.config.copyWith(
        weapons: [f.adapter.config.weaponSlots.single.copyWith(breakFactor: 4)],
      );
      await tester.tap(find.text('Bruchtestergebnis übernehmen'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('BF oder Waffenprofil geändert'),
        findsOneWidget,
      );
      expect(f.adapter.config.weaponSlots.single.breakFactor, 4);
      f.adapter.config = f.adapter.config.copyWith(
        weapons: [f.adapter.config.weaponSlots.single.copyWith(breakFactor: 3)],
      );
      await tester.tap(find.text('Bruchtestergebnis übernehmen'));
      await tester.pumpAndSettle();
      expect(f.adapter.config.weaponSlots.single.breakFactor, 4);
      expect(
        f.adapter.config.weaponSlots.single.unbekannteFelder['future'],
        42,
      );
      expect(f.adapter.proben, 1);
      expect(
        f.container.read(gefechtPatzerProvider('rondra')).bruch!.erledigt,
        true,
      );
    },
  );

  testWidgets('Fehlgeschlagener Bruchtest sperrt ohne Löschung', (
    tester,
  ) async {
    final f = await _start(tester, patzer: false);
    await tester.tap(find.text('Bruchtest'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Schwert · w1 · BF 3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kritischer Treffer abgewehrt'));
    await tester.pumpAndSettle();
    f.adapter.wuerfe.add([1, 2]);
    await tester.tap(find.text('Bruchtest · 2W6'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bruchtestergebnis übernehmen'));
    await tester.pumpAndSettle();
    expect(f.adapter.config.weaponSlots.single.id, 'w1');
    expect(
      f.container
          .read(gefechtPatzerProvider('rondra'))
          .gesperrteMittel['waffe:w1'],
      'Schwert zerbrochen',
    );
  });
}

// Realer Compute-Pfad und flüchtiger Controller; nur Dialogwürfe werden ersetzt.
Future<({ProviderContainer container, _Adapter adapter})> _start(
  WidgetTester tester, {
  bool patzer = true,
}) async {
  const config = CombatConfig(
    weapons: [
      MainWeaponSlot(
        id: 'w1',
        name: 'Schwert',
        breakFactor: 3,
        unbekannteFelder: {'future': 42},
      ),
    ],
  );
  final hero = testHero().copyWith(combatConfig: config);
  final repo = BogenTestRepository(
    heroes: [hero],
    states: {'rondra': const HeroState.empty()},
  );
  final c = ProviderContainer(
    overrides: [
      heroRepositoryProvider.overrideWithValue(repo),
      rulesCatalogProvider.overrideWith((ref) async => testCatalog),
    ],
  );
  addTearDown(c.dispose);
  final a = _Adapter(config);
  late WidgetRef ref;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Consumer(
              builder: (ctx, r, _) {
                ref = r;
                r.watch(heroComputedProvider('rondra'));
                return GefechtPatzer(
                  heroId: 'rondra',
                  bestand: () => a,
                  gesperrt: false,
                  onAktion: (aktion) => aktion(),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  c.read(gefechtProvider('rondra').notifier).beginnen(6);
  if (patzer) {
    final r = evaluateProbe(
      const ResolvedProbeRequest(
        type: ProbeType.combatAttack,
        title: 'Schwert-AT',
        subtitle: '',
        ruleHint: '',
        diceSpec: DiceSpec(count: 1, sides: 20),
        targets: [ProbeTargetValue(label: 'AT', value: 12)],
      ),
      const ProbeRollInput(
        mode: ProbeRollMode.manual,
        diceValues: [20],
        situationalModifier: 0,
        specializationApplied: false,
      ),
    );
    starteGefechtsPatzer(
      ref: ref,
      heroId: 'rondra',
      auftragId: 'a',
      result: r,
      kampfmittel: const GefechtsKampfmittelwahl(
        GefechtsKampfmittelArt.hauptwaffe,
        'w1',
      ),
    );
    // Derselbe tatsächliche Auftrag darf nicht doppelt eingereiht werden.
    starteGefechtsPatzer(
      ref: ref,
      heroId: 'rondra',
      auftragId: 'a',
      result: r,
      kampfmittel: const GefechtsKampfmittelwahl(
        GefechtsKampfmittelArt.hauptwaffe,
        'w1',
      ),
    );
  }
  await tester.pumpAndSettle();
  return (container: c, adapter: a);
}

class _Adapter implements KartoGefechtsAdapter {
  _Adapter(this.config);
  CombatConfig config;
  final List<List<int>?> wuerfe = [];
  int proben = 0;
  bool fehler = false;
  @override
  Future<ProbeResult?> gefechtsProbe({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required ResolvedProbeRequest request,
    void Function(ProbeResult)? onResolved,
  }) async {
    proben++;
    final w = wuerfe.removeAt(0);
    if (w == null) return null;
    final r = evaluateProbe(
      request,
      ProbeRollInput(
        mode: ProbeRollMode.manual,
        diceValues: w,
        situationalModifier: 0,
        specializationApplied: false,
      ),
    );
    onResolved?.call(r);
    onResolved?.call(r);
    return r;
  }

  @override
  Future<bool> gefechtsAusruestung({
    required BuildContext context,
    required WidgetRef ref,
    required String heroId,
    required CombatConfig Function(CombatConfig) aenderung,
  }) async {
    final neu = aenderung(config);
    if (fehler) return false;
    config = neu;
    return true;
  }
}
