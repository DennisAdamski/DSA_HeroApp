import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:dsa_heldenverwaltung/data/avatar_api_client.dart';

/// OpenAI DALL-E 3 Implementation der [AvatarApiClient]-Schnittstelle.
class OpenAiDalle3Client implements AvatarApiClient {
  OpenAiDalle3Client({required this.apiKey, http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final String apiKey;
  final http.Client _httpClient;

  static const String _endpoint =
      'https://api.openai.com/v1/images/generations';

  @override
  double get estimatedCostUsd => 0.080;

  @override
  String get providerName => 'OpenAI DALL-E 3';

  @override
  Future<List<int>> generatePortrait({required String prompt}) async {
    final response = await _httpClient.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'dall-e-3',
        'prompt': prompt,
        'n': 1,
        'size': '1024x1792',
        'quality': 'hd',
        'response_format': 'b64_json',
      }),
    );

    if (response.statusCode != 200) {
      throw _parseApiError(response);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'] as List?;
    if (data == null || data.isEmpty) {
      throw const FormatException(
        'Die API hat kein Bild zurueckgegeben.',
      );
    }

    final b64 = (data[0] as Map)['b64_json'] as String?;
    if (b64 == null || b64.isEmpty) {
      throw const FormatException(
        'Die API-Antwort enthaelt keine Bilddaten.',
      );
    }

    return base64Decode(b64);
  }

  Exception _parseApiError(http.Response response) {
    String detail;
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final error = json['error'] as Map?;
      detail = (error?['message'] as String?) ?? response.body;
    } on Object {
      detail = response.body;
    }

    switch (response.statusCode) {
      case 401:
        return Exception(
          'Ungueltiger API-Schluessel. '
          'Bitte pruefe den Schluessel in den Einstellungen.',
        );
      case 429:
        return Exception(
          'Zu viele Anfragen oder Kontingent erschoepft. '
          'Bitte versuche es spaeter erneut.',
        );
      case 400:
        if (detail.contains('content_policy')) {
          return Exception(
            'Der Prompt wurde von der Inhaltsrichtlinie abgelehnt. '
            'Bitte passe die Beschreibung an.',
          );
        }
        return Exception('Fehlerhafte Anfrage: $detail');
      default:
        return Exception(
          'API-Fehler (${response.statusCode}): $detail',
        );
    }
  }
}
