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
    this.lastSelectedHeroId,
    this.avatarApiConfig = const AvatarApiConfig(),
    this.uiVariante = UiVariante.codex,
    this.summaryRailCollapsed = false,
    this.catalogContentPassword,
    Set<String> disabledHouseRulePackIds = const <String>{},
    @Deprecated('Use disabledHouseRulePackIds instead')
    Set<String>? disabledHouseRuleSourceKeys,
  }) : disabledHouseRulePackIds =
           disabledHouseRuleSourceKeys ?? disabledHouseRulePackIds;

  final bool debugModus;
  final bool dunkelModus;
  final String? heroStoragePath;

  /// Zuletzt auf der Startseite ausgewaehlte Helden-ID.
  final String? lastSelectedHeroId;

  /// Konfiguration fuer die KI-Bildgenerierungs-API.
  final AvatarApiConfig avatarApiConfig;

  /// Aktive visuelle Darstellungsvariante.
  final UiVariante uiVariante;

  /// Ob die Kernwerte-Rail im Workspace zugeklappt ist.
  final bool summaryRailCollapsed;

  /// Passwort fuer den Zugriff auf geschuetzte Kataloginhalte.
  final String? catalogContentPassword;

  /// Deaktivierte Hausregel-Pakete (Opt-out). Leeres Set = alles aktiv.
  final Set<String> disabledHouseRulePackIds;

  /// Rueckwaertskompatibler Alias fuer alte Source-Key-Settings.
  @Deprecated('Use disabledHouseRulePackIds instead')
  Set<String> get disabledHouseRuleSourceKeys => disabledHouseRulePackIds;

  /// Erstellt eine angepasste Kopie der Einstellungen.
  AppSettings copyWith({
    bool? debugModus,
    bool? dunkelModus,
    Object? heroStoragePath = _copySentinel,
    Object? lastSelectedHeroId = _copySentinel,
    AvatarApiConfig? avatarApiConfig,
    UiVariante? uiVariante,
    bool? summaryRailCollapsed,
    Object? catalogContentPassword = _copySentinel,
    Set<String>? disabledHouseRulePackIds,
    @Deprecated('Use disabledHouseRulePackIds instead')
    Set<String>? disabledHouseRuleSourceKeys,
  }) {
    return AppSettings(
      debugModus: debugModus ?? this.debugModus,
      dunkelModus: dunkelModus ?? this.dunkelModus,
      heroStoragePath: identical(heroStoragePath, _copySentinel)
          ? this.heroStoragePath
          : heroStoragePath as String?,
      lastSelectedHeroId: identical(lastSelectedHeroId, _copySentinel)
          ? this.lastSelectedHeroId
          : lastSelectedHeroId as String?,
      avatarApiConfig: avatarApiConfig ?? this.avatarApiConfig,
      uiVariante: uiVariante ?? this.uiVariante,
      summaryRailCollapsed: summaryRailCollapsed ?? this.summaryRailCollapsed,
      catalogContentPassword: identical(catalogContentPassword, _copySentinel)
          ? this.catalogContentPassword
          : catalogContentPassword as String?,
      disabledHouseRulePackIds:
          disabledHouseRuleSourceKeys ??
          disabledHouseRulePackIds ??
          this.disabledHouseRulePackIds,
    );
  }

  Map<String, dynamic> toJson() => {
    'debugModus': debugModus,
    'dunkelModus': dunkelModus,
    'heroStoragePath': heroStoragePath,
    'lastSelectedHeroId': lastSelectedHeroId,
    'avatarApiConfig': avatarApiConfig.toJson(),
    'uiVariante': uiVariante.name,
    'summaryRailCollapsed': summaryRailCollapsed,
    'catalogContentPassword': catalogContentPassword,
    'disabledHouseRulePackIds': disabledHouseRulePackIds.toList(
      growable: false,
    ),
  };

  static AppSettings fromJson(Map<String, dynamic> json) {
    final rawHeroStoragePath = json['heroStoragePath'];
    final heroStoragePath = rawHeroStoragePath is String
        ? rawHeroStoragePath.trim()
        : null;
    final lastSelectedHeroId = _parseNullableString(json['lastSelectedHeroId']);
    final rawVariante = json['uiVariante'] as String?;
    final uiVariante =
        UiVariante.values.where((v) => v.name == rawVariante).firstOrNull ??
        UiVariante.codex;

    return AppSettings(
      debugModus: json['debugModus'] as bool? ?? false,
      dunkelModus: json['dunkelModus'] as bool? ?? false,
      heroStoragePath: heroStoragePath == null || heroStoragePath.isEmpty
          ? null
          : heroStoragePath,
      lastSelectedHeroId: lastSelectedHeroId,
      avatarApiConfig: AvatarApiConfig.fromJson(
        (json['avatarApiConfig'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      uiVariante: uiVariante,
      summaryRailCollapsed: json['summaryRailCollapsed'] as bool? ?? false,
      catalogContentPassword: _parseNullableString(
        json['catalogContentPassword'],
      ),
      disabledHouseRulePackIds: _parseStringSet(
        json['disabledHouseRulePackIds'],
        fallback: _parseStringSet(json['disabledHouseRuleSourceKeys']),
      ),
    );
  }

  static Set<String> _parseStringSet(dynamic raw, {Set<String>? fallback}) {
    if (raw is! List) {
      return fallback ?? const <String>{};
    }
    final result = <String>{};
    for (final entry in raw) {
      if (entry is String) {
        final trimmed = entry.trim();
        if (trimmed.isNotEmpty) result.add(trimmed);
      }
    }
    if (result.isEmpty && fallback != null) {
      return fallback;
    }
    return Set<String>.unmodifiable(result);
  }

  static String? _parseNullableString(dynamic raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

const Object _copySentinel = Object();
