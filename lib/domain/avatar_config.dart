/// Unterstuetzte KI-Bildgenerierungs-Anbieter.
enum AvatarApiProvider {
  openaiDalle3('OpenAI DALL-E 3');

  const AvatarApiProvider(this.displayName);

  final String displayName;

  static AvatarApiProvider? fromId(String? id) {
    if (id == null) return null;
    for (final value in values) {
      if (value.name == id) return value;
    }
    return null;
  }
}

/// Konfiguration fuer die KI-Bildgenerierungs-API.
class AvatarApiConfig {
  const AvatarApiConfig({
    this.provider = AvatarApiProvider.openaiDalle3,
    this.apiKey = '',
  });

  final AvatarApiProvider provider;
  final String apiKey;

  /// Ob ein API-Key hinterlegt ist.
  bool get isConfigured => apiKey.isNotEmpty;

  AvatarApiConfig copyWith({
    AvatarApiProvider? provider,
    String? apiKey,
  }) {
    return AvatarApiConfig(
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
    );
  }

  Map<String, dynamic> toJson() => {
        'provider': provider.name,
        'apiKey': apiKey,
      };

  static AvatarApiConfig fromJson(Map<String, dynamic> json) {
    return AvatarApiConfig(
      provider: AvatarApiProvider.fromId(json['provider'] as String?) ??
          AvatarApiProvider.openaiDalle3,
      apiKey: (json['apiKey'] as String?) ?? '',
    );
  }
}
