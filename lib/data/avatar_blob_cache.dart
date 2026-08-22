import 'dart:typed_data';

/// Lokaler Zwischenspeicher fuer Avatarbytes.
///
/// Im Web ist die Firebase-Storage-Ablage der einzige Speicherort; ohne Cache
/// laedt jede Album-Ansicht jedes Bild erneut ueber drei Netzwerkaufrufe.
///
/// Der Cache ist inhaltsadressiert: `AvatarGalleryEntry.fileName` traegt eine
/// UUID und ist unveraenderlich, ein geaendertes Bild bekommt also einen neuen
/// Dateinamen. Ein Ablaufdatum ist deshalb strukturell unnoetig — nur verwaiste
/// Eintraege muessen aufgeraeumt werden.
abstract class AvatarBlobCache {
  /// Liest die Bytes zu [fileName], oder `null` wenn nicht gecacht.
  Future<Uint8List?> read(String fileName);

  /// Legt [bytes] unter [fileName] ab.
  Future<void> write(String fileName, Uint8List bytes);

  /// Entfernt den Eintrag zu [fileName].
  Future<void> remove(String fileName);

  /// Entfernt alle Eintraege, deren Name nicht in [behalten] steht.
  ///
  /// Gibt die Anzahl der entfernten Eintraege zurueck.
  Future<int> entferneVerwaiste(Set<String> behalten);
}

/// Speicherbasierter [AvatarBlobCache] fuer Tests.
class InMemoryAvatarBlobCache implements AvatarBlobCache {
  final Map<String, Uint8List> eintraege = <String, Uint8List>{};

  /// Anzahl der Lesezugriffe, um Cache-Treffer nachweisen zu koennen.
  int readCalls = 0;

  @override
  Future<Uint8List?> read(String fileName) async {
    readCalls++;
    return eintraege[fileName];
  }

  @override
  Future<void> write(String fileName, Uint8List bytes) async {
    eintraege[fileName] = bytes;
  }

  @override
  Future<void> remove(String fileName) async {
    eintraege.remove(fileName);
  }

  @override
  Future<int> entferneVerwaiste(Set<String> behalten) async {
    final verwaist = eintraege.keys
        .where((key) => !behalten.contains(key))
        .toList(growable: false);
    for (final key in verwaist) {
      eintraege.remove(key);
    }
    return verwaist.length;
  }
}
