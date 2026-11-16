import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'package:dsa_heldenverwaltung/data/karte/karten_kachel_manifest.dart';
import 'package:dsa_heldenverwaltung/domain/avesmaps_ort.dart';
import 'package:dsa_heldenverwaltung/rules/derived/karten_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/karte/karto_karten_kamera.dart';
import 'package:dsa_heldenverwaltung/ui2/karte/karto_karten_stil.dart';

/// Kennung einer Kachel: Zoomstufe, Spalte von Westen, Zeile von Norden.
typedef KachelNummer = (int z, int x, int y);

/// Zoomstufe der Kacheln, die bei [kamera] gezeichnet werden.
///
/// Gerundet und gedeckelt auf [maxZoom]; darüber werden die Kacheln der
/// höchsten Stufe vergrößert.
int kachelStufe(KartenKamera kamera, int maxZoom) =>
    kamera.zoom.round().clamp(0, maxZoom);

/// Die Kacheln der Stufe [z], die [sichtbar] berühren.
List<KachelNummer> kachelnIm(KartenRechteck sichtbar, int z) {
  final anzahl = 1 << z;
  final kante = kKartenKante / anzahl;
  int spalte(double wert) => (wert / kante).floor().clamp(0, anzahl - 1);
  final x0 = spalte(sichtbar.minX);
  final x1 = spalte(sichtbar.maxX);
  // Zeilen zählen von Norden, die Karte von Süden.
  final y0 = spalte(kKartenKante - sichtbar.maxY);
  final y1 = spalte(kKartenKante - sichtbar.minY);
  if (sichtbar.maxX < 0 ||
      sichtbar.minX > kKartenKante ||
      sichtbar.maxY < 0 ||
      sichtbar.minY > kKartenKante) {
    return const <KachelNummer>[];
  }
  return <KachelNummer>[
    for (var y = y0; y <= y1; y++)
      for (var x = x0; x <= x1; x++) (z, x, y),
  ];
}

/// Fläche der Kachel [k] in Karteneinheiten.
KartenRechteck kachelFlaeche(KachelNummer k) {
  final (z, x, y) = k;
  final kante = kKartenKante / (1 << z);
  final nord = kKartenKante - y * kante;
  return KartenRechteck(x * kante, nord - kante, (x + 1) * kante, nord);
}

/// Lädt und hält Kartenkacheln, die zuletzt genutzten zuerst.
///
/// Der Maler fragt mit [bild]; fehlt eine Kachel, nimmt er eine gröbere
/// Stufe als Platzhalter. Geladen wird nur über [benoetige], nie beim
/// Zeichnen. Eine fehlgeschlagene Kachel wird in dieser Sitzung nicht noch
/// einmal angefragt.
class KartenKachelSpeicher extends ChangeNotifier {
  /// Erstellt den Speicher für höchstens [grenze] Kacheln.
  KartenKachelSpeicher({this.grenze = 160});

  /// Höchstzahl gehaltener Kacheln.
  final int grenze;

  KartenKachelManifest? _manifest;
  final LinkedHashMap<KachelNummer, ui.Image> _bilder =
      LinkedHashMap<KachelNummer, ui.Image>();
  final Map<KachelNummer, (ImageStream, ImageStreamListener)> _laufend =
      <KachelNummer, (ImageStream, ImageStreamListener)>{};
  final Set<KachelNummer> _fehlgeschlagen = <KachelNummer>{};
  bool _entsorgt = false;

  /// Das Manifest der Kacheln; `null` heißt: ohne Kartenbild.
  KartenKachelManifest? get manifest => _manifest;

  set manifest(KartenKachelManifest? neu) {
    if (neu?.revision == _manifest?.revision &&
        neu?.basis == _manifest?.basis) {
      _manifest = neu;
      return;
    }
    _leere();
    _manifest = neu;
    notifyListeners();
  }

  /// Die geladene Kachel [k], oder `null`.
  ui.Image? bild(KachelNummer k) => _bilder[k];

  /// Lädt die Kacheln [kacheln], soweit sie fehlen.
  void benoetige(Iterable<KachelNummer> kacheln) {
    final manifest = _manifest;
    if (manifest == null || _entsorgt) return;
    for (final k in kacheln) {
      final vorhanden = _bilder.remove(k);
      if (vorhanden != null) {
        _bilder[k] = vorhanden; // zuletzt genutzt
        continue;
      }
      if (_laufend.containsKey(k) || _fehlgeschlagen.contains(k)) continue;
      final (z, x, y) = k;
      final stream = NetworkImage(manifest.kachel(z, x, y).toString())
          .resolve(ImageConfiguration.empty);
      late final ImageStreamListener hoerer;
      hoerer = ImageStreamListener(
        (info, _) {
          _laufend.remove(k);
          stream.removeListener(hoerer);
          if (_entsorgt || !identical(_manifest, manifest)) {
            info.dispose();
            return;
          }
          _bilder[k] = info.image.clone();
          info.dispose();
          _kuerze();
          notifyListeners();
        },
        onError: (_, _) {
          _laufend.remove(k);
          stream.removeListener(hoerer);
          _fehlgeschlagen.add(k);
        },
      );
      _laufend[k] = (stream, hoerer);
      stream.addListener(hoerer);
    }
  }

  void _kuerze() {
    while (_bilder.length > grenze) {
      final aeltester = _bilder.keys.first;
      _bilder.remove(aeltester)?.dispose();
    }
  }

  void _leere() {
    for (final (stream, hoerer) in _laufend.values) {
      stream.removeListener(hoerer);
    }
    _laufend.clear();
    for (final bild in _bilder.values) {
      bild.dispose();
    }
    _bilder.clear();
    _fehlgeschlagen.clear();
  }

  @override
  void dispose() {
    _entsorgt = true;
    _leere();
    super.dispose();
  }
}

/// Auflösung des Landschimmers in px je Karteneinheit.
const double _landAufloesung = 0.5;

/// Zeichnet den Landschimmer: weiche Flächen um alle Orte, als Ersatz für
/// das Kartenbild. Aus der Ortsdichte zeichnet sich so der Kontinent ab.
///
/// Liefert `null`, wenn das Bild nicht erzeugt werden kann (etwa ohne
/// Grafikkontext); die Karte zeigt dann nur Papier.
ui.Image? zeichneLandschimmer(List<AvesmapsOrt> orte, {required bool dunkel}) {
  if (orte.isEmpty) return null;
  try {
    final kante = (kKartenKante * _landAufloesung).round();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.scale(_landAufloesung);
    canvas.saveLayer(
      const ui.Rect.fromLTWH(0, 0, kKartenKante, kKartenKante),
      ui.Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
    );
    final farbe = ui.Paint()
      ..color = dunkel ? KartenFarben.landDunkel : KartenFarben.land;
    for (final ort in orte) {
      // Bedeutende Orte tragen mehr Umland.
      final radius = 6 + 2.0 * (kartenVorrang(ort.art) - 3).clamp(0, 4);
      canvas.drawCircle(ui.Offset(ort.x, kKartenKante - ort.y), radius, farbe);
    }
    canvas.restore();
    final picture = recorder.endRecording();
    final bild = picture.toImageSync(kante, kante);
    picture.dispose();
    return bild;
  } on Object {
    return null;
  }
}
