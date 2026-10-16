import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/data/feedback/feedback_client.dart';
import 'package:dsa_heldenverwaltung/domain/feedback/feedback_result.dart';
import 'package:dsa_heldenverwaltung/domain/feedback/feedback_submission.dart';

void main() {
  const submission = FeatureFeedbackSubmission(
    requestId: '123e4567-e89b-42d3-a456-426614174001',
    title: 'Gegnervorlagen speichern',
    surface: FeedbackSurface.combat,
    metadata: FeedbackBaseMetadata(
      appVersion: '1.0.1',
      buildNumber: '1',
      commit: 'abcdef0',
      builtAt: '2026-10-15T19:00:00Z',
      platform: 'windows',
    ),
    problem: 'Wiederkehrende Gegner müssen jedes Mal neu erfasst werden.',
    desiredBehavior: 'Gegner sollen als Vorlage gespeichert werden können.',
  );

  test(
    'liest vor jedem Aufruf ein frisches ID-Token und sendet Vertrag als JSON',
    () async {
      var token = 'first-token';
      final requests = <http.Request>[];
      final client = FeedbackClient(
        endpoint: Uri.parse('https://feedback.test.example'),
        idTokenProvider: () async => token,
        appCheckTokenProvider: () async => 'app-check-token',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'requestId': submission.requestId,
              'status': 'created',
              'issueNumber': 23,
              'issueUrl':
                  'https://github.com/DennisAdamski/DSA_HeroApp/issues/23',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final first = await client.submit(submission);
      token = 'second-token';
      await client.submit(submission);

      expect(first.status, FeedbackResultStatus.created);
      expect(first.issueNumber, 23);
      expect(requests[0].headers['authorization'], 'Bearer first-token');
      expect(requests[1].headers['authorization'], 'Bearer second-token');
      expect(
        requests[0].headers['x-firebase-appcheck'],
        'app-check-token',
      );
      expect(jsonDecode(requests[0].body), submission.toJson());
    },
  );

  test(
    'übersetzt 202 und Timeout ohne automatischen zweiten POST in uncertain',
    () async {
      var calls = 0;
      final accepted = FeedbackClient(
        endpoint: Uri.parse('https://feedback.test.example'),
        idTokenProvider: () async => 'token',
        appCheckTokenProvider: () async => 'app-check-token',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'requestId': submission.requestId,
              'status': 'uncertain',
            }),
            202,
          ),
        ),
      );
      expect(
        (await accepted.submit(submission)).status,
        FeedbackResultStatus.uncertain,
      );

      final timedOut = FeedbackClient(
        endpoint: Uri.parse('https://feedback.test.example'),
        idTokenProvider: () async => 'token',
        appCheckTokenProvider: () async => 'app-check-token',
        timeout: const Duration(milliseconds: 1),
        httpClient: MockClient((_) async {
          calls += 1;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return http.Response('{}', 201);
        }),
      );
      final result = await timedOut.submit(submission);
      expect(result.status, FeedbackResultStatus.uncertain);
      expect(calls, 1);
    },
  );

  test('fragt Status per GET ab und liefert stabile Fehlercodes', () async {
    final client = FeedbackClient(
      endpoint: Uri.parse('https://feedback.test.example'),
      idTokenProvider: () async => 'token',
      appCheckTokenProvider: () async => 'app-check-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        return http.Response(jsonEncode({'code': 'NOT_FOUND'}), 404);
      }),
    );

    await expectLater(
      client.status(submission.requestId),
      throwsA(
        isA<FeedbackClientException>().having(
          (error) => error.code,
          'code',
          'NOT_FOUND',
        ),
      ),
    );
  });
}
