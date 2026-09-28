import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:dsa_heldenverwaltung/data/avatar_gesicht/blazeface_erkennung.dart';
import 'package:dsa_heldenverwaltung/data/avatar_gesicht/blazeface_modell.dart';
import 'package:dsa_heldenverwaltung/data/avatar_gesicht/blazeface_rechenkern.dart';
import 'package:dsa_heldenverwaltung/domain/avatar_gesichtsbefund.dart';

/// Version von Modell und Auswertung.
///
/// Steigt, sobald sich Modell, Schwellen oder Kachelsuche aendern. Der Cache
/// verwirft Befunde anderer Versionen und erkennt neu.
const int kAvatarGesichtDetektorVersion = 1;

/// Laengste Bildseite, auf die vor der Erkennung verkleinert wird.
///
/// Reicht fuer die Kacheln des zweiten Durchlaufs: Bei 512 px ist eine Kachel
/// 128 px oder groesser und wird nie hochskaliert.
const int kAvatarGesichtAnalyseKante = 512;

/// Findet das Gesicht in einem Avatarbild.
abstract interface class AvatarGesichtserkennung {
  /// Wertet kodierte Bildbytes (PNG, JPEG, ...) aus.
  ///
  /// Wirft bei nicht dekodierbaren Bytes; ein Bild ohne Gesicht ergibt einen
  /// Befund ohne [AvatarGesichtsbefund.gesicht].
  Future<AvatarGesichtsbefund> erkenne(Uint8List bildBytes);
}

/// [AvatarGesichtserkennung] mit BlazeFace in reinem Dart.
///
/// Dekodiert und verkleinert ueber `dart:ui` im Haupt-Isolate, weil
/// Bilddekoder dort liegen. Das Netz rechnet nativ in einem Hintergrund-
/// Isolate; im Web gibt es keines, dort laeuft es inline und gibt zwischen
/// den Schichten die Kontrolle ab, damit die Oberflaeche fluessig bleibt.
class BlazeFaceGesichtserkennung implements AvatarGesichtserkennung {
  BlazeFaceGesichtserkennung({Future<Uint8List> Function()? ladeModell})
    : _ladeModell = ladeModell ?? _ladeModellAsset;

  final Future<Uint8List> Function() _ladeModell;
  Future<Uint8List>? _modellBytes;
  BlazeFaceErkennung? _inlineErkennung;

  @override
  Future<AvatarGesichtsbefund> erkenne(Uint8List bildBytes) async {
    final bild = await dekodiereFuerAnalyse(bildBytes);
    final modellBytes = await (_modellBytes ??= _ladeModell());
    final auftrag = (
      modell: modellBytes,
      pixel: bild.rgba.pixel,
      breite: bild.rgba.breite,
      hoehe: bild.rgba.hoehe,
    );
    final ({
      double links,
      double oben,
      double rechts,
      double unten,
      double score,
    })?
    treffer;
    if (kIsWeb) {
      final erkennung = _inlineErkennung ??= BlazeFaceErkennung(
        BlazeFaceRechenkern(BlazeFaceModell.ausBytes(modellBytes)),
      );
      final roh = await erkennung.sucheHauptgesicht(
        bild.rgba,
        pause: _zeitscheibenPause(),
      );
      treffer = roh == null ? null : _alsRecord(roh);
    } else {
      treffer = await compute(_sucheImIsolat, auftrag);
    }
    return befundAusTreffer(
      bildBreite: bild.originalBreite,
      bildHoehe: bild.originalHoehe,
      treffer: treffer,
    );
  }

  static Future<Uint8List> _ladeModellAsset() async {
    final daten = await rootBundle.load(kBlazeFaceModellAsset);
    return daten.buffer.asUint8List(daten.offsetInBytes, daten.lengthInBytes);
  }
}

/// Dekodiertes Analysebild samt Originalgroesse.
typedef AvatarAnalyseBild = ({
  RgbaBild rgba,
  int originalBreite,
  int originalHoehe,
});

/// Dekodiert [bytes] und verkleinert seitentreu auf hoechstens
/// [kAvatarGesichtAnalyseKante] Pixel Kantenlaenge.
///
/// `instantiateImageCodecWithSize` liefert die Originalgroesse und dekodiert
/// in einem Schritt direkt verkleinert — auch im Web, wo `ResizeImage`
/// denselben Weg nimmt.
Future<AvatarAnalyseBild> dekodiereFuerAnalyse(Uint8List bytes) async {
  var originalBreite = 0;
  var originalHoehe = 0;
  final puffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  ui.Codec? codec;
  ui.Image? bild;
  try {
    codec = await ui.instantiateImageCodecWithSize(
      puffer,
      getTargetSize: (breite, hoehe) {
        originalBreite = breite;
        originalHoehe = hoehe;
        final kante = math.max(breite, hoehe);
        if (kante <= kAvatarGesichtAnalyseKante) {
          return ui.TargetImageSize(width: breite, height: hoehe);
        }
        final faktor = kAvatarGesichtAnalyseKante / kante;
        return ui.TargetImageSize(
          width: math.max(1, (breite * faktor).round()),
          height: math.max(1, (hoehe * faktor).round()),
        );
      },
    );
    final frame = await codec.getNextFrame();
    bild = frame.image;
    final daten = await bild.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (daten == null) {
      throw StateError('Bildpixel konnten nicht gelesen werden.');
    }
    return (
      rgba: RgbaBild(
        pixel: daten.buffer.asUint8List(
          daten.offsetInBytes,
          daten.lengthInBytes,
        ),
        breite: bild.width,
        hoehe: bild.height,
      ),
      originalBreite: originalBreite > 0 ? originalBreite : bild.width,
      originalHoehe: originalHoehe > 0 ? originalHoehe : bild.height,
    );
  } finally {
    // Den Puffer gibt `instantiateImageCodecWithSize` selbst frei.
    bild?.dispose();
    codec?.dispose();
  }
}

/// Baut den Befund aus einem normierten Treffer.
///
/// Der Rahmen wird auf das Bild beschnitten und auf vier Stellen gerundet:
/// feiner bringt fuer die Darstellung nichts, und gerundete Werte bleiben im
/// Cache ueber Plattformen hinweg vergleichbar.
AvatarGesichtsbefund befundAusTreffer({
  required int bildBreite,
  required int bildHoehe,
  required ({
    double links,
    double oben,
    double rechts,
    double unten,
    double score,
  })?
  treffer,
}) {
  if (treffer == null) {
    return AvatarGesichtsbefund(bildBreite: bildBreite, bildHoehe: bildHoehe);
  }
  double runde(double wert) => (wert.clamp(0.0, 1.0) * 10000).round() / 10000;
  final links = runde(treffer.links);
  final oben = runde(treffer.oben);
  final rechts = runde(treffer.rechts);
  final unten = runde(treffer.unten);
  if (rechts <= links || unten <= oben) {
    return AvatarGesichtsbefund(bildBreite: bildBreite, bildHoehe: bildHoehe);
  }
  return AvatarGesichtsbefund(
    bildBreite: bildBreite,
    bildHoehe: bildHoehe,
    gesicht: AvatarGesichtsrahmen(
      links: links,
      oben: oben,
      breite: runde(rechts - links),
      hoehe: runde(unten - oben),
    ),
    konfidenz: runde(treffer.score),
  );
}

/// Gibt der Oberflaeche nur nach etwa einem Frame Rechenzeit die Kontrolle.
///
/// Eine Pause nach jeder Op kostete im Browser mehr als das Rechnen selbst:
/// `Future.delayed(Duration.zero)` wird dort auf mindestens 4 ms gedehnt.
Future<void> Function() _zeitscheibenPause() {
  final uhr = Stopwatch()..start();
  return () async {
    if (uhr.elapsedMilliseconds < 12) return;
    await Future<void>.delayed(Duration.zero);
    uhr.reset();
  };
}

typedef _Auftrag = ({Uint8List modell, Uint8List pixel, int breite, int hoehe});

// Laeuft im Hintergrund-Isolate: baut das Modell dort auf und liefert nur
// sendbare Werte zurueck.
Future<
  ({double links, double oben, double rechts, double unten, double score})?
>
_sucheImIsolat(_Auftrag auftrag) async {
  final erkennung = BlazeFaceErkennung(
    BlazeFaceRechenkern(BlazeFaceModell.ausBytes(auftrag.modell)),
  );
  final treffer = await erkennung.sucheHauptgesicht(
    RgbaBild(
      pixel: auftrag.pixel,
      breite: auftrag.breite,
      hoehe: auftrag.hoehe,
    ),
  );
  return treffer == null ? null : _alsRecord(treffer);
}

({double links, double oben, double rechts, double unten, double score})
_alsRecord(BlazeFaceTreffer treffer) {
  return (
    links: treffer.links,
    oben: treffer.oben,
    rechts: treffer.rechts,
    unten: treffer.unten,
    score: treffer.score,
  );
}
