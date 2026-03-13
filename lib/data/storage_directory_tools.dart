import 'storage_directory_tools_stub.dart'
    if (dart.library.io) 'storage_directory_tools_io.dart';

/// Oeffnet ein lokales Verzeichnis im nativen Dateimanager.
Future<void> openStorageDirectory(String path) {
  return openStorageDirectoryImpl(path);
}

/// Prueft, ob das aktuelle Zielsystem das Oeffnen lokaler Verzeichnisse
/// unterstuetzt.
bool canOpenStorageDirectory() {
  return canOpenStorageDirectoryImpl();
}
