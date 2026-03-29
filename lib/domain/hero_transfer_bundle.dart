import 'package:dsa_heldenverwaltung/catalog/catalog_section_id.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';

class HeroTransferBundle {
  const HeroTransferBundle({
    required this.exportedAt,
    required this.hero,
    required this.state,
    this.avatarBase64,
    this.galleryImages,
    this.catalogEntries,
  });

  static const String kind = 'dsa.hero.export';
  static const int transferSchemaVersion = 3;

  final DateTime exportedAt;
  final HeroSheet hero;
  final HeroState state;

  /// Base64-kodierte Avatar-PNG-Daten (optional, Legacy-Kompatibilitaet).
  final String? avatarBase64;

  /// Gallery-Bilder als Base64-kodierte Eintraege (optional).
  final List<Map<String, dynamic>>? galleryImages;

  /// Optional eingebettete benutzerdefinierte Katalogeintraege.
  final List<HeroTransferCatalogEntry>? catalogEntries;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kind': kind,
      'transferSchemaVersion': transferSchemaVersion,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'hero': hero.toJson(),
      'state': state.toJson(),
      if (avatarBase64 != null) 'avatarBase64': avatarBase64,
      if (galleryImages != null && galleryImages!.isNotEmpty)
        'galleryImages': galleryImages,
      if (catalogEntries != null && catalogEntries!.isNotEmpty)
        'catalogEntries': catalogEntries!
            .map((entry) => entry.toJson())
            .toList(growable: false),
    };
  }

  static HeroTransferBundle fromJson(Map<String, dynamic> json) {
    final rawKind = json['kind'];
    if (rawKind != kind) {
      throw const FormatException(
        'Ungueltiger Exporttyp: erwartet "dsa.hero.export".',
      );
    }

    final rawVersion = json['transferSchemaVersion'];
    final version = rawVersion is num ? rawVersion.toInt() : null;
    if (version == null || version < 1 || version > transferSchemaVersion) {
      throw FormatException(
        'Unbekannte Export-Version: nur Version 1-$transferSchemaVersion '
        'wird unterstuetzt.',
      );
    }

    final rawExportedAt = json['exportedAt'];
    if (rawExportedAt is! String || rawExportedAt.trim().isEmpty) {
      throw const FormatException(
        'Feld "exportedAt" fehlt oder ist ungueltig.',
      );
    }
    final exportedAt = DateTime.tryParse(rawExportedAt);
    if (exportedAt == null) {
      throw const FormatException(
        'Feld "exportedAt" ist kein gueltiges ISO-8601 Datum.',
      );
    }

    final rawHero = json['hero'];
    if (rawHero is! Map) {
      throw const FormatException('Feld "hero" fehlt oder ist ungueltig.');
    }

    final rawState = json['state'];
    if (rawState is! Map) {
      throw const FormatException('Feld "state" fehlt oder ist ungueltig.');
    }

    final heroMap = rawHero.cast<String, dynamic>();
    final heroId = heroMap['id'];
    if (heroId is! String || heroId.trim().isEmpty) {
      throw const FormatException('Feld "hero.id" fehlt oder ist ungueltig.');
    }

    final rawAvatar = json['avatarBase64'];
    final avatarBase64 = rawAvatar is String && rawAvatar.isNotEmpty
        ? rawAvatar
        : null;

    final rawGallery = json['galleryImages'] as List?;
    final galleryImages = rawGallery?.whereType<Map<String, dynamic>>().toList(
      growable: false,
    );
    final rawCatalogEntries = json['catalogEntries'] as List?;
    final catalogEntries = rawCatalogEntries
        ?.whereType<Map>()
        .map(
          (entry) =>
              HeroTransferCatalogEntry.fromJson(entry.cast<String, dynamic>()),
        )
        .toList(growable: false);

    return HeroTransferBundle(
      exportedAt: exportedAt.toUtc(),
      hero: HeroSheet.fromJson(heroMap),
      state: HeroState.fromJson(rawState.cast<String, dynamic>()),
      avatarBase64: avatarBase64,
      galleryImages: galleryImages,
      catalogEntries: catalogEntries,
    );
  }
}

/// Eingebetteter benutzerdefinierter Katalogeintrag innerhalb eines Hero-Exports.
class HeroTransferCatalogEntry {
  const HeroTransferCatalogEntry({
    required this.section,
    required this.id,
    required this.data,
  });

  final CatalogSectionId section;
  final String id;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'section': section.directoryName,
      'id': id,
      'data': data,
    };
  }

  static HeroTransferCatalogEntry fromJson(Map<String, dynamic> json) {
    final sectionRaw = json['section'] as String? ?? '';
    final section = catalogSectionFromDirectoryName(sectionRaw);
    if (section == null) {
      throw FormatException(
        'Unbekannte Katalogsektion im Hero-Export: "$sectionRaw".',
      );
    }

    final id = (json['id'] as String? ?? '').trim();
    if (id.isEmpty) {
      throw const FormatException(
        'Feld "catalogEntries[].id" fehlt oder ist ungueltig.',
      );
    }

    final data = json['data'];
    if (data is! Map) {
      throw const FormatException(
        'Feld "catalogEntries[].data" fehlt oder ist ungueltig.',
      );
    }

    return HeroTransferCatalogEntry(
      section: section,
      id: id,
      data: data.cast<String, dynamic>(),
    );
  }
}
