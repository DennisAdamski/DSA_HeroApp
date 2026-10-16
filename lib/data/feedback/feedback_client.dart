import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:dsa_heldenverwaltung/domain/feedback/feedback_result.dart';
import 'package:dsa_heldenverwaltung/domain/feedback/feedback_submission.dart';

/// Austauschbarer Transportvertrag für UI und Statuswiederherstellung.
abstract interface class FeedbackGateway {
  /// Sendet genau eine typisierte Meldung.
  Future<FeedbackResult> submit(FeedbackSubmission submission);

  /// Fragt einen bestehenden Vorgang ohne neuen POST ab.
  Future<FeedbackResult> status(String requestId);
}

/// HTTP-Client für den authentifizierten Feedbackdienst.
class FeedbackClient implements FeedbackGateway {
  /// Erstellt einen Client mit injizierbaren Netzwerk- und Tokenabhängigkeiten.
  FeedbackClient({
    required this.endpoint,
    required this.idTokenProvider,
    required this.appCheckTokenProvider,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 12),
  }) : _http = httpClient ?? http.Client();

  /// Basis-URL genau eines serverseitig festgelegten Zielsystems.
  final Uri endpoint;

  /// Liefert unmittelbar vor jedem Aufruf das aktuelle Firebase-ID-Token.
  final Future<String?> Function() idTokenProvider;

  /// Liefert unmittelbar vor jedem Aufruf einen frischen App-Check-Token.
  final Future<String?> Function() appCheckTokenProvider;

  /// Maximale Wartezeit; ein Ablauf gilt wegen möglicher Erstellung als unklar.
  final Duration timeout;

  final http.Client _http;

  /// Sendet eine Meldung genau einmal; Transportabbrüche werden `uncertain`.
  @override
  Future<FeedbackResult> submit(FeedbackSubmission submission) async {
    try {
      final tokens = await _requiredTokens();
      final response = await _http
          .post(
            _route('submissions'),
            headers: <String, String>{
              'authorization': 'Bearer ${tokens.idToken}',
              'x-firebase-appcheck': tokens.appCheckToken,
              'content-type': 'application/json',
            },
            body: jsonEncode(submission.toJson()),
          )
          .timeout(timeout);
      return _decode(response);
    } on TimeoutException {
      return FeedbackResult(
        requestId: submission.requestId,
        status: FeedbackResultStatus.uncertain,
      );
    } on http.ClientException {
      return FeedbackResult(
        requestId: submission.requestId,
        status: FeedbackResultStatus.uncertain,
      );
    }
  }

  /// Fragt den kontogebundenen Status ab, ohne einen neuen POST auszulösen.
  @override
  Future<FeedbackResult> status(String requestId) async {
    final tokens = await _requiredTokens();
    try {
      final response = await _http
          .get(
            _route('submissions/${Uri.encodeComponent(requestId)}'),
            headers: <String, String>{
              'authorization': 'Bearer ${tokens.idToken}',
              'x-firebase-appcheck': tokens.appCheckToken,
            },
          )
          .timeout(timeout);
      return _decode(response);
    } on TimeoutException {
      return FeedbackResult(
        requestId: requestId,
        status: FeedbackResultStatus.uncertain,
      );
    } on http.ClientException {
      return FeedbackResult(
        requestId: requestId,
        status: FeedbackResultStatus.uncertain,
      );
    }
  }

  Future<_FeedbackTokens> _requiredTokens() async {
    final idToken = await idTokenProvider();
    if (idToken == null || idToken.trim().isEmpty) {
      throw const FeedbackClientException('AUTH_REQUIRED', statusCode: 401);
    }
    final appCheckToken = await appCheckTokenProvider();
    if (appCheckToken == null || appCheckToken.trim().isEmpty) {
      throw const FeedbackClientException(
        'APP_CHECK_REQUIRED',
        statusCode: 401,
      );
    }
    return _FeedbackTokens(
      idToken: idToken.trim(),
      appCheckToken: appCheckToken.trim(),
    );
  }

  Uri _route(String child) {
    final base = endpoint.path.endsWith('/')
        ? endpoint.path
        : '${endpoint.path}/';
    return endpoint.replace(path: '$base$child');
  }

  FeedbackResult _decode(http.Response response) {
    Map<String, dynamic> json;
    try {
      final decoded = jsonDecode(response.body);
      json = (decoded as Map).cast<String, dynamic>();
    } catch (_) {
      throw FeedbackClientException(
        'INVALID_RESPONSE',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FeedbackClientException(
        json['code'] as String? ?? 'REQUEST_FAILED',
        statusCode: response.statusCode,
      );
    }
    return FeedbackResult.fromJson(json);
  }
}

class _FeedbackTokens {
  const _FeedbackTokens({required this.idToken, required this.appCheckToken});

  final String idToken;
  final String appCheckToken;
}

/// Stabiler, nutzerlesbar übersetzbarer Fehler des Feedbackdienstes.
class FeedbackClientException implements Exception {
  /// Erstellt einen Fehler ohne vertrauliche Serverantwort.
  const FeedbackClientException(this.code, {required this.statusCode});

  final String code;
  final int statusCode;
}
