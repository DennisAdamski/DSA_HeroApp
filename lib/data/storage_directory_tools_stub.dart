/// Stub fuer Plattformen ohne Dateimanager-Integration.
Future<void> openStorageDirectoryImpl(String path) async {
  throw UnsupportedError(
    'Lokale Verzeichnisse koennen auf dieser Plattform nicht geoeffnet werden.',
  );
}

/// Gibt fuer nicht-IO-Plattformen `false` zurueck.
bool canOpenStorageDirectoryImpl() => false;
