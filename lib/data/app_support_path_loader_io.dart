import 'package:path_provider/path_provider.dart';

/// Laedt den app-spezifischen Support-Pfad auf Plattformen mit Dateisystem.
Future<String> loadApplicationSupportPath() async {
  final directory = await getApplicationSupportDirectory();
  return directory.path;
}
