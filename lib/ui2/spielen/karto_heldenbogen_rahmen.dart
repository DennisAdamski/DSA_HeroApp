import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';

/// Feine Messingfassung der äußeren Spielkacheln, ohne eigene Layoutgröße.
///
/// Die Zeichnung liegt vor der bestehenden Materialfläche und nimmt weder
/// Zeigerereignisse noch Platz ein. So bleiben Raster und Aktionen unverändert.
class KartoHeldenbogenRahmen extends StatelessWidget {
  /// Fasst [child] mit einer ruhigen Kontur und vier Kartuschenecken ein.
  const KartoHeldenbogenRahmen({super.key, required this.child});

  /// Bestehende Kachel samt ihrer Materialfläche und Bedienung.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _KartuschenZeichner(context.karto.messing),
      child: child,
    );
  }
}

// Kurze Doppellinien zitieren einen Heldenbogen, ohne den Inhalt einzurahmen.
class _KartuschenZeichner extends CustomPainter {
  const _KartuschenZeichner(this.farbe);

  final Color farbe;

  @override
  void paint(Canvas canvas, Size size) {
    final kontur = Paint()
      ..color = farbe.withValues(alpha: 0.48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final aussen = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        aussen.deflate(0.5),
        const Radius.circular(kKartoRadius),
      ),
      kontur,
    );

    final ecke = Paint()
      ..color = farbe.withValues(alpha: 0.68)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;
    for (final rechts in [false, true]) {
      for (final unten in [false, true]) {
        canvas.save();
        canvas.translate(rechts ? size.width : 0, unten ? size.height : 0);
        canvas.scale(rechts ? -1 : 1, unten ? -1 : 1);
        final winkel = Path()
          ..moveTo(5, 17)
          ..lineTo(5, 10)
          ..quadraticBezierTo(5, 5, 10, 5)
          ..lineTo(17, 5);
        canvas.drawPath(winkel, ecke);
        canvas.drawLine(const Offset(5, 5), const Offset(10, 10), ecke);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_KartuschenZeichner oldDelegate) =>
      oldDelegate.farbe != farbe;
}
