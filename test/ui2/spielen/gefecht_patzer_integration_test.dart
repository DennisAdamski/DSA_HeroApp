import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_patzer.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_auftrag_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_initiative_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_patzer_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_aktion_ausfuehren.dart';

import '../../rules/gefecht_ansagen_paket2_test.dart' as fixture;
import '../shell/karto_test_support.dart';
import 'gefecht_test_support.dart';

void main() {
  testWidgets(
    'Echte Fehl-AT öffnet Patzer einmal und sperrt weitere Aktionen',
    (tester) async {
      final snap = fixture.ansageSnapshot(sf: true);
      final c = ProviderContainer(
        overrides: [
          heroComputedProvider('rondra').overrideWith((ref) => AsyncData(snap)),
          rulesCatalogProvider.overrideWith((ref) async => testCatalog),
        ],
      );
      addTearDown(c.dispose);
      await c.read(rulesCatalogProvider.future);
      final bestand = GefechtsTestBestand()
        ..w20Wert = 20
        ..doppelt = true;
      c.read(gefechtProvider('rondra').notifier).beginnen(6, dk: 'N');
      const auftrag = GefechtAuftrag(
        aktion: Gefechtsaktion.angriff,
        titel: 'Angreifen',
        zuschlag: 0,
        dk: 'N',
        dauer: 1,
        kosten: 1,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (ctx, ref, _) => TextButton(
                  onPressed: () => fuehreGefechtsAuftragAus(
                    context: ctx,
                    ref: ref,
                    heroId: 'rondra',
                    bestand: bestand,
                    k: testCatalog,
                    auftrag: auftrag,
                  ),
                  child: const Text('AT'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('AT'));
      await tester.pumpAndSettle();
      final stand = c.read(gefechtPatzerProvider('rondra'));
      expect(stand.patzer, isNotNull);
      expect(stand.verarbeiteteAuftraege.length, 1);
      expect(c.read(gefechtProvider('rondra'))!.angriffeVerbraucht, 1);
      final s = c.read(gefechtMitInitiativeProvider('rondra'))!;
      const pa = GefechtAuftrag(
        aktion: Gefechtsaktion.parade,
        titel: 'Parieren',
        zuschlag: 0,
        dk: 'N',
        dauer: 1,
        kosten: 1,
      );
      expect(
        pruefeGefechtAuftrag(s, snap, testCatalog, pa).status,
        Gefechtsfreigabe.gesperrt,
      );
      c.read(gefechtProvider('rondra').notifier).beenden();
      expect(c.read(gefechtPatzerProvider('rondra')).patzer, isNull);
    },
  );

  test('Defektes Mittel sperrt nur seine physische ID über nächste Runde', () {
    final snap = fixture.ansageSnapshot(sf: true);
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(gefechtProvider('rondra').notifier).beginnen(6, dk: 'N');
    final id = snap.hero.combatConfig.selectedWeapon.id;
    c
        .read(gefechtPatzerProvider('rondra').notifier)
        .setzen(
          GefechtsPatzerstand(
            gesperrteMittel: {'waffe:$id': 'Waffe zerbrochen'},
          ),
        );
    final s = c.read(gefechtMitInitiativeProvider('rondra'))!;
    const auftrag = GefechtAuftrag(
      aktion: Gefechtsaktion.angriff,
      titel: 'Angreifen',
      zuschlag: 0,
      dk: 'N',
      dauer: 1,
      kosten: 1,
    );
    final p = pruefeGefechtAuftrag(s, snap, testCatalog, auftrag);
    expect(p.sperrgruende, contains('Waffe zerbrochen'));
    expect(p.status, Gefechtsfreigabe.gesperrt);
    c.read(gefechtProvider('rondra').notifier).setzen(naechsteGefechtsrunde(s));
    expect(
      pruefeGefechtAuftrag(
        c.read(gefechtMitInitiativeProvider('rondra'))!,
        snap,
        testCatalog,
        auftrag,
      ).sperrgruende,
      contains('Waffe zerbrochen'),
    );
    c.read(gefechtProvider('rondra').notifier).beenden();
    c.read(gefechtProvider('rondra').notifier).beginnen(6, dk: 'N');
    expect(c.read(gefechtPatzerProvider('rondra')).gesperrteMittel, isEmpty);
  });
}
