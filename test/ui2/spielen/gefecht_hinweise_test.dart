import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/combat_special_rules.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_kontextfelder.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_ladedialog.dart';

import '../../rules/gefecht_laden_rules_test.dart' as fixture;
import '../shell/karto_test_support.dart';

void main() {
  const ladeHinweis = ValueKey('gefecht-laden-axxeleratus-hinweis');
  const ausweichHinweis = ValueKey('gefecht-ausweichen-umkreisung-hinweis');

  Future<void> zeigeLadedialog(WidgetTester t, HeroComputedSnapshot snap) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GefechtLadedialog(
            zustand: const Gefechtszustand(iniWurf: 6),
            snapshot: snap,
            kampfmittel: fixture.mittel,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('Ladedialog weist bei aktivem Axxeleratus auf die FF-Probe hin', (
    t,
  ) async {
    final basis = fixture.ladeSnapshot();
    final mitAxx = buildHeroComputedSnapshot(
      hero: basis.hero.copyWith(
        combatConfig: basis.hero.combatConfig.copyWith(
          specialRules: const CombatSpecialRules(axxeleratusActive: true),
        ),
      ),
      state: const HeroState.empty(),
      catalog: testCatalog,
      epicAdvantagesActive: false,
    );

    await zeigeLadedialog(t, mitAxx);
    expect(find.byKey(ladeHinweis), findsOneWidget);
    expect(find.textContaining('FF-Probe'), findsOneWidget);

    await zeigeLadedialog(t, basis);
    expect(find.byKey(ladeHinweis), findsNothing);
  });

  testWidgets('Ausweichen weist auf Erschwernis und Umkreisung hin', (t) async {
    Future<void> zeige(Gefechtsaktion aktion) => t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GefechtKontextfelder(
            kontext: const Gefechtskontext(),
            aktion: aktion,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    await zeige(Gefechtsaktion.freiesAusweichen);
    expect(find.byKey(ausweichHinweis), findsOneWidget);
    expect(find.textContaining('Umkreisung (4 Teilnehmer)'), findsOneWidget);

    await zeige(Gefechtsaktion.gezieltesAusweichen);
    expect(find.byKey(ausweichHinweis), findsOneWidget);

    await zeige(Gefechtsaktion.parade);
    expect(find.byKey(ausweichHinweis), findsNothing);
  });
}
