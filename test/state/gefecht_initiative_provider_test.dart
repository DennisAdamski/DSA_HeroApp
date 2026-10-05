import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_gegner.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_begegnung_provider.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_initiative_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_initiative_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';

import '../rules/gefecht_ansagen_paket2_test.dart' as fixture;
import '../ui2/shell/karto_test_support.dart';

void main() {
  test(
    'Explizite abgeschlossene Phase gibt den nächsten Zeitpunkt frei',
    () async {
      final snap = fixture.ansageSnapshot(sf: true);
      final c = ProviderContainer(
        overrides: [
          heroComputedProvider('a').overrideWith((ref) => AsyncData(snap)),
          rulesCatalogProvider.overrideWith((ref) async => testCatalog),
        ],
      );
      addTearDown(c.dispose);
      await c.read(rulesCatalogProvider.future);
      c.read(gefechtProvider('a').notifier).beginnen(6, dk: 'N');
      final gruppe = c.read(gefechtInitiativeProvider.notifier);
      gruppe.hinzufuegen('a', zeitpunktVorbei: false);
      c
          .read(gefechtBegegnungProvider.notifier)
          .speichern(
            const Gefechtsgegner(id: 'g', name: 'Ork', lep: 20, rs: 3, ini: 99),
          );
      gruppe.phaseSetzen(99);
      gruppe.abschliessen('gegner:g');
      expect(
        c.read(gefechtMitInitiativeProvider('a'))!.initiativphase,
        gefechtsInitiative(
          c.read(gefechtProvider('a'))!,
          gefechtswerteFuer(snap, katalog: testCatalog),
        ),
      );
    },
  );

  test(
    'Fehlende Teilnehmerspielwerte sperren Gruppenaktionen bis Wiederkehr',
    () async {
      final snap = fixture.ansageSnapshot(sf: true);
      final status = StateProvider<AsyncValue<HeroComputedSnapshot>>(
        (ref) => AsyncData(snap),
      );
      final c = ProviderContainer(
        overrides: [
          heroComputedProvider('a').overrideWith((ref) => AsyncData(snap)),
          heroComputedProvider('b').overrideWith((ref) => ref.watch(status)),
          rulesCatalogProvider.overrideWith((ref) async => testCatalog),
        ],
      );
      addTearDown(c.dispose);
      await c.read(rulesCatalogProvider.future);
      final gruppe = c.read(gefechtInitiativeProvider.notifier);
      for (final id in ['a', 'b']) {
        c.read(gefechtProvider(id).notifier).beginnen(6, dk: 'N');
        gruppe.hinzufuegen(id, zeitpunktVorbei: false);
      }
      c.read(status.notifier).state = const AsyncLoading();
      final w = gefechtswerteFuer(snap, katalog: testCatalog);
      final s = c.read(gefechtMitInitiativeProvider('a'))!;
      expect(
        gefechtsZeitsperre(s, w, Gefechtsaktion.angriff),
        contains('Spielwerte'),
      );
      expect(() => gruppe.naechsteRunde(), throwsStateError);
      expect(c.read(gefechtProvider('a'))!.runde, 1);
      c.read(status.notifier).state = AsyncData(snap);
      expect(
        gefechtsZeitsperre(
          c.read(gefechtMitInitiativeProvider('a'))!,
          w,
          Gefechtsaktion.angriff,
        ),
        isNull,
      );
    },
  );

  test(
    'Konkurrierende Reserven haben echte ursprüngliche INI-Priorität',
    () async {
      final snap = fixture.ansageSnapshot(sf: true);
      final w = gefechtswerteFuer(snap, katalog: testCatalog);
      final c = ProviderContainer(
        overrides: [
          heroComputedProvider('a').overrideWith((ref) => AsyncData(snap)),
          heroComputedProvider('b').overrideWith((ref) => AsyncData(snap)),
          rulesCatalogProvider.overrideWith((ref) async => testCatalog),
        ],
      );
      addTearDown(c.dispose);
      await c.read(rulesCatalogProvider.future);
      final gruppe = c.read(gefechtInitiativeProvider.notifier);
      for (final id in ['a', 'b']) {
        final ctl = c.read(gefechtProvider(id).notifier);
        ctl.beginnen(id == 'a' ? 6 : 2, dk: 'N');
        gruppe.hinzufuegen(id, zeitpunktVorbei: false);
        final s = c.read(gefechtProvider(id))!;
        ctl.setzen(
          reserviereGefechtsaktion(s, w).copyWith(reserveBereit: true),
        );
      }
      gruppe.phaseSetzen(5);
      final b = c.read(gefechtMitInitiativeProvider('b'))!;
      expect(
        gefechtsZeitsperre(b, w, Gefechtsaktion.angriff),
        contains('Reserve'),
      );
      expect(
        gefechtsZeitsperre(
          c.read(gefechtMitInitiativeProvider('a'))!,
          w,
          Gefechtsaktion.angriff,
        ),
        isNull,
      );
    },
  );

  test(
    'Begonnene Dauerhandlung behält eigenen Zeitpunkt für restliche PA',
    () async {
      final snap = fixture.ansageSnapshot(sf: true);
      final w = gefechtswerteFuer(snap, katalog: testCatalog);
      final c = ProviderContainer(
        overrides: [
          heroComputedProvider('a').overrideWith((ref) => AsyncData(snap)),
          rulesCatalogProvider.overrideWith((ref) async => testCatalog),
        ],
      );
      addTearDown(c.dispose);
      await c.read(rulesCatalogProvider.future);
      final ctl = c.read(gefechtProvider('a').notifier);
      ctl.beginnen(6, dk: 'N');
      c
          .read(gefechtInitiativeProvider.notifier)
          .hinzufuegen('a', zeitpunktVorbei: false);
      ctl.setzen(
        c
            .read(gefechtProvider('a'))!
            .copyWith(
              angriffeVerbraucht: 1,
              handlung: const Gefechtshandlung(titel: 'Laden', verbleibend: 1),
            ),
      );
      expect(
        gefechtsZeitsperre(
          c.read(gefechtMitInitiativeProvider('a'))!,
          w,
          Gefechtsaktion.handlung,
        ),
        isNull,
      );
    },
  );
  test(
    'Zwei Helden und Gegner führen Phasen frisch, Rundenwechsel ist gemeinsam',
    () async {
      final snap = fixture.ansageSnapshot(sf: true);
      final c = ProviderContainer(
        overrides: [
          heroComputedProvider('a').overrideWith((ref) => AsyncData(snap)),
          heroComputedProvider('b').overrideWith((ref) => AsyncData(snap)),
          rulesCatalogProvider.overrideWith((ref) async => testCatalog),
        ],
      );
      addTearDown(c.dispose);
      await c.read(rulesCatalogProvider.future);
      for (final id in ['a', 'b']) {
        c.read(gefechtProvider(id).notifier).beginnen(6);
      }
      final gruppe = c.read(gefechtInitiativeProvider.notifier);
      gruppe.hinzufuegen('a', zeitpunktVorbei: false);
      gruppe.hinzufuegen('b', zeitpunktVorbei: false);
      c
          .read(gefechtBegegnungProvider.notifier)
          .speichern(
            const Gefechtsgegner(id: 'g', name: 'Ork', lep: 20, rs: 3, ini: 99),
          );
      expect(c.read(gefechtMitInitiativeProvider('a'))!.initiativphase, 99);
      expect(
        gefechtsZeitsperre(
          c.read(gefechtMitInitiativeProvider('a'))!,
          gefechtswerteFuer(snap, katalog: testCatalog),
          Gefechtsaktion.angriff,
        ),
        isNotNull,
      );
      gruppe.abschliessen('gegner:g');
      final phase = c.read(gefechtMitInitiativeProvider('a'))!.initiativphase;
      expect(phase, isNot(99));
      final a = c.read(gefechtProvider('a').notifier);
      expect(a.reservieren('offen'), isTrue);
      expect(() => gruppe.naechsteRunde(), throwsStateError);
      expect(c.read(gefechtProvider('b'))!.runde, 1);
      a.abbrechen('offen');
      gruppe.naechsteRunde();
      expect(c.read(gefechtProvider('a'))!.runde, 2);
      expect(c.read(gefechtProvider('b'))!.runde, 2);
      expect(c.read(gefechtMitInitiativeProvider('a'))!.initiativphase, 99);
    },
  );
}
