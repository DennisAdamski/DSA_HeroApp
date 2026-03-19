import 'package:dsa_heldenverwaltung/domain/avatar_config.dart';

/// Globale, heldenunabhaengige App-Einstellungen.
class AppSettings {
  const AppSettings({
    this.debugModus = false,
    this.dunkelModus = false,
    this.heroStoragePath,
    this.avatarApiConfig = const AvatarApiConfig(),
  });

  final bool debugModus;
  final bool dunkelModus;
  final String? heroStoragePath;

  /// Konfiguration fuer die KI-Bildgenerierungs-API.
  final AvatarApiConfig avatarApiConfig;

  /// Erstellt eine angepasste Kopie der Einstellungen.
  AppSettings copyWith({
    bool? debugModus,
    bool? dunkelModus,
    Object? heroStoragePath = _copySentinel,
    AvatarApiConfig? avatarApiConfig,
  }) {
    return AppSettings(
      debugModus: debugModus ?? this.debugModus,
      dunkelModus: dunkelModus ?? this.dunkelModus,
      heroStoragePath: identical(heroStoragePath, _copySentinel)
          ? this.heroStoragePath
          : heroStoragePath as String?,
      avatarApiConfig: avatarApiConfig ?? this.avatarApiConfig,
    );
  }

  Map<String, dynamic> toJson() => {
    'debugModus': debugModus,
    'dunkelModus': dunkelModus,
    'heroStoragePath': heroStoragePath,
    'avatarApiConfig': avatarApiConfig.toJson(),
  };

  static AppSettings fromJson(Map<String, dynamic> json) {
    final rawHeroStoragePath = json['heroStoragePath'];
    final heroStoragePath = rawHeroStoragePath is String
        ? rawHeroStoragePath.trim()
        : null;
    return AppSettings(
      debugModus: json['debugModus'] as bool? ?? false,
      dunkelModus: json['dunkelModus'] as bool? ?? false,
      heroStoragePath: heroStoragePath == null || heroStoragePath.isEmpty
          ? null
          : heroStoragePath,
      avatarApiConfig: AvatarApiConfig.fromJson(
        (json['avatarApiConfig'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }
}

const Object _copySentinel = Object();
