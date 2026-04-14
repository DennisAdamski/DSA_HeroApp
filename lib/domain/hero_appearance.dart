import 'package:dsa_heldenverwaltung/domain/avatar_gallery_entry.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_snapshot.dart';

/// Aeussere Erscheinung eines Helden.
class HeroAppearance {
  const HeroAppearance({
    this.geschlecht = '',
    this.alter = '',
    this.groesse = '',
    this.gewicht = '',
    this.haarfarbe = '',
    this.augenfarbe = '',
    this.aussehen = '',
    this.avatarFileName = '',
    this.avatarGallery = const [],
    this.primaerbildId = '',
    this.aktivesBildId = '',
    this.avatarSnapshot,
  });

  final String geschlecht;
  final String alter;
  final String groesse;
  final String gewicht;
  final String haarfarbe;
  final String augenfarbe;
  final String aussehen;

  /// Dateiname des aktiven Portraets (leer = kein Avatar).
  final String avatarFileName;

  /// Alle gespeicherten Bilder (KI-generiert und hochgeladen).
  final List<AvatarGalleryEntry> avatarGallery;

  /// ID des Primaerbilds in der Galerie (leer = keins gesetzt).
  /// Das Primaerbild dient als Referenz fuer KI-Prompts.
  final String primaerbildId;

  /// ID des sichtbar gesetzten Bildes in der Galerie (Header + Uebersicht).
  final String aktivesBildId;

  /// Heldendaten-Snapshot zum Zeitpunkt der Primaerbild-Festlegung.
  final AvatarSnapshot? avatarSnapshot;

  HeroAppearance copyWith({
    String? geschlecht,
    String? alter,
    String? groesse,
    String? gewicht,
    String? haarfarbe,
    String? augenfarbe,
    String? aussehen,
    String? avatarFileName,
    List<AvatarGalleryEntry>? avatarGallery,
    String? primaerbildId,
    String? aktivesBildId,
    AvatarSnapshot? Function()? avatarSnapshot,
  }) {
    return HeroAppearance(
      geschlecht: geschlecht ?? this.geschlecht,
      alter: alter ?? this.alter,
      groesse: groesse ?? this.groesse,
      gewicht: gewicht ?? this.gewicht,
      haarfarbe: haarfarbe ?? this.haarfarbe,
      augenfarbe: augenfarbe ?? this.augenfarbe,
      aussehen: aussehen ?? this.aussehen,
      avatarFileName: avatarFileName ?? this.avatarFileName,
      avatarGallery: avatarGallery ?? this.avatarGallery,
      primaerbildId: primaerbildId ?? this.primaerbildId,
      aktivesBildId: aktivesBildId ?? this.aktivesBildId,
      avatarSnapshot:
          avatarSnapshot != null ? avatarSnapshot() : this.avatarSnapshot,
    );
  }

  /// Serialisiert als flache Map (Felder auf Root-Ebene).
  Map<String, dynamic> toJson() => {
        'geschlecht': geschlecht,
        'alter': alter,
        'groesse': groesse,
        'gewicht': gewicht,
        'haarfarbe': haarfarbe,
        'augenfarbe': augenfarbe,
        'aussehen': aussehen,
        'avatarFileName': avatarFileName,
        'avatarGallery':
            avatarGallery.map((e) => e.toJson()).toList(growable: false),
        'primaerbildId': primaerbildId,
        'aktivesBildId': aktivesBildId,
        if (avatarSnapshot != null)
          'avatarSnapshot': avatarSnapshot!.toJson(),
      };

  /// Liest aus einer flachen Map (Felder auf Root-Ebene).
  static HeroAppearance fromJson(Map<String, dynamic> json) {
    final avatarFileName = (json['avatarFileName'] as String?) ?? '';

    final rawGallery = json['avatarGallery'] as List?;
    var gallery = <AvatarGalleryEntry>[];
    if (rawGallery != null) {
      gallery = rawGallery
          .whereType<Map>()
          .map((e) => AvatarGalleryEntry.fromJson(e.cast<String, dynamic>()))
          .toList();
    }

    // Migration: bestehender Avatar ohne Gallery-Eintrag.
    if (avatarFileName.isNotEmpty && gallery.isEmpty) {
      final heroId = avatarFileName.replaceAll('.png', '');
      gallery = [
        AvatarGalleryEntry(
          id: '${heroId}_legacy',
          fileName: avatarFileName,
          quelle: 'ki',
        ),
      ];
    }

    final primaerbildId = (json['primaerbildId'] as String?) ?? '';
    var aktivesBildId = (json['aktivesBildId'] as String?) ?? '';

    // Migration: wenn kein aktives Bild gesetzt, Gallery-Eintrag anhand
    // des Haupt-Avatar-Dateinamens bestimmen, sonst Primaerbild, sonst erstes.
    if (aktivesBildId.isEmpty && gallery.isNotEmpty) {
      if (avatarFileName.isNotEmpty) {
        final match = gallery
            .where((e) => e.fileName == avatarFileName)
            .firstOrNull;
        if (match != null) {
          aktivesBildId = match.id;
        }
      }
      if (aktivesBildId.isEmpty && primaerbildId.isNotEmpty) {
        final match = gallery.where((e) => e.id == primaerbildId).firstOrNull;
        if (match != null) {
          aktivesBildId = match.id;
        }
      }
      if (aktivesBildId.isEmpty) {
        aktivesBildId = gallery.first.id;
      }
    }

    final rawSnapshot = (json['avatarSnapshot'] as Map?)?.cast<String, dynamic>();

    return HeroAppearance(
      geschlecht: (json['geschlecht'] as String?) ?? '',
      alter: (json['alter'] as String?) ?? '',
      groesse: (json['groesse'] as String?) ?? '',
      gewicht: (json['gewicht'] as String?) ?? '',
      haarfarbe: (json['haarfarbe'] as String?) ?? '',
      augenfarbe: (json['augenfarbe'] as String?) ?? '',
      aussehen: (json['aussehen'] as String?) ?? '',
      avatarFileName: avatarFileName,
      avatarGallery: gallery,
      primaerbildId: primaerbildId,
      aktivesBildId: aktivesBildId,
      avatarSnapshot:
          rawSnapshot != null ? AvatarSnapshot.fromJson(rawSnapshot) : null,
    );
  }
}
