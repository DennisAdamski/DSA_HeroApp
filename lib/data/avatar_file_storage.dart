import 'dart:typed_data';

import 'package:dsa_heldenverwaltung/data/avatar_blob_cache.dart';

import 'avatar_file_storage_stub.dart'
    if (dart.library.html) 'avatar_file_storage_web.dart'
    if (dart.library.io) 'avatar_file_storage_io.dart';

/// Plattformfassade fuer die Ablage von Avatar-Bildern.
///
/// Die IO-Implementierung schreibt in den `avatare`-Ordner des
/// Heldenspeichers, die Web-Implementierung direkt in Firebase Storage.
/// Aufrufer importieren ausschliesslich diese Datei.
abstract class AvatarFileStorage {
  /// Gibt an, ob diese Implementierung ihre Bytes bereits in der Cloud haelt.
  ///
  /// Nur `false` bedeutet, dass ein zusaetzlicher Cloud-Abgleich noetig ist
  /// (siehe `SyncingAvatarStorage`). Die Web-Implementierung liefert `true`,
  /// weil sie den Cloud-Speicher selbst ist.
  bool get isCloudBacked;

  /// Zwischenspeicher der Implementierung, oder `null` wenn keiner existiert.
  ///
  /// Nur die Cloud-gestuetzte Web-Ablage hat einen; die Dateisystem-Variante
  /// braucht keinen, weil ihre Bytes ohnehin lokal liegen.
  AvatarBlobCache? get blobCache => null;

  /// Speichert PNG-Bytes als Legacy-Hauptavatar und gibt den Dateinamen zurueck.
  ///
  /// Nur noch fuer Bestandsdaten relevant; neue Bilder laufen ueber
  /// [saveGalleryImage].
  Future<String> saveAvatar({
    required String heroStoragePath,
    required String heroId,
    required List<int> pngBytes,
  });

  /// Loest den vollstaendigen Pfad einer Avatar-Datei auf.
  String resolveAvatarPath({
    required String heroStoragePath,
    required String avatarFileName,
  });

  /// Laedt die Bytes des Legacy-Hauptavatars.
  ///
  /// Gibt `null` zurueck, wenn die Datei nicht existiert.
  Future<Uint8List?> loadAvatarBytes({
    required String heroStoragePath,
    required String avatarFileName,
  });

  /// Loescht den Legacy-Hauptavatar eines Helden.
  Future<void> deleteAvatar({
    required String heroStoragePath,
    required String avatarFileName,
  });

  /// Speichert ein Galeriebild und gibt den Dateinamen zurueck.
  ///
  /// Ein leerer Rueckgabewert bedeutet, dass die Ablage fehlgeschlagen ist
  /// (im Web z. B. ohne angemeldeten Nutzer). Aufrufer duerfen daraus keinen
  /// Galerie-Eintrag bauen.
  Future<String> saveGalleryImage({
    required String heroStoragePath,
    required String heroId,
    required String entryId,
    required List<int> pngBytes,
  });

  /// Loescht ein einzelnes Galeriebild.
  Future<void> deleteGalleryImage({
    required String heroStoragePath,
    required String fileName,
  });

  /// Laedt die Bytes eines Galeriebildes.
  ///
  /// Gibt `null` zurueck, wenn das Bild nirgends gefunden wurde.
  Future<Uint8List?> loadGalleryImageBytes({
    required String heroStoragePath,
    required String fileName,
  });
}

/// Erzeugt die zur Plattform passende [AvatarFileStorage].
AvatarFileStorage createAvatarFileStorage() {
  return createAvatarFileStorageImpl();
}
