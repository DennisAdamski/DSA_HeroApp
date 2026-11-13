import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dsa_heldenverwaltung/catalog/ort_loader.dart';
import 'package:dsa_heldenverwaltung/data/avesmaps/avesmaps_client.dart';
import 'package:dsa_heldenverwaltung/data/avesmaps/avesmaps_orte_speicher.dart';
import 'package:dsa_heldenverwaltung/data/avesmaps/avesmaps_orte_repository.dart';
import 'package:dsa_heldenverwaltung/domain/avesmaps_ort.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/state/avesmaps_providers.dart';
import 'package:dsa_heldenverwaltung/state/ort_providers.dart';

class _Speicher implements AvesmapsOrteSpeicher {
  _Speicher([this.liste]);

  AvesmapsOrtsliste? liste;

  @override
  Future<AvesmapsOrtsliste?> lade() async => liste;

  @override
  Future<void> merke(AvesmapsOrtsliste neu) async => liste = neu;
}

const String _garethId = '80558060-4299-54aa-b520-814b10819885';

void main() {
  test('erneute Anforderung lädt nach Retry-After, ohne frische Liste neu abzurufen', () async {
    var jetzt = DateTime.utc(2026, 11, 13);
    var anfragen = 0;
    final client = AvesmapsClient(
      httpClient: MockClient((_) async {
        anfragen++;
        if (anfragen == 1) {
          return http.Response('', 503, headers: {'retry-after': '1200'});
        }
        return http.Response(
          '{"orte":[{"id":"g","name":"Gareth","x":551,"y":533}]}',
          200,
        );
      }),
    );
    addTearDown(client.close);
    final repository = AvesmapsOrteRepository(
      client: client,
      speicher: _Speicher(),
      jetzt: () => jetzt,
    );
    final container = ProviderContainer(
      overrides: [
        avesmapsOrteRepositoryProvider.overrideWith((ref) async => repository),
      ],
    );
    addTearDown(container.dispose);
    final anforderung = container.read(
      avesmapsOrteAnforderungProvider.notifier,
    );
    anforderung.fordereAn();
    expect(await container.read(avesmapsOrteProvider.future), isEmpty);
    jetzt = jetzt.add(const Duration(minutes: 16));
    anforderung.fordereAn();
    expect(await container.read(avesmapsOrteProvider.future), isEmpty);
    expect(anfragen, 1);
    jetzt = jetzt.add(const Duration(minutes: 4));
    anforderung.fordereAn();
    final orte = await container.read(avesmapsOrteProvider.future);
    expect(orte.map((ort) => ort.name), <String>['Gareth']);
    expect(anfragen, 2);
    anforderung.fordereAn();
    expect(await container.read(avesmapsOrteProvider.future), isNotEmpty);
    expect(anfragen, 2);
  });

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

  test('vor der Anforderung gilt nur die lokal gespeicherte Liste, ohne '
      'Netz', () async {
    var anfragen = 0;
    final container = ProviderContainer(
      overrides: [
        avesmapsAktivProvider.overrideWithValue(true),
        avesmapsClientProvider.overrideWithValue(
          AvesmapsClient(
            httpClient: MockClient((_) async {
              anfragen++;
              return http.Response('', 503);
            }),
          ),
        ),
        avesmapsOrteSpeicherProvider.overrideWith(
          (ref) async => _Speicher(
            AvesmapsOrtsliste(
              orte: const <AvesmapsOrt>[
                AvesmapsOrt(id: _garethId, name: 'Gareth', x: 551.6, y: 533),
              ],
              // Alt: nach der Anforderung würde neu geladen.
              abgerufen: DateTime.utc(2020),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final orte = await container.read(avesmapsOrteProvider.future);

    expect(orte.single.name, 'Gareth');
    expect(container.read(avesmapsOnlineSucheProvider), isNull);
    expect(
      await container.read(avesmapsOrtsdetailsProvider(_garethId).future),
      isNull,
    );
    expect(anfragen, 0);
  });

  test(
    'ohne lokale Liste bleibt das Verzeichnis vor der Anforderung leer',
    () async {
      final container = ProviderContainer(
        overrides: [
          avesmapsAktivProvider.overrideWithValue(true),
          avesmapsOrteSpeicherProvider.overrideWith((ref) async => _Speicher()),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(avesmapsOrteProvider.future), isEmpty);
      expect(container.read(avesmapsOnlineSucheProvider), isNull);
    },
  );

  test('Ortsdetails nach der Anforderung, je Ort einmal; Fehler ergeben '
      'null', () async {
    final angefragt = <String>[];
    final container = ProviderContainer(
      overrides: [
        avesmapsAktivProvider.overrideWithValue(true),
        avesmapsOrteSpeicherProvider.overrideWith((ref) async => _Speicher()),
        avesmapsClientProvider.overrideWithValue(
          AvesmapsClient(
            httpClient: MockClient((anfrage) async {
              angefragt.add(anfrage.url.path);
              if (anfrage.url.path.endsWith(_garethId)) {
                return http.Response.bytes(
                  utf8.encode(
                    jsonEncode(<String, Object?>{
                      'id': _garethId,
                      'name': 'Gareth',
                      'art': 'metropole',
                      'x': 551.625,
                      'y': 532.969,
                      'wiki': <String, Object?>{
                        'url': 'https://de.wiki-aventurica.de/wiki/Gareth',
                      },
                    }),
                  ),
                  200,
                );
              }
              return http.Response('', 503);
            }),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(avesmapsOrteAnforderungProvider.notifier).fordereAn();

    final details = await container.read(
      avesmapsOrtsdetailsProvider(_garethId).future,
    );
    await container.read(avesmapsOrtsdetailsProvider(_garethId).future);
    container.read(avesmapsOrteAnforderungProvider.notifier).fordereAn();
    await container.read(avesmapsOrtsdetailsProvider(_garethId).future);
    const andere = '5acdf435-80fc-4a34-980f-41020b31a8d3';

    expect(details?.wikiUrl, 'https://de.wiki-aventurica.de/wiki/Gareth');
    expect(
      await container.read(avesmapsOrtsdetailsProvider(andere).future),
      isNull,
    );
    expect(angefragt.where((w) => w.endsWith(_garethId)), hasLength(1));
  });

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
