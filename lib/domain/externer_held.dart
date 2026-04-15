import 'package:dsa_heldenverwaltung/domain/held_visitenkarte.dart';

/// Externes Gruppenmitglied — entweder manuell angelegt oder ueber
/// Firebase mit einem anderen Spieler verknuepft.
///
/// Speichert nur Basisdaten (Visitenkarten-Niveau).  Wird in einer
/// eigenen Hive-Box persistiert und steht allen lokalen Helden zur
/// Verfuegung.
class ExternerHeld {
  const ExternerHeld({
    required this.id,
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
    this.quelleHeroId,
    this.notizen = '',
    required this.updatedAt,
  });

  /// Stabile UUID.
  final String id;

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

  /// Quell-HeroId des verknuepften Spielers.
  /// `null` bedeutet manuell angelegt.
  final String? quelleHeroId;

  /// Freitext-Notizen (vor allem fuer manuelle Helden).
  final String notizen;

  /// Letzter Aktualisierungszeitpunkt (UTC).
  final DateTime updatedAt;

  /// `true` wenn dieser Held ueber Firebase verknuepft ist.
  bool get istVerknuepft =>
      quelleHeroId != null && quelleHeroId!.isNotEmpty;

  /// `true` wenn dieser Held manuell angelegt wurde.
  bool get istManuell => !istVerknuepft;

  /// Erstellt einen [ExternerHeld] aus einer [HeldVisitenkarte].
  ///
  /// Manuell angelegte Helden (`karte.istManuell`) behalten
  /// `quelleHeroId == null`, damit [istManuell] korrekt bleibt.
  factory ExternerHeld.fromVisitenkarte(
    HeldVisitenkarte karte, {
    String? id,
  }) {
    return ExternerHeld(
      id: id ?? karte.heroId,
      name: karte.name,
      rasse: karte.rasse,
      kultur: karte.kultur,
      profession: karte.profession,
      level: karte.level,
      maxLep: karte.maxLep,
      maxAsp: karte.maxAsp,
      maxAu: karte.maxAu,
      iniBase: karte.iniBase,
      avatarThumbnailBase64: karte.avatarThumbnailBase64,
      quelleHeroId: karte.istManuell ? null : karte.heroId,
      updatedAt: karte.exportedAt,
    );
  }

  ExternerHeld copyWith({
    String? id,
    String? name,
    String? rasse,
    String? kultur,
    String? profession,
    int? level,
    int? maxLep,
    int? maxAsp,
    int? maxAu,
    int? iniBase,
    String? avatarThumbnailBase64,
    String? quelleHeroId,
    String? notizen,
    DateTime? updatedAt,
  }) {
    return ExternerHeld(
      id: id ?? this.id,
      name: name ?? this.name,
      rasse: rasse ?? this.rasse,
      kultur: kultur ?? this.kultur,
      profession: profession ?? this.profession,
      level: level ?? this.level,
      maxLep: maxLep ?? this.maxLep,
      maxAsp: maxAsp ?? this.maxAsp,
      maxAu: maxAu ?? this.maxAu,
      iniBase: iniBase ?? this.iniBase,
      avatarThumbnailBase64:
          avatarThumbnailBase64 ?? this.avatarThumbnailBase64,
      quelleHeroId: quelleHeroId ?? this.quelleHeroId,
      notizen: notizen ?? this.notizen,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
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
      if (quelleHeroId != null) 'quelleHeroId': quelleHeroId,
      'notizen': notizen,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  static ExternerHeld fromJson(Map<String, dynamic> json) {
    final rawUpdatedAt = json['updatedAt'] as String? ?? '';
    final updatedAt =
        DateTime.tryParse(rawUpdatedAt)?.toUtc() ?? DateTime.now().toUtc();

    return ExternerHeld(
      id: json['id'] as String? ?? '',
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
      quelleHeroId: json['quelleHeroId'] as String?,
      notizen: json['notizen'] as String? ?? '',
      updatedAt: updatedAt,
    );
  }
}
