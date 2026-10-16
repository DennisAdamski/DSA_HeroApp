import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dsa_heldenverwaltung/data/registration_invite_client.dart';

void main() {
  test('sendet E-Mail und Keyword nur mit frischem App-Check-Token', () async {
    late http.Request captured;
    final client = RegistrationInviteClient(
      endpoint: Uri.parse('https://registration.example'),
      appCheckTokenProvider: () async => 'app-check-token',
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response('', 204);
      }),
    );

    await client.issueTicket(
      email: 'held@example.de',
      keyword: 'invite-secret',
    );

    expect(captured.url.path, '/tickets');
    expect(captured.headers['x-firebase-appcheck'], 'app-check-token');
    expect(jsonDecode(captured.body), {
      'email': 'held@example.de',
      'keyword': 'invite-secret',
    });
  });
}
