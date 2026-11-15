import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dsa_heldenverwaltung/data/avesmaps/avesmaps_client.dart';
import 'package:dsa_heldenverwaltung/data/avesmaps/avesmaps_orte_repository.dart';
import 'package:dsa_heldenverwaltung/data/avesmaps/avesmaps_orte_speicher.dart';
import 'package:dsa_heldenverwaltung/domain/avesmaps_ort.dart';

class _SpeicherImArbeitsspeicher implements AvesmapsOrteSpeicher {
  AvesmapsOrtsliste? liste;
  bool kaputt = false;

  @override
  Future<AvesmapsOrtsliste?> lade() async {
    if (kaputt) throw StateError('Box nicht lesbar');
    return liste;
  }

  @override
  Future<void> merke(AvesmapsOrtsliste neu) async {
    if (kaputt) throw StateError('Box nicht schreibbar');
    liste = neu;
  }
}

http.Response _orte(List<String> namen) => http.Response.bytes(
  utf8.encode(
    jsonEncode(<String, Object?>{
      'orte': <Object?>[
        for (final name in namen)
          <String, Object?>{'id': 'id-$name', 'name': name, 'x': 1, 'y': 2},
      ],
    }),
  ),
  200,
);

void main() {
  late DateTime uhr;
  late int anfragen;
  late http.Response Function() antwort;
  late _SpeicherImArbeitsspeicher speicher;
  late AvesmapsOrteRepository repository;

  setUp(() {
    uhr = DateTime.utc(2026, 11, 13, 8);
    anfragen = 0;
    antwort = () => _orte(<String>['Gareth']);
    speicher = _SpeicherImArbeitsspeicher();
    repository = AvesmapsOrteRepository(
      client: AvesmapsClient(
        httpClient: MockClient((_) async {
          anfragen++;
          return antwort();
        }),
      ),
      speicher: speicher,
      jetzt: () => uhr,
    );
  });

  test('lädt beim ersten Aufruf und merkt die Liste', () async {
    final liste = await repository.ladeOrte();

    expect(anfragen, 1);
    expect(liste!.orte.single.name, 'Gareth');
    expect(liste.abgerufen, uhr);
    expect(speicher.liste!.orte.single.id, 'id-Gareth');
  });

  test('fragt innerhalb eines Tages nicht erneut', () async {
    await repository.ladeOrte();
    uhr = uhr.add(const Duration(hours: 23, minutes: 59));

    final liste = await repository.ladeOrte();

    expect(anfragen, 1);
    expect(liste!.orte.single.name, 'Gareth');
  });

  test('frischt nach einem Tag auf', () async {
    await repository.ladeOrte();
    uhr = uhr.add(const Duration(hours: 24));
    antwort = () => _orte(<String>['Gareth', 'Havena']);

    final liste = await repository.ladeOrte();

    expect(anfragen, 2);
    expect(liste!.orte, hasLength(2));
    expect(speicher.liste!.abgerufen, uhr);
  });

  test('gleichzeitige Aufrufe teilen sich einen Abruf', () async {
    final ergebnisse = await Future.wait(<Future<AvesmapsOrtsliste?>>[
      repository.ladeOrte(),
      repository.ladeOrte(),
      repository.ladeOrte(),
    ]);

    expect(anfragen, 1);
    expect(ergebnisse.every((liste) => liste != null), isTrue);
  });

  test('behält die alte Liste, wenn das Auffrischen scheitert', () async {
    await repository.ladeOrte();
    uhr = uhr.add(const Duration(days: 2));
    antwort = () => http.Response('', 500);

    final liste = await repository.ladeOrte();

    expect(anfragen, 2);
    expect(liste!.orte.single.name, 'Gareth');
    expect(speicher.liste!.abgerufen, DateTime.utc(2026, 11, 13, 8));
  });

  test('ohne Liste und ohne Netz kommt null, nicht sofort ein neuer '
      'Versuch', () async {
    antwort = () => http.Response('', 500);

    expect(await repository.ladeOrte(), isNull);
    expect(await repository.ladeOrte(), isNull);
    expect(anfragen, 1);

    // Nach der Pause wird wieder gefragt.
    uhr = uhr.add(const Duration(minutes: 15));
    antwort = () => _orte(<String>['Gareth']);
    expect((await repository.ladeOrte())!.orte, hasLength(1));
    expect(anfragen, 2);
  });

  test('achtet die Wartezeit der Drossel', () async {
    antwort = () => http.Response(
      '',
      429,
      headers: <String, String>{'retry-after': '3600'},
    );
    expect(await repository.ladeOrte(), isNull);

    antwort = () => _orte(<String>['Gareth']);
    uhr = uhr.add(const Duration(minutes: 59));
    expect(await repository.ladeOrte(), isNull);
    expect(anfragen, 1);

    uhr = uhr.add(const Duration(minutes: 1));
    expect(await repository.ladeOrte(), isNotNull);
    expect(anfragen, 2);
  });

  test('eine leere Antwort ersetzt keine brauchbare Liste', () async {
    await repository.ladeOrte();
    uhr = uhr.add(const Duration(days: 1));
    antwort = () => _orte(<String>[]);

    final liste = await repository.ladeOrte();

    expect(liste!.orte.single.name, 'Gareth');
    expect(speicher.liste!.orte, hasLength(1));
  });

  test('ein defekter Zwischenspeicher verhindert die Liste nicht', () async {
    speicher.kaputt = true;

    final liste = await repository.ladeOrte();

    expect(liste!.orte.single.name, 'Gareth');
    // Ohne Ablage gilt die Liste für die Sitzung und wird nicht bei jedem
    // Aufruf neu geladen.
    expect((await repository.ladeOrte())!.orte.single.name, 'Gareth');
    expect(anfragen, 1);
  });

  group('HiveAvesmapsOrteSpeicher', () {
    late Directory wurzel;
    late HiveAvesmapsOrteSpeicher hive;

    setUp(() async {
      wurzel = await Directory.systemTemp.createTemp('dsa_avesmaps_orte_');
      hive = HiveAvesmapsOrteSpeicher(speicherPfad: wurzel.path);
    });

    tearDown(() async {
      await hive.close();
      if (await wurzel.exists()) await wurzel.delete(recursive: true);
    });

    test('ist anfangs leer', () async {
      expect(await hive.lade(), isNull);
    });

    test('legt die Liste ab und liest sie nach dem Schließen wieder', () async {
      await hive.merke(
        AvesmapsOrtsliste(
          orte: const <AvesmapsOrt>[
            AvesmapsOrt(
              id: 'a',
              name: 'Gareth',
              art: 'metropole',
              x: 551.625,
              y: 532.969,
            ),
            AvesmapsOrt(id: 'b', name: 'Angbar', x: 1, y: 2),
          ],
          abgerufen: DateTime.utc(2026, 11, 13, 8, 30),
        ),
      );
      await hive.close();

      final gelesen = await hive.lade();

      expect(gelesen!.abgerufen, DateTime.utc(2026, 11, 13, 8, 30));
      expect(gelesen.orte.map((o) => o.name), <String>['Gareth', 'Angbar']);
      expect(gelesen.orte.first.art, 'metropole');
      expect(gelesen.orte.first.x, 551.625);
      expect(gelesen.orte.last.art, '');
    });

    test('ein unlesbarer Eintrag zählt als leer', () async {
      final box = await Hive.openBox<String>(
        'avesmaps_orte_v1',
        path: wurzel.path,
      );
      await box.put('orte', 'kein json');

      expect(await hive.lade(), isNull);
    });
  });
}
