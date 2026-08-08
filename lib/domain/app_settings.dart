import 'package:dsa_heldenverwaltung/domain/avatar_config.dart';
import 'package:dsa_heldenverwaltung/domain/rules_index_remote_config.dart';

/// Visuelle Darstellungsvariante der App-Oberflaeche.
enum UiVariante {
  /// Schlichtes Material-3-Design ohne dekorative Elemente.
  klassisch,

  /// Pergament-und-Messing-Aesthetik mit Texturen und Wasserzeichen.
  codex,
}

/// Darstellung breiter Datenlisten (Talente, Eigenschaften, Basiswerte).
enum TabellenAnsicht {
  /// Tabelle, solange die Breite reicht, sonst Karten (Standard).
  automatisch,

  /// Immer die volle Tabelle, bei Bedarf horizontal scrollbar.
  tabelle,

  /// Immer die kompakte Kartenliste.
  karten,
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
    this.tabellenAnsicht = TabellenAnsicht.automatisch,
    this.summaryRailCollapsed = false,
    this.catalogContentPassword,
    this.rulesIndexRemoteConfig = const RulesIndexRemoteConfig(),
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

  /// Gewuenschte Darstellung breiter Datenlisten.
  final TabellenAnsicht tabellenAnsicht;

  /// Ob die Kernwerte-Rail im Workspace zugeklappt ist.
  final bool summaryRailCollapsed;

  /// Passwort fuer den Zugriff auf geschuetzte Kataloginhalte.
  final String? catalogContentPassword;

  /// Konfiguration fuer den optionalen Remote-Bezug der Regel-Index-DB.
  final RulesIndexRemoteConfig rulesIndexRemoteConfig;

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
    TabellenAnsicht? tabellenAnsicht,
    bool? summaryRailCollapsed,
    Object? catalogContentPassword = _copySentinel,
    RulesIndexRemoteConfig? rulesIndexRemoteConfig,
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
      tabellenAnsicht: tabellenAnsicht ?? this.tabellenAnsicht,
      summaryRailCollapsed: summaryRailCollapsed ?? this.summaryRailCollapsed,
      catalogContentPassword: identical(catalogContentPassword, _copySentinel)
          ? this.catalogContentPassword
          : catalogContentPassword as String?,
      rulesIndexRemoteConfig:
          rulesIndexRemoteConfig ?? this.rulesIndexRemoteConfig,
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
    'tabellenAnsicht': tabellenAnsicht.name,
    'summaryRailCollapsed': summaryRailCollapsed,
    'catalogContentPassword': catalogContentPassword,
    'rulesIndexRemoteConfig': rulesIndexRemoteConfig.toJson(),
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
    final rawAnsicht = json['tabellenAnsicht'] as String?;
    final tabellenAnsicht =
        TabellenAnsicht.values
            .where((v) => v.name == rawAnsicht)
            .firstOrNull ??
        TabellenAnsicht.automatisch;

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
      tabellenAnsicht: tabellenAnsicht,
      summaryRailCollapsed: json['summaryRailCollapsed'] as bool? ?? false,
      catalogContentPassword: _parseNullableString(
        json['catalogContentPassword'],
      ),
      rulesIndexRemoteConfig: RulesIndexRemoteConfig.fromJson(
        (json['rulesIndexRemoteConfig'] as Map?)?.cast<String, dynamic>() ??
            const {},
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
