import 'package:dsa_heldenverwaltung/domain/externer_held.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/derived_stats.dart';

/// Kompakte Visitenkarte eines Helden fuer geraeteuebergreifendes
/// Gruppen-Sharing via Firestore.
///
/// Enthaelt nur die wichtigsten Basisdaten, die andere Gruppenmitglieder
/// auf ihren Geraeten sehen koennen.
class HeldVisitenkarte {
  /// Firestore-Obergrenze fuer Base64-Avatar-Thumbnails in Visitenkarten.
  static const int avatarThumbnailBase64MaxLength = 200000;

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
    this.istManuell = false,
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

  /// `true` wenn der Held manuell angelegt wurde (kein echtes Spielergeraet).
  final bool istManuell;

  /// Erstellt eine Visitenkarte aus berechneten Heldenwerten.
  factory HeldVisitenkarte.fromHeroComputed(
    HeroSheet hero,
    DerivedStats derivedStats, {
    String? avatarThumbnailBase64,
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
      avatarThumbnailBase64: avatarThumbnailBase64,
      exportedAt: DateTime.now().toUtc(),
    );
  }

  /// Erstellt eine Visitenkarte aus einem manuell angelegten [ExternerHeld].
  factory HeldVisitenkarte.fromExternerHeld(ExternerHeld held) {
    return HeldVisitenkarte(
      heroId: held.id,
      name: held.name,
      rasse: held.rasse,
      kultur: held.kultur,
      profession: held.profession,
      level: held.level,
      maxLep: held.maxLep,
      maxAsp: held.maxAsp,
      maxAu: held.maxAu,
      iniBase: held.iniBase,
      avatarThumbnailBase64: held.avatarThumbnailBase64,
      exportedAt: held.updatedAt,
      istManuell: true,
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
      if (istManuell) 'istManuell': true,
    };
  }

  /// Serialisiert die Visitenkarte fuer Firestore und entfernt uebergrosse
  /// Thumbnail-Payloads, damit der Rest der Karte weiter synchronisiert wird.
  Map<String, dynamic> toFirestoreJson() {
    final json = toJson();
    final thumbnailBase64 = avatarThumbnailBase64;
    if (thumbnailBase64 != null &&
        thumbnailBase64.length > avatarThumbnailBase64MaxLength) {
      json.remove('avatarThumbnailBase64');
    }
    return json;
  }

  static HeldVisitenkarte fromJson(Map<String, dynamic> json) {
    final rawExportedAt = json['exportedAt'] as String? ?? '';
    final exportedAt =
        DateTime.tryParse(rawExportedAt)?.toUtc() ?? DateTime.now().toUtc();

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
      istManuell: json['istManuell'] as bool? ?? false,
    );
  }
}
