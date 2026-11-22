import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/digests/sha256.dart';

/// SHA-256 der `sqlite3.wasm` aus dem GitHub-Release `sqlite3-<version>` von
/// simolus3/sqlite3.dart, je aufgelöster Paketversion.
///
/// Ein Versatz zwischen `package:sqlite3` und `web/sqlite3.wasm` fällt nicht
/// beim Kompilieren auf, sondern erst zur Laufzeit im Browser (Regel-
/// Nachschlag im Web). Hebt `pubspec.lock` die Version an (auch ohne Änderung
/// an `pubspec.yaml`), die passende Datei nach `web/sqlite3.wasm` legen und
/// hier mit dem Digest aus dem Release eintragen.
const Map<String, String> _wasmSha256JeVersion = <String, String>{
  '3.9.1': 'e7451780e78c56ff864fe9317a0fbcd6aeb2e8de3beba7f5efd963202f7ec3d9',
};

/// Liest die aufgelöste Version von `sqlite3` aus `pubspec.lock`.
///
/// Bewusst ein kleiner eigener Parser statt einer YAML-Abhängigkeit: Der
/// Paketeintrag ist flach und stabil.
String? _aufgeloesteSqlite3Version() {
  final zeilen = File('pubspec.lock').readAsLinesSync();
  var imPaket = false;
  for (final zeile in zeilen) {
    if (zeile == '  sqlite3:') {
      imPaket = true;
      continue;
    }
    if (!imPaket) continue;
    // Ein Schlüssel auf Paketebene beendet den Eintrag.
    if (zeile.startsWith('  ') && !zeile.startsWith('   ')) break;
    final treffer = RegExp(r'^    version: "([^"]+)"$').firstMatch(zeile);
    if (treffer != null) return treffer.group(1);
  }
  return null;
}

String _sha256Hex(Uint8List bytes) {
  final digest = SHA256Digest().process(bytes);
  return digest.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

void main() {
  test('web/sqlite3.wasm passt zur aufgelösten sqlite3-Version', () {
    final version = _aufgeloesteSqlite3Version();
    expect(version, isNotNull, reason: 'sqlite3 fehlt in pubspec.lock');

    final erwartet = _wasmSha256JeVersion[version];
    expect(
      erwartet,
      isNotNull,
      reason:
          'sqlite3 $version ist aufgelöst, aber kein Digest hinterlegt: '
          'sqlite3.wasm aus dem Release sqlite3-$version nach web/ legen und '
          'in _wasmSha256JeVersion eintragen.',
    );

    final ist = _sha256Hex(File('web/sqlite3.wasm').readAsBytesSync());
    expect(
      ist,
      erwartet,
      reason: 'web/sqlite3.wasm stammt nicht aus dem Release sqlite3-$version.',
    );
  });
}
