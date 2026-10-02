import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_orientieren.dart';

import '../shell/karto_test_support.dart';
import 'gefecht_test_support.dart';

void main() {
  testWidgets('Orientieren würfelt erst am Ende und übernimmt einmalig INI', (
    tester,
  ) async {
    final snapshot = buildHeroComputedSnapshot(
      hero: testHero(),
      state: const HeroState.empty(),
      catalog: testCatalog,
      epicAdvantagesActive: false,
    );
    final container = ProviderContainer(
      overrides: [
        heroComputedProvider('rondra')
            .overrideWith((ref) => AsyncData(snapshot)),
      ],
    );
    addTearDown(container.dispose);
    final c = container.read(gefechtProvider('rondra').notifier);
    c.beginnen(1);
    c.setzen(
      container.read(gefechtProvider('rondra'))!.copyWith(iniVerlust: 4),
    );
    final bestand = GefechtsTestBestand()..doppelt = true;
    late BuildContext context;
    late WidgetRef ref;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (ctx, r, _) {
              context = ctx;
              ref = r;
              return const Scaffold();
            },
          ),
        ),
      ),
    );
    final start = zeigeOrientieren(
      context: context,
      ref: ref,
      heroId: 'rondra',
      bestand: bestand,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ungestört beginnen'));
    await tester.pumpAndSettle();
    await start;
    expect(bestand.anfragen, isEmpty);
    expect(
      container.read(gefechtProvider('rondra'))!.handlung!.art,
      Gefechtshandlungsart.orientieren,
    );
    await fuehreOrientierungFort(
      context: context,
      ref: ref,
      heroId: 'rondra',
      bestand: bestand,
    );
    expect(bestand.anfragen.length, 1);
    final s = container.read(gefechtProvider('rondra'))!;
    expect(s.iniWurf, 6);
    expect(s.iniVerlust, 0);
    expect(s.angriffeVerbraucht + s.paradenVerbraucht, 2);
    expect(s.handlung, isNull);
  });
}
