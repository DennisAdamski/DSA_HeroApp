import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;

/// Speichert Bytes als Datei und gibt den Dateinamen zurueck.
Future<String> saveImageFile({
  required String directoryPath,
  required String fileName,
  required List<int> pngBytes,
}) async {
  final dir = Directory(directoryPath);
  if (!dir.existsSync()) {
    await dir.create(recursive: true);
  }
  final file = File(p.join(dir.path, fileName));
  await file.writeAsBytes(pngBytes, flush: true);
  return fileName;
}

/// Laedt Bytes einer Bilddatei oder gibt null zurueck.
Future<List<int>?> loadImageFileBytes({required String filePath}) async {
  final file = File(filePath);
  if (!file.existsSync()) return null;
  return file.readAsBytes();
}

/// Loescht eine Bilddatei falls vorhanden.
Future<void> deleteImageFile({required String filePath}) async {
  final file = File(filePath);
  if (file.existsSync()) {
    await file.delete();
  }
}

/// Entfernt eine gecachte FileImage-Instanz aus dem Flutter-Cache.
void evictFileImage(String path) {
  FileImage(File(path)).evict();
}
