import 'package:flutter/foundation.dart';

import 'package:dsa_heldenverwaltung/data/avatar_file_storage.dart';
import 'package:dsa_heldenverwaltung/data/cloud_avatar_storage.dart';
import 'package:dsa_heldenverwaltung/data/hive_avatar_sync_marker_store.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';

/// Ergebnis eines Backfill-Laufs.
class AvatarBackfillReport {
  const AvatarBackfillReport({
    this.uploaded = 0,
    this.downloaded = 0,
    this.skipped = 0,
    this.failed = 0,
    this.missing = 0,
    this.verwaisteEntfernt = 0,
    this.zuletztGelaufen,
  });

  /// Lokal vorhandene Bilder, die in die Cloud gewandert sind.
  final int uploaded;

  /// Aus der Cloud nachgeladene Bilder.
  final int downloaded;

  /// Bereits abgeglichene Bilder.
  final int skipped;

  /// Eintraege, die fehlgeschlagen sind und beim naechsten Lauf erneut drankommen.
  final int failed;

  /// Eintraege, deren Bytes auf keiner Seite mehr existieren.
  final int missing;

  /// Aus dem Browser-Cache entfernte Eintraege ohne Galerie-Bezug.
  final int verwaisteEntfernt;

  /// Ende des Laufs; `null` solange kein Lauf abgeschlossen ist.
  final DateTime? zuletztGelaufen;

  /// Deutsche Zusammenfassung fuer die Statuszeile in den Einstellungen.
  String get beschreibung {
    final teile = <String>[
      if (uploaded > 0) '$uploaded hochgeladen',
      if (downloaded > 0) '$downloaded geladen',
      if (failed > 0) '$failed fehlgeschlagen',
      if (missing > 0) '$missing ohne Bilddatei',
      if (verwaisteEntfernt > 0) '$verwaisteEntfernt verwaiste entfernt',
    ];
    if (teile.isEmpty) {
      return 'Alle Avatarbilder sind abgeglichen.';
    }
    return teile.join(', ');
  }

  /// Markiert den Lauf als beendet.
  AvatarBackfillReport abgeschlossen(DateTime zeitpunkt) {
    return AvatarBackfillReport(
      uploaded: uploaded,
      downloaded: downloaded,
      skipped: skipped,
      failed: failed,
      missing: missing,
      verwaisteEntfernt: verwaisteEntfernt,
      zuletztGelaufen: zeitpunkt,
    );
  }

  AvatarBackfillReport _plus({
    int uploaded = 0,
    int downloaded = 0,
    int skipped = 0,
    int failed = 0,
    int missing = 0,
  }) {
    return AvatarBackfillReport(
      uploaded: this.uploaded + uploaded,
      downloaded: this.downloaded + downloaded,
      skipped: this.skipped + skipped,
      failed: this.failed + failed,
      missing: this.missing + missing,
      verwaisteEntfernt: verwaisteEntfernt,
      zuletztGelaufen: zuletztGelaufen,
    );
  }

  @override
  String toString() {
    return 'AvatarBackfillReport(uploaded: $uploaded, '
        'downloaded: $downloaded, skipped: $skipped, failed: $failed, '
        'missing: $missing, verwaisteEntfernt: $verwaisteEntfernt)';
  }
}

/// Gleicht die Avatarbilder bestehender Helden mit der Cloud ab.
///
/// Noetig, weil der Konto-Sync nur die Heldendaten uebertraegt: Ohne diesen
/// Lauf kaeme ein vor dieser Funktion angelegter Held im Web mit gefuellter
/// Galerie, aber ohne Bilddateien an.
///
/// Der Lauf ist durchgaengig Best-Effort. Ein Fehlschlag setzt bewusst
/// **keinen** Marker, damit der naechste Start es erneut versucht.
///
/// Der Service schreibt **niemals** ueber das Helden-Repository. Ein
/// `saveHero()` wuerde `lastModified` anfassen, das Heldendokument pushen und
/// bei jedem Start eine Konfliktwelle ausloesen.
class AvatarBackfillService {
  const AvatarBackfillService({
    required this.storage,
    required this.cloud,
    required this.markers,
  });

  /// Lokale Ablage; hier ist bewusst die **rohe** Plattformablage gemeint,
  /// nicht der `SyncingAvatarStorage` — sonst laedt schon das Lesen nach.
  final AvatarFileStorage storage;

  /// Cloud-Gegenstelle.
  final CloudAvatarStorage cloud;

  /// Vermerke bereits abgeglichener Dateien.
  final AvatarSyncMarkerStore markers;

  /// Gleicht alle Galeriebilder von [heroes] ab.
  Future<AvatarBackfillReport> run({
    required List<HeroSheet> heroes,
    required String heroStoragePath,
  }) async {
    var report = const AvatarBackfillReport();
    if (!cloud.isAvailable) return report;

    final seen = <String>{};
    for (final hero in heroes) {
      for (final entry in hero.appearance.avatarGallery) {
        final fileName = entry.fileName;
        if (fileName.isEmpty || !seen.add(fileName)) continue;
        report = await _syncFile(fileName, heroStoragePath, report);
      }
    }
    return report.abgeschlossen(DateTime.now().toUtc());
  }

  Future<AvatarBackfillReport> _syncFile(
    String fileName,
    String heroStoragePath,
    AvatarBackfillReport report,
  ) async {
    try {
      // Der Dateiname wird nie aus heroId und entryId rekonstruiert: Legacy-
      // Eintraege heissen `{heroId}.png` und wuerden dabei verlorengehen.
      final localBytes = await storage.loadGalleryImageBytes(
        heroStoragePath: heroStoragePath,
        fileName: fileName,
      );

      final marker = markers.load(fileName);
      if (marker != null && marker.byteLength == (localBytes?.length ?? -1)) {
        return report._plus(skipped: 1);
      }

      if (localBytes != null) {
        if (await cloud.exists(fileName)) {
          await _mark(fileName, localBytes.length);
          return report._plus(skipped: 1);
        }
        await cloud.upload(fileName, localBytes);
        await _mark(fileName, localBytes.length);
        return report._plus(uploaded: 1);
      }

      final remoteBytes = await cloud.download(fileName);
      if (remoteBytes == null) {
        return report._plus(missing: 1);
      }
      await _cacheLocally(heroStoragePath, fileName, remoteBytes);
      await _mark(fileName, remoteBytes.length);
      return report._plus(downloaded: 1);
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'avatar_backfill_service',
          context: ErrorDescription(
            'Avatarbild $fileName konnte nicht abgeglichen werden',
          ),
        ),
      );
      return report._plus(failed: 1);
    }
  }

  Future<void> _mark(String fileName, int byteLength) {
    return markers.save(
      fileName,
      AvatarSyncMarker(
        byteLength: byteLength,
        syncedAt: DateTime.now().toUtc(),
      ),
    );
  }

  /// Legt Bytes unter exakt [fileName] lokal ab.
  ///
  /// `saveGalleryImage` setzt den Namen aus `heroId` und `entryId` zusammen und
  /// kann Legacy-Namen deshalb nicht treffen; `saveAvatar` haengt nur `.png` an.
  Future<void> _cacheLocally(
    String heroStoragePath,
    String fileName,
    List<int> bytes,
  ) {
    final baseName = fileName.endsWith('.png')
        ? fileName.substring(0, fileName.length - 4)
        : fileName;
    return storage.saveAvatar(
      heroStoragePath: heroStoragePath,
      heroId: baseName,
      pngBytes: bytes,
    );
  }
}
