import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_angriff.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_auftrag_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_angriff_rules.dart';

import 'gefecht_ansagen_paket2_test.dart' as fixture;
import '../ui2/shell/karto_test_support.dart';

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
    test('${m.name} erhält keinen gewöhnlichen Schadensrequest', () {
      final snap = fixture.ansageSnapshot(sf: true);
      final a = GefechtAuftrag(
        aktion: Gefechtsaktion.angriff,
        titel: m.name,
        zuschlag: 0,
        dk: 'N',
        dauer: 1,
        kosten: 1,
        manoever: m,
      );
      final p = pruefeGefechtAuftrag(
        const Gefechtszustand(iniWurf: 6),
        snap,
        testCatalog,
        a,
      );
      expect(p.ausfuehrbar, isTrue);
      final e = gefechtsAngriffsergebnisNachBuchung(
        auftragId: m.id,
        buchungErfolgreich: true,
        erfolg: true,
        snapshot: snap,
        katalog: testCatalog,
        auftrag: a,
        pruefung: p,
      )!;
      expect(gefechtsSchadenFuerAngriff(e), isNull);
      expect(e.schaden, isNull);
      expect(
        e.schadensfolge,
        m.id == 'man_ungeklaerte_variante'
            ? GefechtsSchadensfolge.manuell
            : GefechtsSchadensfolge.keinSchaden,
      );
    });
  }
  for (final hammer in [false, true]) {
    test(
      'Ansagemetadaten bleiben bei ${hammer ? 'Hammerschlag' : 'manueller Variante'} erhalten',
      () {
        final snap = fixture.ansageSnapshot(sf: true, talent: 'tal_hiebwaffen');
        final m = ManeuverDef(
          id: hammer ? 'man_hammerschlag' : 'man_ungeklaerte_variante',
          name: hammer ? 'Hammerschlag' : 'Ungeklärte Variante',
          typ: 'Angriffsaktion',
        );
        final a = GefechtAuftrag(
          aktion: Gefechtsaktion.angriff,
          titel: m.name,
          zuschlag: 0,
          dk: 'N',
          dauer: 1,
          kosten: 1,
          manoever: m,
          finte: 1,
          wuchtschlag: 3,
        );
        final p = pruefeGefechtAuftrag(
          const Gefechtszustand(iniWurf: 6),
          snap,
          testCatalog,
          a,
        );
        final e = gefechtsAngriffsergebnisNachBuchung(
          auftragId: m.id,
          buchungErfolgreich: true,
          erfolg: true,
          snapshot: snap,
          katalog: testCatalog,
          auftrag: a,
          pruefung: p,
        )!;
        expect(e.abwehrmalus, 1);
        expect(e.tpBonus, 3);
        final request = gefechtsSchadenFuerAngriff(e);
        if (hammer) {
          expect(
            request!.diceSpec.modifier,
            snap.combatPreviewStats.damageDiceSpec.modifier + 3,
          );
          expect(request.ruleHint, contains('gesamte'));
          expect(request.ruleHint, contains('verdreifachen'));
        } else {
          expect(request, isNull);
          expect(e.hinweis, contains('Schadensfolge manuell'));
        }
      },
    );
  }
  test('Nur gebuchter erfolgreicher Angriff erhält seinen TP-Bonus', () {
    final snap = fixture.ansageSnapshot(sf: true);
    const a = GefechtAuftrag(
      aktion: Gefechtsaktion.angriff,
      titel: 'AT',
      zuschlag: 0,
      dk: 'N',
      dauer: 1,
      kosten: 1,
      wuchtschlag: 5,
      finte: 3,
    );
    final p = pruefeGefechtAuftrag(
      const Gefechtszustand(iniWurf: 6),
      snap,
      testCatalog,
      a,
    );
    for (final erfolg in [false, true]) {
      final e = gefechtsAngriffsergebnisNachBuchung(
        auftragId: 'at1',
        buchungErfolgreich: false,
        erfolg: erfolg,
        snapshot: snap,
        katalog: testCatalog,
        auftrag: a,
        pruefung: p,
      );
      expect(e, isNull);
    }
    final fehl = gefechtsAngriffsergebnisNachBuchung(
      auftragId: 'at1',
      buchungErfolgreich: true,
      erfolg: false,
      snapshot: snap,
      katalog: testCatalog,
      auftrag: a,
      pruefung: p,
    );
    expect(fehl, isNull);
    final e = gefechtsAngriffsergebnisNachBuchung(
      auftragId: 'at1',
      buchungErfolgreich: true,
      erfolg: true,
      snapshot: snap,
      katalog: testCatalog,
      auftrag: a,
      pruefung: p,
    )!;
    expect(e.kampfmittel.id, 'a');
    expect(e.abwehrmalus, 3);
    expect(e.tpBonus, 5);
    final request = gefechtsSchadenFuerAngriff(e)!;
    expect(
      request.diceSpec.modifier,
      snap.combatPreviewStats.damageDiceSpec.modifier + 5,
    );
    expect(
      snap.combatPreviewStats.damageDiceSpec.modifier,
      isNot(request.diceSpec.modifier),
    );
    expect(request.subtitle, contains('Schwert'));
  });
}
