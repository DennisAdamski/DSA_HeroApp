import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_auftrag_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_angriff_rules.dart';

import 'gefecht_ansagen_paket2_test.dart' as fixture;
import '../ui2/shell/karto_test_support.dart';

void main() {
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
    final request = gefechtsSchadenFuerAngriff(e);
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
