import 'package:flutter/foundation.dart';

import 'package:dsa_heldenverwaltung/data/avatar_blob_cache.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';

/// Raeumt Cache-Eintraege weg, die zu keinem Galerie-Eintrag mehr gehoeren.
///
/// Noetig, weil der Cache selbst nie veraltet (inhaltsadressierte Dateinamen):
/// Ohne diesen Lauf blieben die Bytes eines geloeschten Bildes dauerhaft im
/// Browserspeicher liegen.
///
/// Laeuft wie der Backfill bewusst **nach** `syncNow()`. Vorher waere die
/// lokale Galerie veraltet und der Aufraeumer wuerde gerade erst
/// synchronisierte Bilder wegwerfen.
class AvatarCacheReconciler {
  const AvatarCacheReconciler({required this.cache});

  /// Zu bereinigender Zwischenspeicher.
  final AvatarBlobCache cache;

  /// Entfernt alle Cache-Eintraege, die von [heroes] nicht referenziert werden.
  ///
  /// Gibt die Anzahl der entfernten Eintraege zurueck; Fehler bleiben folgenlos.
  Future<int> run({required List<HeroSheet> heroes}) async {
    final referenziert = <String>{
      for (final hero in heroes)
        for (final entry in hero.appearance.avatarGallery)
          if (entry.fileName.isNotEmpty) entry.fileName,
    };

    try {
      return await cache.entferneVerwaiste(referenziert);
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'avatar_cache_reconciler',
          context: ErrorDescription(
            'Avatar-Cache konnte nicht aufgeraeumt werden',
          ),
        ),
      );
      return 0;
    }
  }
}
