import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/hive_vorgangsjournal.dart';

void main() {
  Future<String> createTempPath() async {
    final root = await Directory.systemTemp.createTemp(
      'dsa_vorgangsjournal_test_',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    return root.path;
  }

  test('offene Vorgänge überdauern das Schließen der Box samt '
      'verschachtelter Werte', () async {
    final path = await createTempPath();

    final erstes = await HiveVorgangsjournal.create(storagePath: path);
    await erstes.merke('v-1', {
      'art': 'heldImportieren',
      'dateien': ['a.png', 'b.png'],
      'zustand': {
        'currentLep': 21,
        'wpiZustand': {'kopf': 1},
      },
      'heldHashVorher': null,
    });
    await erstes.close();

    final zweites = await HiveVorgangsjournal.create(storagePath: path);
    addTearDown(zweites.close);
    final offen = await zweites.offene();

    expect(offen.keys, ['v-1']);
    final eintrag = offen['v-1']!;
    expect(eintrag['dateien'], ['a.png', 'b.png']);
    expect((eintrag['zustand']! as Map)['currentLep'], 21);
    expect(((eintrag['zustand']! as Map)['wpiZustand'] as Map)['kopf'], 1);
    expect(eintrag.containsKey('heldHashVorher'), isTrue);
  });

  test('merke ersetzt den Eintrag, erledige entfernt ihn', () async {
    final journal = await HiveVorgangsjournal.create(
      storagePath: await createTempPath(),
    );
    addTearDown(journal.close);

    await journal.merke('v-1', {'schritt': 'bilderAblegen'});
    await journal.merke('v-1', {'schritt': 'heldGespeichert'});
    expect((await journal.offene())['v-1'], {'schritt': 'heldGespeichert'});

    await journal.erledige('v-1');
    await journal.erledige('fehlt');
    expect(await journal.offene(), isEmpty);
  });
}
