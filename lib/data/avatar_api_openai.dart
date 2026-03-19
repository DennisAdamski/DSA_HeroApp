import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:dsa_heldenverwaltung/data/avatar_api_client.dart';

/// Gemeinsame Basis fuer OpenAI-Bildgenerierungs-Clients.
///
/// DALL-E 3 und GPT-image-1 nutzen denselben Endpoint und dasselbe
/// Antwortformat; sie unterscheiden sich nur in Modell, Groesse,
/// Quality-Parameter und Kosten.
abstract class _OpenAiImageClient implements AvatarApiClient {
  _OpenAiImageClient({required this.apiKey, http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final String apiKey;
  final http.Client _httpClient;

  static const String _endpoint =
      'https://api.openai.com/v1/images/generations';

  String get _model;
  String get _size;
  String get _quality;

  /// Baut den Request-Body. Subklassen koennen dies ueberschreiben,
  /// um modellspezifische Parameter zu setzen.
  Map<String, dynamic> _buildRequestBody(String prompt) => {
        'model': _model,
        'prompt': prompt,
        'n': 1,
        'size': _size,
        'quality': _quality,
      };

  @override
  Future<List<int>> generatePortrait({required String prompt}) async {
    final response = await _httpClient.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(_buildRequestBody(prompt)),
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

/// OpenAI GPT-image-1: bessere Prompt-Treue und Detailtreue als DALL-E 3.
class OpenAiGptImage1Client extends _OpenAiImageClient {
  OpenAiGptImage1Client({required super.apiKey, super.httpClient});

  @override
  String get _model => 'gpt-image-1';

  @override
  String get _size => '1024x1536';

  @override
  String get _quality => 'high';

  @override
  double get estimatedCostUsd => 0.25;

  @override
  String get providerName => 'OpenAI GPT-image-1';
}

/// OpenAI DALL-E 3: guenstiger, etwas geringere Qualitaet.
class OpenAiDalle3Client extends _OpenAiImageClient {
  OpenAiDalle3Client({required super.apiKey, super.httpClient});

  @override
  String get _model => 'dall-e-3';

  @override
  String get _size => '1024x1792';

  @override
  String get _quality => 'hd';

  @override
  Map<String, dynamic> _buildRequestBody(String prompt) => {
        ...super._buildRequestBody(prompt),
        'response_format': 'b64_json',
      };

  @override
  double get estimatedCostUsd => 0.080;

  @override
  String get providerName => 'OpenAI DALL-E 3';
}
