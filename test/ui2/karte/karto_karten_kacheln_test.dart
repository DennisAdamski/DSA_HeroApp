import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/karte/karten_kachel_manifest.dart';
import 'package:dsa_heldenverwaltung/ui2/karte/karto_karten_kacheln.dart';

// Zählt Anfragen und scheitert jedes Mal, wie bei einem Netzabriss.
class _AusfallClient implements HttpClient {
  int anfragen = 0;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    anfragen++;
    throw const SocketException('Netz weg');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  final manifest = KartenKachelManifest(
    basis: Uri.parse('https://karte.example'),
    revision: 'r1',
    maxZoom: 2,
  );

  testWidgets('eine fehlgeschlagene Kachel wird erst nach der Wartezeit neu '
      'angefragt', (tester) async {
    final client = _AusfallClient();
    debugNetworkImageHttpClientProvider = () => client;
    var jetzt = DateTime.utc(2026, 11, 16, 12);
    final speicher = KartenKachelSpeicher(
      wartezeit: const Duration(seconds: 30),
      uhr: () => jetzt,
    )..manifest = manifest;
    addTearDown(speicher.dispose);
    const kachel = (1, 0, 0);

    Future<void> frage() async {
      await tester.runAsync(() async {
        speicher.benoetige(const <KachelNummer>[kachel]);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
    }

    try {
      await frage();
      expect(client.anfragen, 1);

      // Innerhalb der Wartezeit bleibt es bei einem Versuch.
      jetzt = jetzt.add(const Duration(seconds: 10));
      await frage();
      expect(client.anfragen, 1);

      // Danach kommt die Kachel beim nächsten Bedarf erneut.
      jetzt = jetzt.add(const Duration(seconds: 25));
      await frage();
      expect(client.anfragen, 2);
    } finally {
      // Muss vor dem Ende des Tests zurückgesetzt sein (Painting-Invariante).
      debugNetworkImageHttpClientProvider = null;
    }
  });
}
