import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_gruppen_config.dart';

void main() {
  test(
    'kontoGruppe wird nur bei Belegung geschrieben (Hash von Bestandshelden)',
    () {
      const alt = HeroGruppenMitgliedschaft(gruppenCode: 'g', gruppenName: 'N');
      expect(alt.toJson().containsKey('kontoGruppe'), isFalse);
      expect(
        HeroGruppenMitgliedschaft.fromJson(<String, dynamic>{
          'gruppenCode': 'g',
        }).kontoGruppe,
        isFalse,
      );
    },
  );

  test('kontoGruppe übersteht Speichern und Laden', () {
    const neu = HeroGruppenMitgliedschaft(gruppenCode: 'g', kontoGruppe: true);
    final geladen = HeroGruppenMitgliedschaft.fromJson(neu.toJson());
    expect(geladen.kontoGruppe, isTrue);
    expect(geladen.copyWith(gruppenName: 'X').kontoGruppe, isTrue);
  });
}
