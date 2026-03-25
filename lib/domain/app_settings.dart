import 'package:dsa_heldenverwaltung/domain/avatar_config.dart';

/// Visuelle Darstellungsvariante der App-Oberflaeche.
enum UiVariante {
  /// Schlichtes Material-3-Design ohne dekorative Elemente.
  klassisch,

  /// Pergament-und-Messing-Aesthetik mit Texturen und Wasserzeichen.
  codex,
}

/// Globale, heldenunabhaengige App-Einstellungen.
class AppSettings {
  const AppSettings({
    this.debugModus = false,
    this.dunkelModus = false,
    this.heroStoragePath,
    this.avatarApiConfig = const AvatarApiConfig(),
    this.uiVariante = UiVariante.codex,
    this.summaryRailCollapsed = false,
  });

  final bool debugModus;
  final bool dunkelModus;
  final String? heroStoragePath;

  /// Konfiguration fuer die KI-Bildgenerierungs-API.
  final AvatarApiConfig avatarApiConfig;

  /// Aktive visuelle Darstellungsvariante.
  final UiVariante uiVariante;

  /// Ob die Kernwerte-Rail im Workspace zugeklappt ist.
  final bool summaryRailCollapsed;

  /// Erstellt eine angepasste Kopie der Einstellungen.
  AppSettings copyWith({
    bool? debugModus,
    bool? dunkelModus,
    Object? heroStoragePath = _copySentinel,
    AvatarApiConfig? avatarApiConfig,
    UiVariante? uiVariante,
    bool? summaryRailCollapsed,
  }) {
    return AppSettings(
      debugModus: debugModus ?? this.debugModus,
      dunkelModus: dunkelModus ?? this.dunkelModus,
      heroStoragePath: identical(heroStoragePath, _copySentinel)
          ? this.heroStoragePath
          : heroStoragePath as String?,
      avatarApiConfig: avatarApiConfig ?? this.avatarApiConfig,
      uiVariante: uiVariante ?? this.uiVariante,
      summaryRailCollapsed: summaryRailCollapsed ?? this.summaryRailCollapsed,
    );
  }

  Map<String, dynamic> toJson() => {
    'debugModus': debugModus,
    'dunkelModus': dunkelModus,
    'heroStoragePath': heroStoragePath,
    'avatarApiConfig': avatarApiConfig.toJson(),
    'uiVariante': uiVariante.name,
    'summaryRailCollapsed': summaryRailCollapsed,
  };

  static AppSettings fromJson(Map<String, dynamic> json) {
    final rawHeroStoragePath = json['heroStoragePath'];
    final heroStoragePath = rawHeroStoragePath is String
        ? rawHeroStoragePath.trim()
        : null;
    final rawVariante = json['uiVariante'] as String?;
    final uiVariante = UiVariante.values.where(
      (v) => v.name == rawVariante,
    ).firstOrNull ?? UiVariante.codex;

    return AppSettings(
      debugModus: json['debugModus'] as bool? ?? false,
      dunkelModus: json['dunkelModus'] as bool? ?? false,
      heroStoragePath: heroStoragePath == null || heroStoragePath.isEmpty
          ? null
          : heroStoragePath,
      avatarApiConfig: AvatarApiConfig.fromJson(
        (json['avatarApiConfig'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      uiVariante: uiVariante,
      summaryRailCollapsed: json['summaryRailCollapsed'] as bool? ?? false,
    );
  }
}

const Object _copySentinel = Object();
