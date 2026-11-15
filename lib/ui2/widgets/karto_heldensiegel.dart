import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/theme/karto_heldensiegel_profil.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';

/// Kleine, codegezeichnete Heldensiegel ohne Semantik oder eigene Bedienung.
class KartoHeldensiegel extends StatelessWidget {
  /// Zeichnet ein vollständiges Grundmotiv samt unabhängigen Zusatzzeichen.
  const KartoHeldensiegel({
    super.key,
    required this.profil,
    required this.groesse,
    this.farbe,
  });

  /// Ausschließlich kosmetisches Profil des Helden.
  final KartoSiegelProfil profil;

  /// Außenmaß; der Zeichner skaliert alle Motive gleichmäßig.
  final double groesse;

  /// Optionaler Messington für dunkle Navigationsflächen.
  final Color? farbe;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: CustomPaint(
          size: Size.square(groesse),
          painter: _SiegelZeichner(
            profil,
            farbe ?? context.karto.messing,
            context.karto.astralenergie,
          ),
        ),
      ),
    );
  }
}

// Einheitlicher Zeichenraum: alle Ornamente bleiben im Ring, frei vom Porträt.
class _SiegelZeichner extends CustomPainter {
  const _SiegelZeichner(this.profil, this.farbe, this.astral);

  final KartoSiegelProfil profil;
  final Color farbe;
  final Color astral;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final stift = Paint()
      ..color = farbe
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(const Offset(50, 50), 45, stift);
    final innen = Paint()
      ..color = farbe.withValues(alpha: farbe.a * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(const Offset(50, 50), 39, innen);
    switch (profil.motiv) {
      case KartoSiegelMotiv.mensch:
        _schild(canvas, stift);
        _raute(canvas, stift, const Offset(50, 45), 9);
      case KartoSiegelMotiv.elf:
        _blatt(canvas, stift, spiegeln: false);
        _blatt(canvas, stift, spiegeln: true);
      case KartoSiegelMotiv.halbelf:
        _schild(canvas, stift);
        _blatt(canvas, stift, spiegeln: false);
      case KartoSiegelMotiv.zwerg:
        _zug(canvas, stift, const [
          Offset(50, 20),
          Offset(73, 34),
          Offset(73, 62),
          Offset(50, 78),
          Offset(27, 62),
          Offset(27, 34),
          Offset(50, 20),
        ]);
        _zug(canvas, stift, const [
          Offset(34, 43),
          Offset(50, 31),
          Offset(66, 43),
          Offset(50, 65),
          Offset(34, 43),
        ]);
      case KartoSiegelMotiv.echse:
        for (final mitte in const [
          Offset(50, 32),
          Offset(35, 50),
          Offset(65, 50),
          Offset(50, 68),
        ]) {
          _raute(canvas, stift, mitte, 12);
        }
      case KartoSiegelMotiv.ork:
        for (final spiegeln in [false, true]) {
          canvas.save();
          if (spiegeln) {
            canvas.translate(100, 0);
            canvas.scale(-1, 1);
          }
          final spitze = Path()
            ..moveTo(29, 27)
            ..quadraticBezierTo(25, 63, 48, 76)
            ..quadraticBezierTo(37, 52, 29, 27);
          canvas.drawPath(spitze, stift);
          canvas.restore();
        }
      case KartoSiegelMotiv.goblin:
        for (var i = 0; i < 3; i++) {
          final x = 32.0 + i * 18;
          final y = i.isEven ? 52.0 : 39.0;
          _zug(canvas, stift, [
            Offset(x - 6, y + 11),
            Offset(x, y - 7),
            Offset(x + 6, y + 11),
          ]);
        }
      case KartoSiegelMotiv.neutral:
        _stern(canvas, stift, const Offset(50, 50), 27);
    }
    // Beide Befähigungen können gleichzeitig sichtbar sein; keine Rangfolge.
    if (profil.magisch) {
      final magie = Paint()
        ..color = astral
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      _stern(canvas, magie, const Offset(77, 22), 9);
    }
    if (profil.karmal) {
      final mitte = const Offset(77, 78);
      canvas.drawCircle(mitte, 5, stift);
      for (var i = 0; i < 8; i++) {
        final winkel = i * math.pi / 4;
        canvas.drawLine(
          mitte + Offset.fromDirection(winkel, 8),
          mitte + Offset.fromDirection(winkel, 11),
          stift,
        );
      }
    }
    canvas.restore();
  }

  // Offene Blattkonturen erinnern an Gravuren, ohne ein Bildasset zu brauchen.
  void _blatt(Canvas canvas, Paint stift, {required bool spiegeln}) {
    canvas.save();
    if (spiegeln) {
      canvas.translate(100, 0);
      canvas.scale(-1, 1);
    }
    final blatt = Path()
      ..moveTo(50, 77)
      ..cubicTo(13, 58, 25, 35, 47, 20)
      ..cubicTo(58, 49, 38, 57, 50, 77);
    canvas.drawPath(blatt, stift);
    final ader = Path()
      ..moveTo(50, 77)
      ..quadraticBezierTo(32, 48, 47, 20);
    canvas.drawPath(ader, stift);
    canvas.restore();
  }

  // Dieselbe Schildkontur verbindet Menschen- und Halbelfenmotiv.
  void _schild(Canvas canvas, Paint stift) {
    final schild = Path()
      ..moveTo(27, 27)
      ..lineTo(73, 27)
      ..lineTo(70, 54)
      ..quadraticBezierTo(67, 67, 50, 78)
      ..quadraticBezierTo(33, 67, 30, 54)
      ..close();
    canvas.drawPath(schild, stift);
  }

  // Rauten dienen als Schuppen und als kleine heraldische Prägung.
  void _raute(Canvas canvas, Paint stift, Offset mitte, double radius) {
    _zug(canvas, stift, [
      mitte + Offset(0, -radius),
      mitte + Offset(radius, 0),
      mitte + Offset(0, radius),
      mitte + Offset(-radius, 0),
      mitte + Offset(0, -radius),
    ]);
  }

  // Vierpunktstern bleibt auch bei kleinen Siegeln klar erkennbar.
  void _stern(Canvas canvas, Paint stift, Offset mitte, double radius) {
    final punkte = <Offset>[];
    for (var i = 0; i < 8; i++) {
      punkte.add(
        mitte +
            Offset.fromDirection(
              i * math.pi / 4 - math.pi / 2,
              i.isEven ? radius : radius * 0.23,
            ),
      );
    }
    _zug(canvas, stift, [...punkte, punkte.first]);
  }

  // Benannte Zeichenhilfe hält die einzelnen Motivdefinitionen übersichtlich.
  void _zug(Canvas canvas, Paint stift, List<Offset> punkte) {
    canvas.drawPath(Path()..addPolygon(punkte, false), stift);
  }

  @override
  bool shouldRepaint(_SiegelZeichner oldDelegate) =>
      oldDelegate.profil != profil ||
      oldDelegate.farbe != farbe ||
      oldDelegate.astral != astral;
}
