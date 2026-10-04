import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_auftrag_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_angriff_rules.dart';
import 'package:dsa_heldenverwaltung/state/gefecht_provider.dart';
import 'package:dsa_heldenverwaltung/ui2/gefecht/gefecht_angriffsergebnis.dart';

import '../../rules/gefecht_ansagen_paket2_test.dart' as fixture;
import '../shell/karto_test_support.dart';
import 'gefecht_test_support.dart';

void main() {
  for (final m in const [
    ManeuverDef(
      id: 'man_entwaffnen',
      name: 'Entwaffnen',
      typ: 'Angriffsaktion',
    ),
    ManeuverDef(id: 'man_umreissen', name: 'Umreißen', typ: 'Angriffsaktion'),
    ManeuverDef(
      id: 'man_ungeklaerte_variante',
      name: 'Ungeklärte Variante',
      typ: 'Angriffsaktion',
    ),
  ]) {
    testWidgets('${m.name}: Folgen ohne unzulässigen Schadensbutton', (
      tester,
    ) async {
      final snap = fixture.ansageSnapshot(sf: true);
      const s = Gefechtszustand(iniWurf: 6);
      final a = GefechtAuftrag(
        aktion: Gefechtsaktion.angriff,
        titel: m.name,
        zuschlag: 0,
        dk: 'N',
        dauer: 1,
        kosten: 1,
        manoever: m,
      );
      final p = pruefeGefechtAuftrag(s, snap, testCatalog, a);
      final e = gefechtsAngriffsergebnisNachBuchung(
        auftragId: m.id,
        buchungErfolgreich: true,
        erfolg: true,
        snapshot: snap,
        katalog: testCatalog,
        auftrag: a,
        pruefung: p,
      )!;
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ctl = container.read(gefechtProvider('rondra').notifier)
        ..beginnen(6);
      ctl.setzen(ergaenzeGefechtsAngriffsergebnis(s, e));
      final normal = GefechtAuftrag(
        aktion: Gefechtsaktion.angriff,
        titel: 'Normaler Angriff',
        zuschlag: 0,
        dk: 'N',
        dauer: 1,
        kosten: 1,
      );
      final andererTreffer = gefechtsAngriffsergebnisNachBuchung(
        auftragId: 'offener-treffer',
        buchungErfolgreich: true,
        erfolg: true,
        snapshot: snap,
        katalog: testCatalog,
        auftrag: normal,
        pruefung: pruefeGefechtAuftrag(s, snap, testCatalog, normal),
      )!;
      ctl.setzen(
        ergaenzeGefechtsAngriffsergebnis(
          container.read(gefechtProvider('rondra'))!,
          andererTreffer,
        ),
      );
      final bestand = GefechtsTestBestand();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: GefechtAngriffsergebnisAnzeige(
                ergebnis: e,
                heroId: 'rondra',
                bestand: bestand,
                gesperrt: false,
                onAktion: (aktion) => aktion(),
              ),
            ),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('gefecht-angriffsschaden')),
        findsNothing,
      );
      expect(find.textContaining('Schaden dieses Angriffs'), findsNothing);
      expect(
        find.textContaining(
          m.id == 'man_ungeklaerte_variante'
              ? 'Schadensfolge manuell'
              : 'Kein Schaden',
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('gefecht-angriffsfolgen-abschliessen')),
      );
      await tester.pumpAndSettle();
      expect(bestand.anfragen, isEmpty);
      expect(
        container
            .read(gefechtProvider('rondra'))!
            .angriffsergebnisse
            .single
            .auftragId,
        'offener-treffer',
      );
    });
  }
}
