import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/catalog_providers.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kampf_aenderung_rules.dart';
import 'package:dsa_heldenverwaltung/ui/bridges/karto_bestands_adapter_impl.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_ausruestung.dart';

import '../shell/karto_test_support.dart';
import '../../test_support/bogen_test_repository.dart';

const _a = MainWeaponSlot(id: 'w1', name: 'Schwert', distanceClass: 'N');
const _b = MainWeaponSlot(
  id: 'w2',
  name: 'Dolch',
  distanceClass: 'H',
  unbekannteFelder: {
    'future': 17,
    'sourceRef': {'id': 'i-7'},
  },
);
const _helm = ArmorPiece(
  id: 'a1',
  name: 'Helm',
  unbekannteFelder: {'future': 21},
);

void main() {
  for (final fehler in [false, true]) {
    testWidgets(
      'Verzögerter Waffenwechsel mit frischem Stand; Speicherfehler=$fehler',
      (tester) async {
        final hero = testHero().copyWith(
          combatConfig: const CombatConfig(
            weapons: [_a, _b],
            armor: ArmorConfig(pieces: [_helm]),
            unbekannteFelder: {'future': 42},
          ),
        );
        final repo = BogenTestRepository(
          heroes: [hero],
          states: {'rondra': const HeroState.empty()},
        );
        final container = ProviderContainer(
          overrides: [
            heroRepositoryProvider.overrideWithValue(repo),
            rulesCatalogProvider.overrideWith((ref) async => testCatalog),
          ],
        );
        addTearDown(container.dispose);
        late WidgetRef ref;
        late BuildContext context;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (ctx, r, _) {
                    ref = r;
                    context = ctx;
                    r.watch(heroComputedProvider('rondra'));
                    return const SizedBox();
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        const bestand = KartoBestandsAdapterImpl();
        final controller = container.read(gefechtProvider('rondra').notifier);
        controller.beginnen(6);
        expect(
          await starteGefechtswaffenwechsel(
            context: context,
            ref: ref,
            heroId: 'rondra',
            bestand: bestand,
            waffe: _b,
            index: 1,
            dauer: 3,
          ),
          true,
        );
        expect(
          (await repo.gespeichert('rondra')).combatConfig.selectedWeapon.id,
          'w1',
        );
        expect(
          container.read(gefechtProvider('rondra'))!.handlung!.verbleibend,
          2,
        );
        await setzeGefechtsausruestungFort(
          context: context,
          ref: ref,
          heroId: 'rondra',
          bestand: bestand,
        );
        expect(
          container.read(gefechtProvider('rondra'))!.handlung!.verbleibend,
          1,
        );
        expect(
          container.read(gefechtProvider('rondra'))!.handlung!.waffe?.id,
          'w2',
        );
        controller.setzen(
          naechsteGefechtsrunde(container.read(gefechtProvider('rondra'))!),
        );
        expect(container.read(gefechtProvider('rondra'))!.auftrag, isNull);
        expect(
          container.read(gefechtProvider('rondra'))!.handlung!.waffe!.id,
          'w2',
        );
        expect(
          container.read(heroComputedProvider('rondra')).asData,
          isNotNull,
        );
        repo.fremdeAenderung = (held) => held.copyWith(
          name: 'Frisch',
          combatConfig: held.combatConfig.copyWith(
            weapons: [_b, _a],
            selectedWeaponIndex: 1,
          ),
        );
        repo.schreibFehler = fehler;
        if (fehler) {
          await expectLater(
            setzeGefechtsausruestungFort(
              context: context,
              ref: ref,
              heroId: 'rondra',
              bestand: bestand,
            ),
            throwsStateError,
          );
          expect(
            container.read(gefechtProvider('rondra'))!.handlung!.verbleibend,
            1,
          );
          expect(
            container.read(gefechtProvider('rondra'))!.angriffeVerbraucht,
            0,
          );
        } else {
          await setzeGefechtsausruestungFort(
            context: context,
            ref: ref,
            heroId: 'rondra',
            bestand: bestand,
          );
          final gespeichert = await repo.gespeichert('rondra');
          expect(gespeichert.name, 'Frisch');
          expect(gespeichert.combatConfig.selectedWeapon.id, 'w2');
          expect(
            gespeichert.combatConfig.selectedWeapon.unbekannteFelder,
            _b.unbekannteFelder,
          );
          expect(gespeichert.combatConfig.unbekannteFelder['future'], 42);
          expect(container.read(gefechtProvider('rondra'))!.handlung, isNull);
          expect(
            await bestand.gefechtsAusruestung(
              context: context,
              ref: ref,
              heroId: 'rondra',
              aenderung: (c) => mitRuestungsteil(
                c,
                _helm.copyWith(isActive: true),
                ausgang: _helm,
              ),
            ),
            true,
          );
          final teil = (await repo.gespeichert('rondra'))
              .combatConfig
              .armor
              .pieces
              .single;
          expect(teil.id, 'a1');
          expect(teil.unbekannteFelder['future'], 21);
          expect(teil.isActive, true);
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
