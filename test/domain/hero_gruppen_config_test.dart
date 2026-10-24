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

  test('primaer wird nur bei Belegung geschrieben und übersteht das Laden', () {
    const normal = HeroGruppenMitgliedschaft(
      gruppenCode: 'g',
      kontoGruppe: true,
    );
    expect(normal.toJson().containsKey('primaer'), isFalse);
    expect(
      HeroGruppenMitgliedschaft.fromJson(<String, dynamic>{'gruppenCode': 'g'})
          .primaer,
      isFalse,
    );

    final primaer = normal.copyWith(primaer: true);
    expect(primaer.toJson()['primaer'], isTrue);
    final geladen = HeroGruppenMitgliedschaft.fromJson(primaer.toJson());
    expect(geladen.primaer, isTrue);
    expect(geladen.copyWith(gruppenName: 'X').primaer, isTrue);
    expect(
      geladen.copyWith(primaer: false).toJson().containsKey('primaer'),
      isFalse,
    );
  });

  test('kontoGruppe übersteht Speichern und Laden', () {
    const neu = HeroGruppenMitgliedschaft(gruppenCode: 'g', kontoGruppe: true);
    final geladen = HeroGruppenMitgliedschaft.fromJson(neu.toJson());
    expect(geladen.kontoGruppe, isTrue);
    expect(geladen.copyWith(gruppenName: 'X').kontoGruppe, isTrue);
  });
}
