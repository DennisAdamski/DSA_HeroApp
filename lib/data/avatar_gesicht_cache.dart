import 'package:dsa_heldenverwaltung/domain/avatar_gesichtsbefund.dart';

/// Gespeicherter Befund samt den Angaben, die ihn als aktuell ausweisen.
class AvatarGesichtCacheEintrag {
  const AvatarGesichtCacheEintrag({
    required this.version,
    required this.byteLaenge,
    required this.befund,
  });

  /// `kAvatarGesichtDetektorVersion` zum Zeitpunkt der Erkennung.
  final int version;

  /// Groesse der ausgewerteten Datei.
  ///
  /// Schuetzt den Legacy-Namen `{heroId}.png`: Er traegt keine UUID und kann
  /// beim erneuten Import ueberschrieben werden.
  final int byteLaenge;

  final AvatarGesichtsbefund befund;

  Map<String, dynamic> toJson() => {
    'v': version,
    'n': byteLaenge,
    'b': befund.toJson(),
  };

  static AvatarGesichtCacheEintrag? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final version = raw['v'];
    final byteLaenge = raw['n'];
    final befund = AvatarGesichtsbefund.fromJson(raw['b']);
    if (version is! num || byteLaenge is! num || befund == null) return null;
    return AvatarGesichtCacheEintrag(
      version: version.toInt(),
      byteLaenge: byteLaenge.toInt(),
      befund: befund,
    );
  }
}

/// Lokaler Zwischenspeicher fuer Gesichtsbefunde, geschluesselt nach
/// `AvatarGalleryEntry.fileName`.
///
/// Inhaltsadressiert wie der `AvatarBlobCache`: Die Dateinamen tragen eine
/// UUID, ein geaendertes Bild bekommt einen neuen Namen. Die wenigen Byte je
/// Eintrag lohnen kein Aufraeumen verwaister Eintraege.
abstract class AvatarGesichtCache {
  /// Liest den Eintrag zu [fileName], oder `null`.
  Future<AvatarGesichtCacheEintrag?> lese(String fileName);

  /// Legt [eintrag] unter [fileName] ab.
  Future<void> schreibe(String fileName, AvatarGesichtCacheEintrag eintrag);
}

/// Speicherbasierter [AvatarGesichtCache] fuer Tests.
class InMemoryAvatarGesichtCache implements AvatarGesichtCache {
  final Map<String, AvatarGesichtCacheEintrag> eintraege = {};

  /// Anzahl der Schreibzugriffe, um Cache-Nutzung nachweisen zu koennen.
  int schreibvorgaenge = 0;

  @override
  Future<AvatarGesichtCacheEintrag?> lese(String fileName) async {
    return eintraege[fileName];
  }

  @override
  Future<void> schreibe(
    String fileName,
    AvatarGesichtCacheEintrag eintrag,
  ) async {
    schreibvorgaenge++;
    eintraege[fileName] = eintrag;
  }
}
