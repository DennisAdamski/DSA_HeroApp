import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';

// ─── Interne Enums ───────────────────────────────────────────────────────────

enum _AvatarRace { mensch, elf, zwerg, ork, halbling, unbekannt }

enum _AvatarGender { maennlich, weiblich, neutral }

// ─── Mapping-Hilfsfunktionen ─────────────────────────────────────────────────

_AvatarRace _raceFromString(String rasse) {
  final r = rasse.toLowerCase();
  if (r.contains('elf') || r.contains('halbelf')) return _AvatarRace.elf;
  if (r.contains('zwerg') ||
      r.contains('amboss') ||
      r.contains('berg') ||
      r.contains('erz') ||
      r.contains('hügel') ||
      r.contains('stein')) {
    return _AvatarRace.zwerg;
  }
  if (r.contains('ork')) return _AvatarRace.ork;
  if (r.contains('halbling')) return _AvatarRace.halbling;
  if (r.isEmpty) return _AvatarRace.unbekannt;
  return _AvatarRace.mensch;
}

_AvatarGender _genderFromString(String geschlecht) {
  final g = geschlecht.toLowerCase().trim();
  if (g.startsWith('w')) return _AvatarGender.weiblich;
  if (g.startsWith('m')) return _AvatarGender.maennlich;
  return _AvatarGender.neutral;
}

Color _backgroundColorForRace(_AvatarRace race) => switch (race) {
      _AvatarRace.mensch => Colors.blueGrey.shade500,
      _AvatarRace.elf => Colors.green.shade600,
      _AvatarRace.zwerg => Colors.brown.shade600,
      _AvatarRace.ork => const Color(0xFF2E5622),
      _AvatarRace.halbling => Colors.orange.shade500,
      _AvatarRace.unbekannt => Colors.grey.shade500,
    };

Color _hairColorFromString(String haarfarbe) {
  final h = haarfarbe.toLowerCase();
  if (h.contains('schwarz')) return Colors.black87;
  if (h.contains('blond') || h.contains('gold')) return Colors.amber.shade300;
  if (h.contains('rot') || h.contains('kupfer')) return Colors.red.shade700;
  if (h.contains('grau') ||
      h.contains('weiß') ||
      h.contains('weiss') ||
      h.contains('silber')) {
    return Colors.grey.shade400;
  }
  return Colors.brown.shade600;
}

Color _eyeColorFromString(String augenfarbe) {
  final a = augenfarbe.toLowerCase();
  if (a.contains('blau')) return Colors.blue.shade600;
  if (a.contains('grün') || a.contains('gruen')) return Colors.green.shade600;
  if (a.contains('grau')) return Colors.grey.shade500;
  if (a.contains('schwarz')) return Colors.black87;
  if (a.contains('gold') || a.contains('bernstein') || a.contains('amber')) {
    return Colors.amber.shade600;
  }
  if (a.contains('lila') || a.contains('violett')) return Colors.purple.shade400;
  return Colors.brown.shade600;
}

// ─── CustomPainter ───────────────────────────────────────────────────────────

class _HeroAvatarPainter extends CustomPainter {
  const _HeroAvatarPainter({
    required this.race,
    required this.gender,
    required this.hairColor,
    required this.eyeColor,
  });

  final _AvatarRace race;
  final _AvatarGender gender;
  final Color hairColor;
  final Color eyeColor;

  static const Color _skinFarbe = Color(0xFFE8C8A0);
  static const Color _skinSchatten = Color(0xFFB8946A);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s / 2;
    final cy = s / 2;

    // Hintergrundkreis
    canvas.drawCircle(
      Offset(cx, cy),
      s / 2,
      Paint()..color = _backgroundColorForRace(race),
    );

    // Clip auf Kreisform – alle folgenden Zeichenoperationen bleiben im Kreis
    canvas.clipPath(
      Path()
        ..addOval(
          Rect.fromCircle(center: Offset(cx, cy), radius: s / 2 - 0.5),
        ),
    );

    // Gesichtsproportionen je nach Rasse
    final faceRx = switch (race) {
      _AvatarRace.elf => s * 0.23,
      _AvatarRace.zwerg => s * 0.30,
      _ => s * 0.27,
    };
    final faceRy = switch (race) {
      _AvatarRace.elf => s * 0.34,
      _AvatarRace.zwerg => s * 0.26,
      _ => s * 0.31,
    };
    final faceCy = cy + s * 0.06;

    // Haare und Ohren vor dem Gesichtsoval zeichnen,
    // damit das Oval die innere Überlappung verdeckt.
    _drawHair(canvas, s, cx, faceCy, faceRx, faceRy);
    _drawEars(canvas, s, cx, faceCy, faceRx, faceRy);

    // Gesichtsoval
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, faceCy),
        width: faceRx * 2,
        height: faceRy * 2,
      ),
      Paint()..color = _skinFarbe,
    );

    _drawEyes(canvas, s, cx, faceCy, faceRy);
    _drawNose(canvas, s, cx, faceCy, faceRy);
    _drawMouth(canvas, s, cx, faceCy, faceRy);

    // Zwergbart nur für männlich/neutral
    if (race == _AvatarRace.zwerg && gender != _AvatarGender.weiblich) {
      _drawBeard(canvas, s, cx, faceCy, faceRy);
    }
  }

  void _drawHair(
    Canvas canvas,
    double s,
    double cx,
    double faceCy,
    double faceRx,
    double faceRy,
  ) {
    final paint = Paint()..color = hairColor;

    // Langes Haar für weiblich/neutral hinter dem Gesicht
    if (gender != _AvatarGender.maennlich) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, faceCy + faceRy * 0.55),
            width: faceRx * 2.5,
            height: faceRy * 1.3,
          ),
          Radius.circular(s * 0.10),
        ),
        paint,
      );
    }

    // Haarkappe oben: Oval, das über die Gesichtsoberkante ragt
    final hairRx = gender == _AvatarGender.maennlich ? faceRx * 1.06 : faceRx * 1.22;
    final hairRy = faceRy * 0.75;
    final hairCy = faceCy - faceRy * 0.80;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, hairCy),
        width: hairRx * 2,
        height: hairRy * 2,
      ),
      paint,
    );
  }

  void _drawEars(
    Canvas canvas,
    double s,
    double cx,
    double faceCy,
    double faceRx,
    double faceRy,
  ) {
    final paint = Paint()..color = _skinFarbe;
    final earCy = faceCy - faceRy * 0.05;
    final earRx = s * 0.065;
    final earRy = s * 0.090;

    for (final side in [-1.0, 1.0]) {
      final earCx = cx + side * (faceRx - s * 0.01);
      if (race == _AvatarRace.elf) {
        // Spitze Elfenohren als Dreieckspfad
        final path = Path()
          ..moveTo(earCx, earCy - earRy * 0.55)
          ..lineTo(earCx + side * earRx * 1.9, earCy - earRy * 1.35)
          ..lineTo(earCx, earCy + earRy * 0.55)
          ..close();
        canvas.drawPath(path, paint);
      } else {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(earCx, earCy),
            width: earRx * 2,
            height: earRy * 2,
          ),
          paint,
        );
      }
    }
  }

  void _drawEyes(
    Canvas canvas,
    double s,
    double cx,
    double faceCy,
    double faceRy,
  ) {
    final eyeY = faceCy - faceRy * 0.18;
    final eyeOffsetX = s * 0.110;
    final scleraR = s * 0.068;
    final irisR = s * 0.050;
    final pupilR = s * 0.026;

    for (final side in [-1.0, 1.0]) {
      final eyeX = cx + side * eyeOffsetX;
      canvas.drawCircle(Offset(eyeX, eyeY), scleraR, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(eyeX, eyeY), irisR, Paint()..color = eyeColor);
      canvas.drawCircle(Offset(eyeX, eyeY), pupilR, Paint()..color = Colors.black87);
    }
  }

  void _drawNose(
    Canvas canvas,
    double s,
    double cx,
    double faceCy,
    double faceRy,
  ) {
    final noseY = faceCy + faceRy * 0.13;
    final nostrilR = s * 0.025;
    final paint = Paint()..color = _skinSchatten;
    canvas.drawCircle(Offset(cx - s * 0.04, noseY), nostrilR, paint);
    canvas.drawCircle(Offset(cx + s * 0.04, noseY), nostrilR, paint);
  }

  void _drawMouth(
    Canvas canvas,
    double s,
    double cx,
    double faceCy,
    double faceRy,
  ) {
    final mouthY = faceCy + faceRy * 0.38;
    final path = Path()
      ..moveTo(cx - s * 0.09, mouthY)
      ..quadraticBezierTo(cx, mouthY + s * 0.038, cx + s * 0.09, mouthY);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFC47A6A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.028
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawBeard(
    Canvas canvas,
    double s,
    double cx,
    double faceCy,
    double faceRy,
  ) {
    final beardTop = faceCy + faceRy * 0.68;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, beardTop + s * 0.065),
          width: s * 0.38,
          height: s * 0.15,
        ),
        Radius.circular(s * 0.075),
      ),
      Paint()..color = hairColor,
    );
  }

  @override
  bool shouldRepaint(_HeroAvatarPainter oldDelegate) =>
      oldDelegate.race != race ||
      oldDelegate.gender != gender ||
      oldDelegate.hairColor != hairColor ||
      oldDelegate.eyeColor != eyeColor;
}

// ─── Öffentliches Widget ─────────────────────────────────────────────────────

/// Zeigt einen stilisierten Avatarkreis für einen Helden an.
///
/// Die Darstellung wird deterministisch aus Rasse, Geschlecht, Haarfarbe
/// und Augenfarbe abgeleitet – ohne externe API oder Asset-Dateien.
class HeroAvatar extends StatelessWidget {
  const HeroAvatar({super.key, required this.hero, this.size = 48.0});

  final HeroSheet hero;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _HeroAvatarPainter(
          race: _raceFromString(hero.background.rasse),
          gender: _genderFromString(hero.appearance.geschlecht),
          hairColor: _hairColorFromString(hero.appearance.haarfarbe),
          eyeColor: _eyeColorFromString(hero.appearance.augenfarbe),
        ),
      ),
    );
  }
}
