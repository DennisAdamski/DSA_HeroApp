import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Web-Stub: Avatarbilder werden im Web nicht aus einem File-Cache geladen,
/// daher gibt es nichts zu invalidieren.
Future<void> evictAvatarImage(String absolutePath) async {
  // No-Op auf Web.
}

/// Web-Stub: Liefert ein leeres Platzhalter-Bild, da im Web keine lokalen
/// Avatarbilder existieren.
ImageProvider<Object> avatarImageFromPath(String absolutePath) {
  return MemoryImage(Uint8List(0));
}
