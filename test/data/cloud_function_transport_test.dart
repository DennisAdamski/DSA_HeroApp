import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dsa_heldenverwaltung/data/cloud_function_transport.dart';

// REV-11: gemeinsamer Transport der Cloud-Function-Clients.
void main() {
  http.Request? gesendet;
  final client = MockClient((anfrage) async {
    gesendet = anfrage;
    return http.Response('{"code":"OK"}', 200);
  });

  CloudFunctionTransport transport({
    Future<String?> Function()? konto,
    Future<String?> Function()? appCheck,
  }) => CloudFunctionTransport(
    endpoint: Uri.parse('https://example.test/api'),
    idTokenProvider: konto,
    appCheckTokenProvider: appCheck ?? () async => ' check ',
    httpClient: client,
  );

  setUp(() => gesendet = null);

  test('bildet Routen unter dem Endpunkt, leer ist der Endpunkt selbst', () {
    final t = transport();
    expect(t.route('').toString(), 'https://example.test/api');
    expect(t.route('tickets').toString(), 'https://example.test/api/tickets');
  });

  test('setzt Kopfzeilen mit getrimmten Tokens', () async {
    await transport(konto: () async => 'id').postJson(
      Uri.parse('https://example.test/api'),
      <String, String>{'a': 'b'},
    );
    expect(gesendet!.headers['authorization'], 'Bearer id');
    expect(gesendet!.headers['x-firebase-appcheck'], 'check');
    expect(gesendet!.headers['content-type'], startsWith('application/json'));
    expect(gesendet!.body, '{"a":"b"}');
  });

  test('ohne Konto-Provider fehlt die Anmeldung im Kopf', () async {
    await transport().get(Uri.parse('https://example.test/api'));
    expect(gesendet!.headers.containsKey('authorization'), isFalse);
  });

  test('fehlende oder nicht holbare Tokens senden nichts', () async {
    await expectLater(
      transport(konto: () async => null).get(Uri.parse('https://x.test')),
      throwsA(
        isA<CloudFunctionTokenFehlt>().having(
          (f) => f.art,
          'art',
          CloudFunctionTokenArt.konto,
        ),
      ),
    );
    await expectLater(
      transport(appCheck: () async => throw StateError('kaputt'))
          .get(Uri.parse('https://x.test')),
      throwsA(
        isA<CloudFunctionTokenFehlt>().having(
          (f) => f.art,
          'art',
          CloudFunctionTokenArt.appCheck,
        ),
      ),
    );
    expect(gesendet, isNull);
  });

  test('liest nur JSON-Objekte', () {
    expect(CloudFunctionTransport.leseJson('{"code":"X"}'), {'code': 'X'});
    expect(CloudFunctionTransport.leseJson('[1]'), isNull);
    expect(CloudFunctionTransport.leseJson('kein json'), isNull);
  });
}
