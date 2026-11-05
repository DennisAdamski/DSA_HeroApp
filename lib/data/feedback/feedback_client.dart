import 'dart:async';

import 'package:http/http.dart' as http;

import 'package:dsa_heldenverwaltung/data/cloud_function_transport.dart';
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
  }) : _transport = CloudFunctionTransport(
         endpoint: endpoint,
         idTokenProvider: idTokenProvider,
         appCheckTokenProvider: appCheckTokenProvider,
         httpClient: httpClient,
         timeout: timeout,
       );

  /// Basis-URL genau eines serverseitig festgelegten Zielsystems.
  final Uri endpoint;

  /// Liefert unmittelbar vor jedem Aufruf das aktuelle Firebase-ID-Token.
  final Future<String?> Function() idTokenProvider;

  /// Liefert unmittelbar vor jedem Aufruf einen frischen App-Check-Token.
  final Future<String?> Function() appCheckTokenProvider;

  /// Maximale Wartezeit; ein Ablauf gilt wegen möglicher Erstellung als unklar.
  final Duration timeout;

  final CloudFunctionTransport _transport;

  /// Sendet eine Meldung genau einmal; Transportabbrüche werden `uncertain`.
  @override
  Future<FeedbackResult> submit(FeedbackSubmission submission) async {
    try {
      final response = await _mitTokenfehler(
        () => _transport.postJson(
          _transport.route('submissions'),
          submission.toJson(),
        ),
      );
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
    try {
      final response = await _mitTokenfehler(
        () => _transport.get(
          _transport.route('submissions/${Uri.encodeComponent(requestId)}'),
        ),
      );
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

  // Ein fehlendes Token wird zum Fehlercode des Dienstes; gesendet wurde dann
  // nichts, die Meldung ist also nicht `uncertain`.
  Future<http.Response> _mitTokenfehler(
    Future<http.Response> Function() aufruf,
  ) async {
    try {
      return await aufruf();
    } on CloudFunctionTokenFehlt catch (fehlt) {
      throw FeedbackClientException(
        fehlt.art == CloudFunctionTokenArt.konto
            ? 'AUTH_REQUIRED'
            : 'APP_CHECK_REQUIRED',
        statusCode: 401,
      );
    }
  }

  FeedbackResult _decode(http.Response response) {
    final json = CloudFunctionTransport.leseJson(response.body);
    if (json == null) {
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

/// Stabiler, nutzerlesbar übersetzbarer Fehler des Feedbackdienstes.
class FeedbackClientException implements Exception {
  /// Erstellt einen Fehler ohne vertrauliche Serverantwort.
  const FeedbackClientException(this.code, {required this.statusCode});

  final String code;
  final int statusCode;
}
