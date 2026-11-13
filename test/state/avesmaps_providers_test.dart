import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/ort_loader.dart';
import 'package:dsa_heldenverwaltung/domain/avesmaps_ort.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/state/avesmaps_providers.dart';
import 'package:dsa_heldenverwaltung/state/ort_providers.dart';

void main() {
  final wiki = OrtKatalog(
    orte: <OrtEintrag>[
      OrtEintrag(name: 'Gareth', art: OrtArt.siedlung, region: 'Garetien'),
      OrtEintrag(name: 'Garetien', art: OrtArt.region),
    ],
  );

  test('ohne Override ist der Abruf aus: kein Client, keine Online-Suche, '
      'auch nach der Anforderung', () async {
    final container = ProviderContainer(
      overrides: [ortKatalogProvider.overrideWith((ref) async => wiki)],
    );
    addTearDown(container.dispose);

    container.read(avesmapsOrteAnforderungProvider.notifier).fordereAn();

    expect(container.read(avesmapsClientProvider), isNull);
    expect(await container.read(avesmapsOrteProvider.future), isEmpty);
    expect(container.read(avesmapsOnlineSucheProvider), isNull);
    await container.read(ortKatalogProvider.future);
    expect(container.read(ortsverzeichnisProvider), same(wiki.orte));
  });

  test(
    'vor der Anforderung bleibt das Ortsverzeichnis von Avesmaps leer',
    () async {
      final container = ProviderContainer(
        overrides: [avesmapsAktivProvider.overrideWithValue(true)],
      );
      addTearDown(container.dispose);

      expect(await container.read(avesmapsOrteProvider.future), isEmpty);
      expect(container.read(avesmapsOnlineSucheProvider), isNull);
    },
  );

  test('die Auswahlliste mischt beide Verzeichnisse, sobald Avesmaps '
      'vorliegt', () async {
    final container = ProviderContainer(
      overrides: [
        ortKatalogProvider.overrideWith((ref) async => wiki),
        avesmapsOrteProvider.overrideWith(
          (ref) async => const <AvesmapsOrt>[
            AvesmapsOrt(id: 'g', name: 'Gareth', x: 551.6, y: 533),
            AvesmapsOrt(id: 'p', name: 'Punin', art: 'grossstadt', x: 1, y: 2),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(ortKatalogProvider.future);
    await container.read(avesmapsOrteProvider.future);

    final orte = container.read(ortsverzeichnisProvider);

    expect(orte.map((o) => o.name), <String>['Gareth', 'Garetien', 'Punin']);
    expect(orte.first.ortId, 'g');
    expect(orte.first.region, 'Garetien');
    expect(orte[1].hatKartenposition, isFalse);
    expect(orte.last.unterart, 'Großstadt');
  });
}
