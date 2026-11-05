import 'package:http/http.dart' as http;

import 'package:dsa_heldenverwaltung/data/cloud_function_transport.dart';

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
  }) : _transport = CloudFunctionTransport(
         endpoint: endpoint,
         appCheckTokenProvider: appCheckTokenProvider,
         httpClient: httpClient,
       );

  /// Basis-URL der Registration-Invite-Function.
  final Uri endpoint;

  /// Liefert unmittelbar vor dem Aufruf einen frischen App-Check-Token.
  final Future<String?> Function() appCheckTokenProvider;

  final CloudFunctionTransport _transport;

  @override
  Future<void> issueTicket({
    required String email,
    required String keyword,
  }) async {
    final http.Response response;
    try {
      response = await _transport.postJson(_transport.route('tickets'), {
        'email': email.trim(),
        'keyword': keyword,
      });
    } on CloudFunctionTokenFehlt {
      throw const RegistrationInviteException('APP_CHECK_REQUIRED');
    }
    if (response.statusCode == 204) {
      return;
    }
    // Nicht vertrauenswürdige Serverantworten werden nicht an die UI gereicht.
    final code =
        CloudFunctionTransport.leseJson(response.body)?['code'] as String? ??
        'SERVICE_UNAVAILABLE';
    throw RegistrationInviteException(code, statusCode: response.statusCode);
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
