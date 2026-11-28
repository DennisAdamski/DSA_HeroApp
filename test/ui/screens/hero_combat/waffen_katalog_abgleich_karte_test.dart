import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/rules/derived/waffen_katalog_abgleich_rules.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/waffen_katalog_abgleich_karte.dart';

const _waffe = MainWeaponSlot(
  name: 'Meisterschwert',
  weaponType: 'Schwert',
  kkBase: 11,
  kkThreshold: 2,
  tpFlat: 5,
);
const _katalog = WaffenKatalogWerte(
  tpKk: (basis: 12, schwelle: 3),
  tp: (wuerfel: 1, zuschlag: 4),
);
final _abweichung = WaffenKatalogAbweichung(
  slotIndex: 2,
  waffe: _waffe,
  katalogName: 'Schwert',
  katalog: _katalog,
  abweichungen: vergleicheWaffeMitKatalog(_waffe, _katalog),
);

void main() {
  testWidgets('zeigt Meldung und meldet die drei Aktionen', (tester) async {
    final gemeldet = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: WaffenKatalogAbgleichKarte(
              abweichungen: <WaffenKatalogAbweichung>[_abweichung],
              onUebernehmen: (a) => gemeldet.add('mod ${a.slotIndex}'),
              onBearbeiten: (a) => gemeldet.add('edit ${a.slotIndex}'),
              onAkzeptieren: (a) => gemeldet.add('ok ${a.slotIndex}'),
            ),
          ),
        ),
      ),
    );

    expect(
      find.text('Waffenwerte weichen vom Waffenkatalog ab'),
      findsOneWidget,
    );
    expect(find.text(_abweichung.meldung), findsOneWidget);
    expect(
      find.text('Als Modifikation: Verbesserung TP/KK −1/−1, TP +1'),
      findsOneWidget,
    );

    for (final aktion in <String>['mod', 'edit', 'ok']) {
      await tester.tap(
        find.byKey(ValueKey<String>('combat-weapon-katalog-$aktion-2')),
      );
      await tester.pump();
    }
    expect(gemeldet, <String>['mod 2', 'edit 2', 'ok 2']);
  });

  testWidgets('zeigt ohne Abweichungen nichts', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WaffenKatalogAbgleichKarte(
            abweichungen: const <WaffenKatalogAbweichung>[],
            onUebernehmen: (_) {},
            onBearbeiten: (_) {},
            onAkzeptieren: (_) {},
          ),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('combat-weapon-katalog-abgleich')),
      findsNothing,
    );
  });
}
