import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Adresse der selbst gehosteten Kartenkacheln, gesetzt beim Bauen über
/// `--dart-define=KARTEN_KACHELN=https://…`.
///
/// Leer (Tests, lokale Läufe ohne Kacheln) zeichnet die Karte ohne
/// Kartenbild.
const String kKartenKachelBasis = String.fromEnvironment('KARTEN_KACHELN');

/// Beschreibung der selbst gehosteten Kartenkacheln (`aktuell.json`).
///
/// Erzeugt von `tool/avesmaps_karte_kacheln.py` aus dem Kartenpaket, das
/// Avesmaps über seine Karten-API ausgibt. Die Kacheln liegen unter
/// `<basis>/<revision>/{z}/{x}/{y}.<format>`; die Revision ändert sich mit
/// jedem neuen Kartenbild, die Pfade darunter nie.
class KartenKachelManifest {
  /// Erstellt das Manifest.
  const KartenKachelManifest({
    required this.basis,
    required this.revision,
    required this.maxZoom,
    this.serie = '',
    this.format = 'webp',
    this.kachelPixel = 512,
    this.nennung = const <String>[],
    this.lizenzUri = '',
    this.logo = '',
  });

  /// Adresse der Karten-Site (ohne abschließenden Schrägstrich).
  final Uri basis;

  /// Kennung des Kartenbilds; Teil jedes Kachelpfads.
  final String revision;

  /// Größte Zoomstufe mit eigenen Kacheln.
  final int maxZoom;

  /// Kartenserie bei Avesmaps (`modern`, `original`, `old`).
  final String serie;

  /// Dateiendung der Kacheln.
  final String format;

  /// Kantenlänge einer Kachel in px.
  final int kachelPixel;

  /// Pflichtzeilen der Namensnennung aus dem Kartenpaket.
  final List<String> nennung;

  /// Adresse der Lizenz des Kartenmaterials.
  final String lizenzUri;

  /// Dateiname des Fanprojekt-Logos neben den Kacheln, oder leer.
  final String logo;

  /// Adresse der Kachel ([z], [x], [y]); `y` zählt von Norden.
  Uri kachel(int z, int x, int y) =>
      basis.replace(path: '${basis.path}/$revision/$z/$x/$y.$format');

  /// Adresse des Logos, oder `null`.
  Uri? get logoAdresse => logo.isEmpty
      ? null
      : basis.replace(path: '${basis.path}/$revision/$logo');

  /// Liest das Manifest; `null`, wenn Revision oder Zoom fehlen.
  static KartenKachelManifest? ausJson(Uri basis, Object? roh) {
    if (roh is! Map) return null;
    final revision = roh['revision'];
    final maxZoom = roh['maxZoom'];
    if (revision is! String ||
        !RegExp(r'^[0-9a-f]{8,64}$').hasMatch(revision)) {
      return null;
    }
    if (maxZoom is! int || maxZoom < 0 || maxZoom > 8) return null;
    final format = roh['format'];
    final kachel = roh['tileSize'];
    final nennung = roh['nennung'];
    String text(Object? wert) => wert is String ? wert.trim() : '';
    return KartenKachelManifest(
      basis: _ohneSchraegstrich(basis),
      revision: revision,
      maxZoom: maxZoom,
      serie: text(roh['serie']),
      format: format is String && RegExp(r'^[a-z]{3,4}$').hasMatch(format)
          ? format
          : 'webp',
      kachelPixel: kachel is int && kachel > 0 ? kachel : 512,
      nennung: nennung is List
          ? List<String>.unmodifiable(<String>[
              for (final zeile in nennung)
                if (zeile is String && zeile.trim().isNotEmpty) zeile.trim(),
            ])
          : const <String>[],
      lizenzUri: text(roh['lizenzUri']),
      logo: RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(text(roh['logo']))
          ? text(roh['logo'])
          : '',
    );
  }

  static Uri _ohneSchraegstrich(Uri basis) => basis.path.endsWith('/')
      ? basis.replace(path: basis.path.substring(0, basis.path.length - 1))
      : basis;
}

/// Lädt das Manifest von [basis] (`aktuell.json`); `null` bei jedem Fehler.
///
/// Die Karte zeichnet dann ohne Kartenbild, aus den Ortsdaten allein.
Future<KartenKachelManifest?> ladeKartenKachelManifest(
  Uri basis, {
  http.Client? client,
  Duration timeout = const Duration(seconds: 10),
}) async {
  final eigener = client == null;
  final c = client ?? http.Client();
  try {
    final adresse = KartenKachelManifest._ohneSchraegstrich(basis);
    final antwort = await c
        .get(adresse.replace(path: '${adresse.path}/aktuell.json'))
        .timeout(timeout);
    if (antwort.statusCode != 200) return null;
    return KartenKachelManifest.ausJson(
      adresse,
      jsonDecode(utf8.decode(antwort.bodyBytes)),
    );
  } on Object {
    return null;
  } finally {
    if (eigener) c.close();
  }
}
