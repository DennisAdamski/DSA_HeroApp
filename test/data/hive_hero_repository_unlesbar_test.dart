import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:dsa_heldenverwaltung/data/hive_hero_repository.dart';
import 'package:dsa_heldenverwaltung/data/unlesbare_helden_quelle.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';

void main() {
  Future<String> createTempPath() async {
    final root = await Directory.systemTemp.createTemp('dsa_hive_unlesbar_');
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    return root.path;
  }

  const attribute = Attributes(
    mu: 12,
    kl: 12,
    inn: 12,
    ch: 12,
    ff: 12,
    ge: 12,
    ko: 12,
    kk: 12,
  );

  test('ein unlesbarer Held verhindert das Öffnen der übrigen nicht und '
      'bleibt unangetastet (MODELL-02)', () async {
    final path = await createTempPath();
    final erstes = await HiveHeroRepository.create(storagePath: path);
    await erstes.saveHero(
      const HeroSheet(
        id: 'gut',
        name: 'Alrik',
        level: 1,
        attributes: attribute,
      ),
    );
    await erstes.close();

    // Ein Eintrag, den `HeroSheet.fromJson` nicht lesen kann.
    const kaputt = <String, dynamic>{'id': 'kaputt', 'name': 5, 'talents': 'x'};
    final box = await Hive.openBox<Map>('heroes_v1', path: path);
    await box.put('kaputt', kaputt);
    await box.close();

    final zweites = await HiveHeroRepository.create(storagePath: path);

    expect((await zweites.listHeroes()).map((h) => h.id), <String>['gut']);
    expect(await zweites.loadHeroById('kaputt'), isNull);
    expect(zweites.unlesbareHelden, <String>['kaputt']);
    // Der Rohname ist kein Text; die Anzeige fällt auf den Schlüssel zurück.
    expect(zweites.unlesbareHeldenEintraege, const <UnlesbarerHeld>[
      UnlesbarerHeld(schluessel: 'kaputt'),
    ]);

    // Die Rohdaten bleiben für eine spätere Version oder Reparatur liegen.
    await zweites.saveHero(
      const HeroSheet(
        id: 'gut',
        name: 'Alrik 2',
        level: 1,
        attributes: attribute,
      ),
    );
    await zweites.close();
    final nachher = await Hive.openBox<Map>('heroes_v1', path: path);
    addTearDown(nachher.close);
    expect(nachher.get('kaputt'), kaputt);
  });

  test('ein lesbarer Rohname benennt den unlesbaren Eintrag', () async {
    final path = await createTempPath();
    final box = await Hive.openBox<Map>('heroes_v1', path: path);
    await box.put('h1', <String, dynamic>{
      'id': 'h1',
      'name': 'Alrike',
      'talents': 'x',
    });
    await box.close();

    final repository = await HiveHeroRepository.create(storagePath: path);
    addTearDown(repository.close);

    expect(repository.unlesbareHeldenEintraege, const <UnlesbarerHeld>[
      UnlesbarerHeld(schluessel: 'h1', name: 'Alrike'),
    ]);
  });
}
