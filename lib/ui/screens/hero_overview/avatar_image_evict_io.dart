import 'dart:io';

import 'package:flutter/widgets.dart';

/// Entfernt das durch [absolutePath] referenzierte Bild aus dem Image-Cache,
/// damit ein neu geschriebenes Avatarbild nicht aus dem Cache gerendert wird.
Future<void> evictAvatarImage(String absolutePath) async {
  await FileImage(File(absolutePath)).evict();
}

/// Liefert einen [ImageProvider] fuer eine Bilddatei im lokalen Heldenspeicher.
ImageProvider<Object> avatarImageFromPath(String absolutePath) {
  return FileImage(File(absolutePath));
}
