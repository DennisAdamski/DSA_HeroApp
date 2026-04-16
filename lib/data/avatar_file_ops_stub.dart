/// Web-Stub: Avatar-Dateispeicherung ist ohne Dateisystem nicht verfuegbar.
Future<String> saveImageFile({
  required String directoryPath,
  required String fileName,
  required List<int> pngBytes,
}) async {
  return fileName;
}

/// Web-Stub: Bilddateien koennen nicht geladen werden.
Future<List<int>?> loadImageFileBytes({required String filePath}) async {
  return null;
}

/// Web-Stub: Loeschen ist ohne Dateisystem nicht moeglich.
Future<void> deleteImageFile({required String filePath}) async {}

/// Web-Stub: FileImage-Eviction ist im Browser nicht relevant.
void evictFileImage(String path) {}
