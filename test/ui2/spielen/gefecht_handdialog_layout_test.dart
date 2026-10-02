import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_aktionsdialog.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_ausruestung.dart';

import '../shell/karto_test_support.dart';
import 'gefecht_test_support.dart';

void main() {
  for (final breite in [390.0, 820.0, 1200.0, 1440.0]) {
    for (final hell in Brightness.values) {
      for (final popup in [false, true]) {
        testWidgets(
          'Hand-/Abwehrdialog $breite $hell Popup=$popup mit Tastatur',
          (tester) async {
            tester.view.physicalSize = Size(breite, 1000);
            tester.view.devicePixelRatio = 1;
            tester.view.viewInsets = const FakeViewPadding(bottom: 250);
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetViewInsets);
            final snapshot = buildHeroComputedSnapshot(
              hero: testHero().copyWith(
                combatConfig: const CombatConfig(
                  weapons: [
                    MainWeaponSlot(
                      id: 'a',
                      name: 'Schwert',
                      distanceClass: 'N',
                    ),
                    MainWeaponSlot(id: 'b', name: 'Dolch', distanceClass: 'H'),
                  ],
                  offhandEquipment: [
                    OffhandEquipmentEntry(
                      id: 'p',
                      name: 'Linkhanddolch',
                      paMod: 2,
                    ),
                  ],
                  offhandAssignment: OffhandAssignment(equipmentIndex: 0),
                  specialRules: CombatSpecialRules(
                    linkhandActive: true,
                    parierwaffenII: true,
                  ),
                ),
              ),
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
            final ctl = container.read(gefechtProvider('rondra').notifier)
              ..beginnen(6);
            final zustand = container
                .read(gefechtProvider('rondra'))!
                .copyWith(
                  dk: 'N',
                  kontext: const Gefechtskontext(
                    angriffsart: Gefechtsangriffsart.nahkampf,
                    finte: 0,
                    paradeVerboten: false,
                  ),
                );
            ctl.setzen(zustand);
            late BuildContext context;
            late WidgetRef ref;
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  theme: ThemeData(brightness: hell),
                  home: Consumer(
                    builder: (c, r, _) {
                      context = c;
                      ref = r;
                      return Scaffold(
                        body: popup
                            ? const SizedBox()
                            : GefechtAktionsdialog(
                                zustand: zustand,
                                werte: snapshot,
                                katalog: testCatalog,
                                aktion: Gefechtsaktion.parade,
                                titel: 'Parieren',
                              ),
                      );
                    },
                  ),
                ),
              ),
            );
            Future<void>? offen;
            if (popup) {
              offen = zeigeGefechtsausruestung(
                context: context,
                ref: ref,
                heroId: 'rondra',
                bestand: GefechtsTestBestand(),
              );
            }
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            if (popup) {
              expect(find.text('Haupthand'), findsOneWidget);
              expect(find.text('Nebenhand'), findsOneWidget);
              await tester.tap(find.text('Schließen'));
              await tester.pumpAndSettle();
              await offen;
            } else {
              final dropdown = find.byKey(
                const ValueKey('gefecht-kampfmittel'),
              );
              expect(
                tester
                    .widget<DropdownButtonFormField<GefechtsKampfmittelArt>>(
                      dropdown,
                    )
                    .initialValue,
                GefechtsKampfmittelArt.parierwaffe,
              );
              tester
                  .widget<DropdownButtonFormField<GefechtsKampfmittelArt>>(
                    dropdown,
                  )
                  .onChanged!(GefechtsKampfmittelArt.hauptwaffe);
              await tester.pumpAndSettle();
              expect(
                tester
                    .widget<DropdownButtonFormField<GefechtsKampfmittelArt>>(
                      dropdown,
                    )
                    .initialValue,
                GefechtsKampfmittelArt.hauptwaffe,
              );
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
