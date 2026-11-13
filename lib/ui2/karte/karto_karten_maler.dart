import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'package:dsa_heldenverwaltung/domain/avesmaps_ort.dart';
import 'package:dsa_heldenverwaltung/rules/derived/karten_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reiseroute_rules.dart';
import 'package:dsa_heldenverwaltung/ui2/karte/karto_karten_beschriftung.dart';
import 'package:dsa_heldenverwaltung/ui2/karte/karto_karten_kacheln.dart';
import 'package:dsa_heldenverwaltung/ui2/karte/karto_karten_kamera.dart';
import 'package:dsa_heldenverwaltung/ui2/karte/karto_karten_stil.dart';

/// Halbmesser der Wegpunkt-Scheibe in px (drei Viertel von Avesmaps'
/// [kWegpunktScheibe]: die Scheiben tragen Nummern und stehen dichter).
const double kWegpunktHalbmesser = kWegpunktScheibe * .375;

/// Hält gesetzte Ortsnamen, damit nicht jedes Bild neu setzt.
///
/// Gehört der Karte (State) und überlebt die Maler, die je Bild neu
/// entstehen.
class KartenTextSpeicher {
  /// Erstellt den Speicher für höchstens [grenze] Namen.
  KartenTextSpeicher({this.grenze = 1200});

  /// Höchstzahl der gehaltenen Namen.
  final int grenze;

  final LinkedHashMap<String, KartenText> _texte =
      LinkedHashMap<String, KartenText>();

  /// Der gesetzte [name] in der Größe [px] (auf halbe px gerundet), mit
  /// [farbe] und Saum.
  KartenText text(
    String name,
    double px, {
    Color farbe = KartenFarben.beschriftung,
    Color saum = KartenFarben.beschriftungSaum,
  }) {
    final groesse = (px * 2).roundToDouble() / 2;
    final schluessel = '$groesse|${farbe.toARGB32()}|${saum.toARGB32()}|$name';
    final vorhanden = _texte.remove(schluessel);
    if (vorhanden != null) {
      _texte[schluessel] = vorhanden;
      return vorhanden;
    }
    final neu = KartenText._setze(name, groesse, farbe, saum);
    _texte[schluessel] = neu;
    while (_texte.length > grenze) {
      _texte.remove(_texte.keys.first);
    }
    return neu;
  }
}

/// Ein gesetzter Name mit Saum.
class KartenText {
  KartenText._(this._fuellung, this._saum);

  factory KartenText._setze(
    String name,
    double groesse,
    Color farbe,
    Color saumFarbe,
  ) {
    ui.Paragraph absatz(ui.TextStyle stil) {
      final bauer =
          ui.ParagraphBuilder(
              ui.ParagraphStyle(
                fontFamily: kKartenSchrift,
                fontSize: groesse,
                maxLines: 1,
                textDirection: ui.TextDirection.ltr,
              ),
            )
            ..pushStyle(stil)
            ..addText(name);
      return bauer.build()
        ..layout(const ui.ParagraphConstraints(width: double.infinity));
    }

    final saumBreite = math.max(1.0, groesse * kSaumBreiteAnteil * 2);
    final weich = groesse * kSaumWeichAnteil;
    final saumPinsel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = saumBreite
      ..strokeJoin = StrokeJoin.round
      ..color = saumFarbe;
    if (weich > 0.2) {
      saumPinsel.maskFilter = MaskFilter.blur(BlurStyle.normal, weich);
    }
    return KartenText._(
      absatz(
        ui.TextStyle(
          color: farbe,
          fontFamily: kKartenSchrift,
          fontSize: groesse,
        ),
      ),
      absatz(
        ui.TextStyle(
          foreground: saumPinsel,
          fontFamily: kKartenSchrift,
          fontSize: groesse,
        ),
      ),
    );
  }

  final ui.Paragraph _fuellung;
  final ui.Paragraph _saum;

  /// Ausmaß des Namens.
  Size get groesse => Size(_fuellung.maxIntrinsicWidth, _fuellung.height);

  /// Zeichnet den Namen mit Saum bei [oben] (linke obere Ecke).
  void zeichne(Canvas canvas, Offset oben) {
    canvas.drawParagraph(_saum, oben);
    canvas.drawParagraph(_fuellung, oben);
  }
}

/// Was der Maler zeichnet.
class KartenSzene {
  /// Erstellt die Szene.
  const KartenSzene({
    required this.kamera,
    required this.orte,
    required this.dunkel,
    this.routenPunkte = const <KartenRoutenPunkt>[],
    this.standort,
    this.auswahl,
    this.landschimmer,
    this.kacheln,
    this.mitKompass = true,
  });

  /// Blick auf die Karte.
  final KartenKamera kamera;

  /// Orte, unbedeutende zuerst (die bedeutenden liegen obenauf).
  final List<AvesmapsOrt> orte;

  /// Ob das dunkle Theme gilt (nur Papier und Rückfall).
  final bool dunkel;

  /// Stationen mit Position, in zeitlicher Reihenfolge.
  final List<KartenRoutenPunkt> routenPunkte;

  /// Aktueller Standort, oder `null`.
  final AvesmapsOrt? standort;

  /// Kennung des gewählten Orts bzw. der gewählten Station.
  final String? auswahl;

  /// Landschimmer als Ersatz für das Kartenbild (Karte 0 … 1024).
  final ui.Image? landschimmer;

  /// Kartenkacheln; `null` oder ohne Manifest zeichnet ohne Kartenbild.
  final KartenKachelSpeicher? kacheln;

  /// Ob Kompass und Maßstab erscheinen.
  final bool mitKompass;
}

/// Zeichnet die Karte im Stil von Avesmaps: Kartenbild oder Papier mit
/// Landschimmer, Orte, Namen, Route, Standort, Kompass und Maßstab.
class KartenMaler extends CustomPainter {
  /// Erstellt den Maler.
  KartenMaler({required this.szene, required this.texte, super.repaint});

  /// Was zu zeichnen ist.
  final KartenSzene szene;

  /// Gesetzte Namen.
  final KartenTextSpeicher texte;

  @override
  void paint(Canvas canvas, Size size) {
    final kamera = szene.kamera;
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = szene.dunkel
            ? KartenFarben.papierDunkel
            : KartenFarben.papier,
    );

    final mitBild = _kartenbild(canvas, size);
    if (!mitBild) {
      _landschimmer(canvas, size);
      _gitter(canvas, size);
    }

    final sichtbar = kamera.sichtbar(size);
    final zoom = kamera.zoom;
    const reserve = 40.0;
    final grenzen = (Offset.zero & size).inflate(reserve);

    // Marken: unbedeutende zuerst. Die Namen folgen danach in umgekehrter
    // Reihenfolge (bedeutende setzen zuerst).
    final wuensche = <BeschriftungsWunsch>[];
    final namen = <String, (AvesmapsOrt, double)>{};
    for (final ort in szene.orte) {
      if (ort.x < sichtbar.minX - 20 ||
          ort.x > sichtbar.maxX + 20 ||
          ort.y < sichtbar.minY - 20 ||
          ort.y > sichtbar.maxY + 20) {
        continue;
      }
      final durchmesser = markerDurchmesser(ort.art, zoom);
      if (durchmesser == null) continue;
      final p = kamera.zuBildschirm(ort.x, ort.y, size);
      if (!grenzen.contains(p)) continue;
      _marke(canvas, p, ort.art, durchmesser, zoom);
      final px = beschriftungsGroesse(ort.art, zoom);
      if (px != null) {
        namen[ort.id] = (ort, px);
        wuensche.add(
          BeschriftungsWunsch(
            schluessel: ort.id,
            anker: p,
            abstand: durchmesser / 2 + kNamensspalt,
            groesse: Size.zero,
          ),
        );
      }
    }

    final route = <Offset>[
      for (final punkt in szene.routenPunkte)
        kamera.zuBildschirm(punkt.x, punkt.y, size),
    ];
    _routenlinie(canvas, route);

    // Wegpunkte und Reisender halten die Namen fern.
    final frei = <Rect>[
      for (final p in route)
        Rect.fromCircle(center: p, radius: kWegpunktHalbmesser + 2),
    ];
    final reisender = _reisenderOrt(size);
    if (reisender != null) {
      frei.add(
        Rect.fromLTWH(
          reisender.dx - kReisenderGroesse * .3,
          reisender.dy - kReisenderGroesse,
          kReisenderGroesse * .6,
          kReisenderGroesse,
        ),
      );
    }

    final gesetzt = setzeBeschriftungen(<BeschriftungsWunsch>[
      for (final w in wuensche.reversed)
        BeschriftungsWunsch(
          schluessel: w.schluessel,
          anker: w.anker,
          abstand: w.abstand,
          groesse: texte
              .text(namen[w.schluessel]!.$1.name, namen[w.schluessel]!.$2)
              .groesse,
        ),
    ], frei: frei);
    for (final g in gesetzt) {
      final (ort, px) = namen[g.wunsch.schluessel]!;
      texte.text(ort.name, px).zeichne(canvas, g.flaeche.topLeft);
    }

    _auswahl(canvas, size);
    _wegpunkte(canvas, route);
    if (reisender != null) _reisender(canvas, reisender);
    if (szene.mitKompass) {
      _kompass(canvas, const Offset(28, 36));
    }
    _massstab(canvas, size);
  }

  // Kartenbild aus Kacheln; fehlende Kacheln vertritt eine gröbere Stufe.
  bool _kartenbild(Canvas canvas, Size size) {
    final speicher = szene.kacheln;
    final manifest = speicher?.manifest;
    if (speicher == null || manifest == null) return false;
    final kamera = szene.kamera;
    final z = kachelStufe(kamera, manifest.maxZoom);
    final pinsel = Paint()..filterQuality = FilterQuality.medium;
    var gezeichnet = false;
    for (final k in kachelnIm(kamera.sichtbar(size), z)) {
      final ziel = _bildschirm(kachelFlaeche(k), size);
      final bild = speicher.bild(k);
      if (bild != null) {
        canvas.drawImageRect(
          bild,
          Rect.fromLTWH(0, 0, bild.width.toDouble(), bild.height.toDouble()),
          ziel,
          pinsel,
        );
        gezeichnet = true;
        continue;
      }
      // Platzhalter aus der nächstgröberen geladenen Stufe.
      var (pz, px, py) = k;
      var teil = 1;
      while (pz > 0) {
        pz -= 1;
        px >>= 1;
        py >>= 1;
        teil <<= 1;
        final grob = speicher.bild((pz, px, py));
        if (grob == null) continue;
        final (_, kx, ky) = k;
        final kante = grob.width / teil;
        canvas.drawImageRect(
          grob,
          Rect.fromLTWH((kx % teil) * kante, (ky % teil) * kante, kante, kante),
          ziel,
          pinsel,
        );
        gezeichnet = true;
        break;
      }
    }
    // Solange noch keine Kachel da ist, bleibt der Rückfall sichtbar.
    return gezeichnet;
  }

  Rect _bildschirm(KartenRechteck r, Size size) {
    final a = szene.kamera.zuBildschirm(r.minX, r.maxY, size);
    final b = szene.kamera.zuBildschirm(r.maxX, r.minY, size);
    // Halbe Pixel Überlappung gegen Haarrisse zwischen Kacheln.
    return Rect.fromPoints(a, b).inflate(.5);
  }

  void _landschimmer(Canvas canvas, Size size) {
    final bild = szene.landschimmer;
    if (bild == null) return;
    canvas.drawImageRect(
      bild,
      Rect.fromLTWH(0, 0, bild.width.toDouble(), bild.height.toDouble()),
      _bildschirm(kKartenWelt, size),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  // Gitter alle 50 Karteneinheiten (150 Meilen), grob nur jede zweite Linie.
  void _gitter(Canvas canvas, Size size) {
    final kamera = szene.kamera;
    final abstand = kamera.zoom < 2 ? 100.0 : 50.0;
    final sichtbar = kamera.sichtbar(size);
    final linie = Paint()
      ..color = KartenFarben.gitter
      ..strokeWidth = 1;
    for (
      var x = (math.max(0, sichtbar.minX) / abstand).ceil() * abstand;
      x <= math.min(kKartenKante, sichtbar.maxX);
      x += abstand
    ) {
      final a = kamera.zuBildschirm(x, 0, size);
      final b = kamera.zuBildschirm(x, kKartenKante, size);
      canvas.drawLine(a, b, linie);
    }
    for (
      var y = (math.max(0, sichtbar.minY) / abstand).ceil() * abstand;
      y <= math.min(kKartenKante, sichtbar.maxY);
      y += abstand
    ) {
      final a = kamera.zuBildschirm(0, y, size);
      final b = kamera.zuBildschirm(kKartenKante, y, size);
      canvas.drawLine(a, b, linie);
    }
  }

  void _marke(
    Canvas canvas,
    Offset p,
    String art,
    double durchmesser,
    double zoom,
  ) {
    final aussen = durchmesser / 2;
    final pinsel = Paint()..isAntiAlias = true;
    switch (markenForm(art, zoom, durchmesser)) {
      case KartenMarkenForm.raute:
        Path raute(double r) => Path()
          ..moveTo(p.dx, p.dy - r)
          ..lineTo(p.dx + r, p.dy)
          ..lineTo(p.dx, p.dy + r)
          ..lineTo(p.dx - r, p.dy)
          ..close();
        // Die Spitzen reichen so weit wie der Kreis gleicher Größe.
        canvas.drawPath(raute(aussen), pinsel..color = KartenFarben.haarlinie);
        canvas.drawPath(
          raute(math.max(0, aussen - kHaarlinie * 1.4)),
          pinsel..color = KartenFarben.kontur,
        );
        canvas.drawPath(
          raute(kernHalbmesser(aussen) * 1.1),
          pinsel..color = markenFarbe(art),
        );
      case KartenMarkenForm.hauptstadt:
        final ring = durchmesser * kHauptstadtRingAnteil;
        canvas.drawCircle(
          p,
          aussen,
          pinsel..color = KartenFarben.hauptstadtRand,
        );
        canvas.drawCircle(
          p,
          aussen - kHaarlinie,
          pinsel..color = KartenFarben.hauptstadtRing,
        );
        final innen = aussen - kHaarlinie - ring;
        canvas.drawCircle(p, innen, pinsel..color = KartenFarben.haarlinie);
        canvas.drawCircle(
          p,
          innen - kHaarlinie,
          pinsel..color = KartenFarben.kontur,
        );
        canvas.drawCircle(
          p,
          kernHalbmesser(innen),
          pinsel..color = markenFarbe(art),
        );
      case KartenMarkenForm.kreis:
        if (durchmesser < 2.5) {
          // Winzige Marken: nur der Kern, sonst wird alles grau.
          canvas.drawCircle(p, aussen, pinsel..color = markenFarbe(art));
          return;
        }
        canvas.drawCircle(p, aussen, pinsel..color = KartenFarben.haarlinie);
        canvas.drawCircle(
          p,
          aussen - kHaarlinie,
          pinsel..color = KartenFarben.kontur,
        );
        canvas.drawCircle(
          p,
          kernHalbmesser(aussen),
          pinsel..color = markenFarbe(art),
        );
    }
  }

  // Luftlinie als Pillen: Strich und Lücke von Mitte zu Mitte, runde Enden,
  // weißer Saum darunter (wie „querfeldein“ bei Avesmaps).
  void _routenlinie(Canvas canvas, List<Offset> punkte) {
    if (punkte.length < 2) return;
    final pillen = <(Offset, Offset)>[];
    const takt = kPillenStrich + kPillenLuecke;
    var rest = 0.0; // Weg bis zum nächsten Pillenanfang
    for (var i = 1; i < punkte.length; i++) {
      final a = punkte[i - 1];
      final b = punkte[i];
      final laenge = (b - a).distance;
      if (laenge < 1e-3) continue;
      final richtung = (b - a) / laenge;
      var s = rest;
      while (s < laenge) {
        final ende = math.min(s + kPillenStrich, laenge);
        pillen.add((a + richtung * s, a + richtung * ende));
        s += takt;
      }
      rest = s - laenge;
    }
    final saum = Paint()
      ..color = KartenFarben.routeSaum
      ..strokeWidth = kRoutenBreite + 2 * kRoutenSaum
      ..strokeCap = StrokeCap.round;
    final kern = Paint()
      ..color = KartenFarben.route
      ..strokeWidth = kRoutenBreite
      ..strokeCap = StrokeCap.round;
    for (final (a, b) in pillen) {
      canvas.drawLine(a, b, saum);
    }
    for (final (a, b) in pillen) {
      canvas.drawLine(a, b, kern);
    }
  }

  // Nummerierte Scheiben: dunkler Rand, goldener Ring, roter Körper.
  void _wegpunkte(Canvas canvas, List<Offset> punkte) {
    final pinsel = Paint()..isAntiAlias = true;
    for (var i = 0; i < punkte.length; i++) {
      final p = punkte[i];
      canvas.drawCircle(
        p,
        kWegpunktHalbmesser + 1.5,
        pinsel..color = KartenFarben.routeSaum,
      );
      canvas.drawCircle(
        p,
        kWegpunktHalbmesser,
        pinsel..color = KartenFarben.wegpunktKern,
      );
      canvas.drawCircle(
        p,
        kWegpunktHalbmesser - 1.5,
        pinsel..color = KartenFarben.wegpunktRing,
      );
      canvas.drawCircle(
        p,
        kWegpunktHalbmesser - 3.2,
        pinsel..color = KartenFarben.wegpunkt,
      );
      final nummer = texte.text(
        '${szene.routenPunkte[i].nummer}',
        kWegpunktHalbmesser * .95,
        saum: KartenFarben.wegpunktKern,
      );
      nummer.zeichne(
        canvas,
        p - Offset(nummer.groesse.width / 2, nummer.groesse.height / 2),
      );
    }
  }

  // Wo der Reisende steht: am Standort, sonst an der jüngsten Station.
  Offset? _reisenderOrt(Size size) {
    final kamera = szene.kamera;
    final standort = szene.standort;
    if (standort != null) {
      final p = kamera.zuBildschirm(standort.x, standort.y, size);
      final aufStation = szene.routenPunkte.any(
        (r) =>
            (r.x - standort.x).abs() < 1e-6 && (r.y - standort.y).abs() < 1e-6,
      );
      return aufStation ? p - const Offset(0, kWegpunktHalbmesser - 2) : p;
    }
    if (szene.routenPunkte.isEmpty) return null;
    final letzte = szene.routenPunkte.last;
    return kamera.zuBildschirm(letzte.x, letzte.y, size) -
        const Offset(0, kWegpunktHalbmesser - 2);
  }

  // Spielfigur mit Verlauf von Scheitel zu Fuß, dunklem Rand und weißem
  // Saum; [fuss] ist der Standpunkt.
  void _reisender(Canvas canvas, Offset fuss) {
    const h = kReisenderGroesse;
    final figur = Path()
      ..moveTo(fuss.dx - h * .26, fuss.dy)
      ..quadraticBezierTo(
        fuss.dx - h * .28,
        fuss.dy - h * .12,
        fuss.dx - h * .17,
        fuss.dy - h * .16,
      )
      ..lineTo(fuss.dx - h * .08, fuss.dy - h * .58)
      ..lineTo(fuss.dx + h * .08, fuss.dy - h * .58)
      ..lineTo(fuss.dx + h * .17, fuss.dy - h * .16)
      ..quadraticBezierTo(
        fuss.dx + h * .28,
        fuss.dy - h * .12,
        fuss.dx + h * .26,
        fuss.dy,
      )
      ..close()
      ..addOval(
        Rect.fromCircle(
          center: Offset(fuss.dx, fuss.dy - h * .76),
          radius: h * .17,
        ),
      );
    canvas.drawPath(
      figur,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 + 2 * kRoutenSaum
        ..strokeJoin = StrokeJoin.round
        ..color = KartenFarben.routeSaum,
    );
    canvas.drawPath(
      figur,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(fuss.dx, fuss.dy - h),
          fuss,
          const <Color>[
            KartenFarben.reisenderSpitze,
            KartenFarben.reisenderFuss,
          ],
        ),
    );
    canvas.drawPath(
      figur,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = KartenFarben.reisenderRand,
    );
  }

  void _auswahl(Canvas canvas, Size size) {
    final auswahl = szene.auswahl;
    if (auswahl == null) return;
    final kamera = szene.kamera;
    Offset? p;
    var r = 11.0;
    for (final punkt in szene.routenPunkte) {
      if (punkt.station.id == auswahl) {
        p = kamera.zuBildschirm(punkt.x, punkt.y, size);
        r = kWegpunktHalbmesser + 4;
      }
    }
    if (p == null) {
      for (final ort in szene.orte) {
        if (ort.id != auswahl) continue;
        p = kamera.zuBildschirm(ort.x, ort.y, size);
        r = math.max(
          11,
          (markerDurchmesser(ort.art, kamera.zoom) ?? 0) / 2 + 5,
        );
      }
    }
    if (p == null) return;
    canvas.drawCircle(
      p,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = KartenFarben.auswahlSchein.withValues(alpha: .55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(
      p,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = KartenFarben.auswahl,
    );
  }

  // Kompassnadel in den Kanonfarben: Nordhälfte gold, Südhälfte taupe, je
  // mit Licht- und Schattenseite.
  void _kompass(Canvas canvas, Offset mitte) {
    const l = 14.0;
    const b = 5.0;
    void haelfte(double richtung, Color hell, Color schatten) {
      final spitze = mitte + Offset(0, -l * richtung);
      canvas.drawPath(
        Path()
          ..moveTo(spitze.dx, spitze.dy)
          ..lineTo(mitte.dx - b, mitte.dy)
          ..lineTo(mitte.dx, mitte.dy)
          ..close(),
        Paint()..color = hell,
      );
      canvas.drawPath(
        Path()
          ..moveTo(spitze.dx, spitze.dy)
          ..lineTo(mitte.dx + b, mitte.dy)
          ..lineTo(mitte.dx, mitte.dy)
          ..close(),
        Paint()..color = schatten,
      );
    }

    canvas.drawCircle(
      mitte,
      l + 3,
      Paint()..color = KartenFarben.tafel.withValues(alpha: .7),
    );
    haelfte(1, KartenFarben.kompassNordHell, KartenFarben.kompassNordSchatten);
    haelfte(-1, KartenFarben.kompassSuedHell, KartenFarben.kompassSuedSchatten);
    final n = texte.text(
      'N',
      9,
      farbe: KartenFarben.text,
      saum: KartenFarben.tafel,
    );
    n.zeichne(
      canvas,
      mitte + Offset(-n.groesse.width / 2, -l - 3 - n.groesse.height),
    );
  }

  // Maßstab links unten: 1-, 2- oder 5-fache Zehnerpotenz in Meilen, bis
  // etwa 90 px lang.
  void _massstab(Canvas canvas, Size size) {
    final pxProMeile = szene.kamera.pxProEinheit / kMeilenProKarteneinheit;
    if (pxProMeile <= 0) return;
    final hoechstens = 90 / pxProMeile;
    var meilen = 1.0;
    final potenz = math
        .pow(10, (math.log(hoechstens) / math.ln10).floor())
        .toDouble();
    for (final f in const <double>[5, 2, 1]) {
      if (f * potenz <= hoechstens) {
        meilen = f * potenz;
        break;
      }
    }
    final laenge = meilen * pxProMeile;
    const links = 10.0;
    final unten = size.height - 10;
    final tafel = Paint()..color = KartenFarben.tafel.withValues(alpha: .7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(links - 4, unten - 20, laenge + 8, 24),
        const Radius.circular(4),
      ),
      tafel,
    );
    final strich = Paint()
      ..color = KartenFarben.text
      ..strokeWidth = 1.4;
    canvas.drawLine(
      Offset(links, unten),
      Offset(links + laenge, unten),
      strich,
    );
    canvas.drawLine(Offset(links, unten - 4), Offset(links, unten + 1), strich);
    canvas.drawLine(
      Offset(links + laenge, unten - 4),
      Offset(links + laenge, unten + 1),
      strich,
    );
    final text = texte.text(
      meilen >= 1 ? '${meilen.round()} Meilen' : '$meilen Meilen',
      10,
      farbe: KartenFarben.text,
      saum: KartenFarben.tafel,
    );
    text.zeichne(canvas, Offset(links, unten - 5 - text.groesse.height));
  }

  @override
  bool shouldRepaint(KartenMaler alt) =>
      !identical(alt.szene, szene) || !identical(alt.texte, texte);
}
