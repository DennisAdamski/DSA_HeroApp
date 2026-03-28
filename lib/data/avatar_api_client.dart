import 'package:dsa_heldenverwaltung/domain/avatar_config.dart';
import 'package:dsa_heldenverwaltung/data/avatar_api_openai.dart';

/// Abstrakte Schnittstelle fuer KI-Bildgenerierungs-APIs.
abstract class AvatarApiClient {
  /// Generiert ein Portraetbild aus einem Textprompt.
  /// Gibt die rohen PNG-Bytes zurueck.
  Future<List<int>> generatePortrait({required String prompt});

  /// Generiert ein Portraetbild mit Referenzbild fuer Gesichtstreue.
  ///
  /// Nicht alle Provider unterstuetzen diese Funktion.
  /// Pruefe vorher [supportsReferenceImage].
  Future<List<int>> generatePortraitWithReference({
    required String prompt,
    required List<int> referenceImageBytes,
  }) {
    throw UnsupportedError(
      '$providerName unterstuetzt keine Referenzbild-Generierung.',
    );
  }

  /// Ob der Provider Referenzbild-basierte Generierung unterstuetzt.
  bool get supportsReferenceImage => false;

  /// Geschaetzte Kosten pro Generierung in USD.
  double get estimatedCostUsd;

  /// Anzeigename des Providers.
  String get providerName;
}

/// Erstellt den passenden API-Client fuer den konfigurierten Provider.
AvatarApiClient createAvatarApiClient(AvatarApiConfig config) {
  switch (config.provider) {
    case AvatarApiProvider.openaiGptImage1:
      return OpenAiGptImage1Client(apiKey: config.apiKey);
    case AvatarApiProvider.openaiDalle3:
      return OpenAiDalle3Client(apiKey: config.apiKey);
  }
}
