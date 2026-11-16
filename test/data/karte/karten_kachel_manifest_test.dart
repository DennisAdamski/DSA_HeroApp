import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dsa_heldenverwaltung/data/karte/karten_kachel_manifest.dart';

final Uri _basis = Uri.parse('https://karten.example.org/aventurien/');

const Map<String, Object?> _roh = <String, Object?>{
  'serie': 'modern',
  'revision': '3f9a1c0b7d2e',
  'maxZoom': 5,
  'tileSize': 512,
  'format': 'webp',
  'nennung': <String>['Kartenmaterial © Ulisses Spiele', '  '],
  'lizenzUri': 'https://de.wiki-aventurica.de/wiki/Kartenpaket/Lizenz',
  'logo': 'dsa-fanprojekt.png',
  'unbekannt': true,
};

void main() {
  test('liest das Manifest und baut Kachelpfade unter der Revision', () {
    final m = KartenKachelManifest.ausJson(_basis, _roh)!;
    expect(m.maxZoom, 5);
    expect(m.serie, 'modern');
    expect(m.nennung, <String>['Kartenmaterial © Ulisses Spiele']);
    expect(
      m.kachel(3, 2, 7).toString(),
      'https://karten.example.org/aventurien/3f9a1c0b7d2e/3/2/7.webp',
    );
    expect(
      m.logoAdresse.toString(),
      'https://karten.example.org/aventurien/3f9a1c0b7d2e/dsa-fanprojekt.png',
    );
  });

  test('ohne gültige Revision oder Zoomstufe kein Manifest', () {
    expect(
      KartenKachelManifest.ausJson(_basis, <String, Object?>{
        ..._roh,
        'revision': '../x',
      }),
      isNull,
    );
    expect(
      KartenKachelManifest.ausJson(_basis, <String, Object?>{
        ..._roh,
        'maxZoom': 12,
      }),
      isNull,
    );
    expect(KartenKachelManifest.ausJson(_basis, 'kaputt'), isNull);
  });

  test('ein Pfad im Logo wird nicht übernommen', () {
    final m = KartenKachelManifest.ausJson(_basis, <String, Object?>{
      ..._roh,
      'logo': '../../boese.png',
    })!;
    expect(m.logoAdresse, isNull);
  });

  test('lädt aktuell.json; Fehler ergeben null statt einer Ausnahme', () async {
    final anfragen = <Uri>[];
    final gut = MockClient((anfrage) async {
      anfragen.add(anfrage.url);
      return http.Response.bytes(utf8.encode(jsonEncode(_roh)), 200);
    });
    final m = await ladeKartenKachelManifest(_basis, client: gut);
    expect(m?.revision, '3f9a1c0b7d2e');
    expect(
      anfragen.single.toString(),
      'https://karten.example.org/aventurien/aktuell.json',
    );

    final fehlt = MockClient((_) async => http.Response('', 404));
    expect(await ladeKartenKachelManifest(_basis, client: fehlt), isNull);
    final kaputt = MockClient((_) async => http.Response('{', 200));
    expect(await ladeKartenKachelManifest(_basis, client: kaputt), isNull);
    final netz = MockClient((_) async => throw http.ClientException('weg'));
    expect(await ladeKartenKachelManifest(_basis, client: netz), isNull);
  });
}
