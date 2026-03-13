import 'dart:io';

/// Oeffnet ein lokales Verzeichnis im nativen Dateimanager.
Future<void> openStorageDirectoryImpl(String path) async {
  late final String executable;
  late final List<String> arguments;

  if (Platform.isWindows) {
    executable = 'explorer.exe';
    arguments = <String>[path];
  } else if (Platform.isMacOS) {
    executable = 'open';
    arguments = <String>[path];
  } else if (Platform.isLinux) {
    executable = 'xdg-open';
    arguments = <String>[path];
  } else {
    throw UnsupportedError(
      'Lokale Verzeichnisse koennen auf dieser Plattform nicht geoeffnet werden.',
    );
  }

  final result = await Process.run(executable, arguments);
  if (result.exitCode != 0) {
    throw ProcessException(
      executable,
      arguments,
      result.stderr?.toString() ?? 'Unbekannter Fehler beim Oeffnen des Ordners.',
      result.exitCode,
    );
  }
}

/// Desktop-Plattformen koennen Verzeichnisse im Dateimanager oeffnen.
bool canOpenStorageDirectoryImpl() {
  return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}
