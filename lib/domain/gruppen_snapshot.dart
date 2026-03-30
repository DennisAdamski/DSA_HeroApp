import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';

/// Kompakte Visitenkarte eines Helden fuer geraeteuebergreifendes
/// Gruppen-Sharing.
///
/// Enthaelt nur die wichtigsten Basisdaten, die andere Gruppenmitglieder
/// auf ihren Geraeten sehen koennen. Design ist offen fuer kuenftige
/// Echtzeit-Erweiterung (z.B. Firebase/Supabase).
class HeldVisitenkarte {
  const HeldVisitenkarte({
    required this.heroId,
    required this.name,
    this.rasse = '',
    this.kultur = '',
    this.profession = '',
    this.level = 0,
    this.maxLep = 0,
    this.maxAsp = 0,
    this.maxAu = 0,
    this.iniBase = 0,
    this.avatarThumbnailBase64,
    required this.exportedAt,
  });

  final String heroId;
  final String name;
  final String rasse;
  final String kultur;
  final String profession;
  final int level;
  final int maxLep;
  final int maxAsp;
  final int maxAu;
  final int iniBase;

  /// Optionales Avatar-Thumbnail als Base64-kodiertes PNG.
  final String? avatarThumbnailBase64;

  /// Zeitpunkt, zu dem diese Visitenkarte erstellt wurde.
  final DateTime exportedAt;

  /// Erstellt eine Visitenkarte aus berechneten Heldenwerten.
  factory HeldVisitenkarte.fromHeroComputed(
    HeroSheet hero,
    DerivedStats derivedStats, {
    String? avatarBase64,
  }) {
    return HeldVisitenkarte(
      heroId: hero.id,
      name: hero.name,
      rasse: hero.background.rasse,
      kultur: hero.background.kultur,
      profession: hero.background.profession,
      level: hero.level,
      maxLep: derivedStats.maxLep,
      maxAsp: derivedStats.maxAsp,
      maxAu: derivedStats.maxAu,
      iniBase: derivedStats.iniBase,
      avatarThumbnailBase64: avatarBase64,
      exportedAt: DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'heroId': heroId,
      'name': name,
      'rasse': rasse,
      'kultur': kultur,
      'profession': profession,
      'level': level,
      'maxLep': maxLep,
      'maxAsp': maxAsp,
      'maxAu': maxAu,
      'iniBase': iniBase,
      if (avatarThumbnailBase64 != null)
        'avatarThumbnailBase64': avatarThumbnailBase64,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
    };
  }

  static HeldVisitenkarte fromJson(Map<String, dynamic> json) {
    final rawExportedAt = json['exportedAt'] as String? ?? '';
    final exportedAt = DateTime.tryParse(rawExportedAt)?.toUtc() ??
        DateTime.now().toUtc();

    return HeldVisitenkarte(
      heroId: json['heroId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      rasse: json['rasse'] as String? ?? '',
      kultur: json['kultur'] as String? ?? '',
      profession: json['profession'] as String? ?? '',
      level: (json['level'] as num?)?.toInt() ?? 0,
      maxLep: (json['maxLep'] as num?)?.toInt() ?? 0,
      maxAsp: (json['maxAsp'] as num?)?.toInt() ?? 0,
      maxAu: (json['maxAu'] as num?)?.toInt() ?? 0,
      iniBase: (json['iniBase'] as num?)?.toInt() ?? 0,
      avatarThumbnailBase64: json['avatarThumbnailBase64'] as String?,
      exportedAt: exportedAt,
    );
  }
}

/// Container fuer eine Heldengruppe mit kompakten Visitenkarten.
///
/// Wird als `.dsa-gruppe.json`-Datei zwischen Geraeten geteilt und
/// lokal in einer Hive-Box persistiert.
class GruppenSnapshot {
  const GruppenSnapshot({
    required this.gruppenName,
    required this.exportedAt,
    this.helden = const <HeldVisitenkarte>[],
  });

  static const String kind = 'dsa.gruppe.snapshot';
  static const int snapshotSchemaVersion = 1;

  final String gruppenName;
  final DateTime exportedAt;
  final List<HeldVisitenkarte> helden;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kind': kind,
      'snapshotSchemaVersion': snapshotSchemaVersion,
      'gruppenName': gruppenName,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'helden': helden
          .map((held) => held.toJson())
          .toList(growable: false),
    };
  }

  static GruppenSnapshot fromJson(Map<String, dynamic> json) {
    final rawKind = json['kind'];
    if (rawKind != kind) {
      throw const FormatException(
        'Ungültiger Dateityp: erwartet "dsa.gruppe.snapshot".',
      );
    }

    final rawVersion = json['snapshotSchemaVersion'];
    final version = rawVersion is num ? rawVersion.toInt() : null;
    if (version == null || version < 1 || version > snapshotSchemaVersion) {
      throw FormatException(
        'Unbekannte Gruppen-Version: nur Version 1-$snapshotSchemaVersion '
        'wird unterstützt.',
      );
    }

    final rawExportedAt = json['exportedAt'] as String? ?? '';
    final exportedAt = DateTime.tryParse(rawExportedAt)?.toUtc() ??
        DateTime.now().toUtc();

    final rawHelden = json['helden'] as List? ?? const [];
    final helden = rawHelden
        .whereType<Map>()
        .map((m) => HeldVisitenkarte.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);

    return GruppenSnapshot(
      gruppenName: json['gruppenName'] as String? ?? '',
      exportedAt: exportedAt,
      helden: helden,
    );
  }
}
