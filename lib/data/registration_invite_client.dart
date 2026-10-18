import 'dart:convert';

import 'package:http/http.dart' as http;

/// Abstraktion für das serverseitige Ausstellen eines Registrierungstickets.
abstract interface class RegistrationInviteGateway {
  /// Prüft das Keyword und bindet ein kurzlebiges Ticket an die E-Mail.
  Future<void> issueTicket({required String email, required String keyword});
}

/// App-Check-geschützter HTTP-Client für Registrierungstickets.
class RegistrationInviteClient implements RegistrationInviteGateway {
  /// Erstellt den Client für den konfigurierten Function-Endpunkt.
  RegistrationInviteClient({
    required this.endpoint,
    required this.appCheckTokenProvider,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  /// Basis-URL der Registration-Invite-Function.
  final Uri endpoint;

  /// Liefert unmittelbar vor dem Aufruf einen frischen App-Check-Token.
  final Future<String?> Function() appCheckTokenProvider;

  final http.Client _http;

  @override
  Future<void> issueTicket({
    required String email,
    required String keyword,
  }) async {
    final appCheckToken = await appCheckTokenProvider();
    if (appCheckToken == null || appCheckToken.trim().isEmpty) {
      throw const RegistrationInviteException('APP_CHECK_REQUIRED');
    }
    final response = await _http.post(
      _route('tickets'),
      headers: {
        'content-type': 'application/json',
        'x-firebase-appcheck': appCheckToken.trim(),
      },
      body: jsonEncode({'email': email.trim(), 'keyword': keyword}),
    );
    if (response.statusCode == 204) {
      return;
    }
    var code = 'SERVICE_UNAVAILABLE';
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      code = body['code'] as String? ?? code;
    } on Object {
      // Nicht vertrauenswürdige Serverantworten werden nicht an die UI gereicht.
    }
    throw RegistrationInviteException(code, statusCode: response.statusCode);
  }

  Uri _route(String child) {
    final base = endpoint.path.endsWith('/')
        ? endpoint.path.substring(0, endpoint.path.length - 1)
        : endpoint.path;
    return endpoint.replace(path: '$base/$child');
  }
}

/// Stabiler Fehlercode des Registrierungsticket-Dienstes.
class RegistrationInviteException implements Exception {
  /// Erstellt einen Fehler ohne vertrauliche Serverdetails.
  const RegistrationInviteException(this.code, {this.statusCode});

  /// Maschinenlesbarer, lokalisierbarer Fehlercode.
  final String code;

  /// Optionaler HTTP-Status zur Diagnose.
  final int? statusCode;
}
