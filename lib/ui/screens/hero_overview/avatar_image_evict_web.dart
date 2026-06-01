import 'dart:ui' as ui;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Web: Invalidiert den Cache fuer ein Firebase-Storage-Avatarbild.
Future<void> evictAvatarImage(String storagePath) async {
  if (storagePath.isEmpty) return;
  await FirebaseStorageImageProvider(storagePath).evict();
}

/// Web: Liefert einen [ImageProvider] der Bilddaten aus Firebase Storage laedt.
ImageProvider<Object> avatarImageFromPath(String storagePath) {
  if (storagePath.isEmpty) return MemoryImage(Uint8List(0));
  return FirebaseStorageImageProvider(storagePath);
}

/// Laedt ein Bild aus Firebase Storage anhand des Referenzpfads.
class FirebaseStorageImageProvider
    extends ImageProvider<FirebaseStorageImageProvider> {
  const FirebaseStorageImageProvider(this.storagePath);

  final String storagePath;

  @override
  Future<FirebaseStorageImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture<FirebaseStorageImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    FirebaseStorageImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(_loadAsync(key, decode));
  }

  Future<ImageInfo> _loadAsync(
    FirebaseStorageImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    final ref = FirebaseStorage.instance.ref(key.storagePath);
    final data = await ref.getData();
    if (data == null || data.isEmpty) {
      throw Exception('Bild nicht gefunden: ${key.storagePath}');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(data);
    final codec = await decode(buffer);
    final frame = await codec.getNextFrame();
    return ImageInfo(image: frame.image);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FirebaseStorageImageProvider && other.storagePath == storagePath;

  @override
  int get hashCode => storagePath.hashCode;

  @override
  String toString() => 'FirebaseStorageImageProvider("$storagePath")';
}
