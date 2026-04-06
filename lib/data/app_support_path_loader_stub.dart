const String _browserStorageRootPath = 'Browser-Speicher';

/// Liefert einen logischen Speicherort fuer Plattformen ohne Dateisystem.
Future<String> loadApplicationSupportPath() async {
  return _browserStorageRootPath;
}
