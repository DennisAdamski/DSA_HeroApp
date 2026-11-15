import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_bewegung.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';

/// Feine Messingfassung der äußeren Spielkacheln, ohne eigene Layoutgröße.
///
/// Die Zeichnung liegt vor der bestehenden Materialfläche und nimmt weder
/// Zeigerereignisse noch Platz ein. So bleiben Raster und Aktionen unverändert.
class KartoHeldenbogenRahmen extends StatefulWidget {
  /// Fasst [child] mit einer ruhigen Kontur und vier Kartuschenecken ein.
  const KartoHeldenbogenRahmen({
    super.key,
    required this.child,
    this.aktiv = false,
    this.magisch = false,
  });

  /// Bestehende Kachel samt ihrer Materialfläche und Bedienung.
  final Widget child;

  /// Ob Zeiger oder Tastaturfokus in der Kachel liegen.
  final bool aktiv;

  /// Verwendet einen astralen Akzent statt Messing für den Lichtschimmer.
  final bool magisch;

  @override
  State<KartoHeldenbogenRahmen> createState() => _HeldenbogenRahmenState();
}

class _HeldenbogenRahmenState extends State<KartoHeldenbogenRahmen>
    with TickerProviderStateMixin {
  late final AnimationController _betonung = AnimationController(
    vsync: this,
    value: widget.aktiv ? 1 : 0,
  );
  late final AnimationController _schimmer = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
    value: 1,
  );

  // Keine Schleife: ein Schimmer folgt ausschließlich einer Interaktion.
  void _anregen() {
    if (kartoDekorationAktiv(context)) _schimmer.forward(from: 0);
  }

  @override
  void didUpdateWidget(KartoHeldenbogenRahmen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.aktiv != oldWidget.aktiv) _betonen(bewegen: true);
    if (widget.aktiv && !oldWidget.aktiv) _anregen();
  }

  // Anders als eine neue implizite Dauer stoppt der Zielwert sofort.
  void _betonen({bool bewegen = false}) {
    final dauer = kartoDauer(context, Bewegung.kurz);
    final ziel = widget.aktiv ? 1.0 : 0.0;
    if (dauer == Duration.zero) {
      _betonung.stop();
      _betonung.value = ziel;
    } else if (bewegen) {
      _betonung.animateTo(ziel, duration: dauer, curve: Bewegung.kurve);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _betonen();
    if (!kartoDekorationAktiv(context)) {
      _schimmer.stop();
      _schimmer.value = 1;
    }
  }

  @override
  void dispose() {
    _betonung.dispose();
    _schimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final token = context.karto;
    final licht = widget.magisch ? token.astralenergie : token.messing;
    return Listener(
      onPointerDown: (_) => _anregen(),
      child: AnimatedBuilder(
        animation: Listenable.merge([_schimmer, _betonung]),
        child: widget.child,
        builder: (context, child) => CustomPaint(
          foregroundPainter: _KartuschenZeichner(
            token.messing,
            licht: licht,
            betonung: _betonung.value,
            schimmer: _schimmer.value,
            magisch: widget.magisch,
          ),
          child: child,
        ),
      ),
    );
  }
}

// Kurze Doppellinien zitieren einen Heldenbogen, ohne den Inhalt einzurahmen.
class _KartuschenZeichner extends CustomPainter {
  const _KartuschenZeichner(
    this.farbe, {
    required this.licht,
    required this.betonung,
    required this.schimmer,
    required this.magisch,
  });

  final Color farbe;
  final Color licht;
  final double betonung;
  final double schimmer;
  final bool magisch;

  @override
  void paint(Canvas canvas, Size size) {
    final kontur = Paint()
      ..color = farbe.withValues(alpha: 0.48 + 0.35 * betonung)
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

    if (schimmer > 0 && schimmer < 1) {
      // Der Lichtlauf sitzt nur auf der Kontur, niemals über Text oder Zahlen.
      final lauf = -2 + schimmer * 4;
      final glanz = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = magisch ? 2 : 1.5
        ..shader = LinearGradient(
          begin: Alignment(lauf - 0.5, -1),
          end: Alignment(lauf + 0.5, 1),
          colors: [
            licht.withValues(alpha: 0),
            licht.withValues(alpha: 0.85),
            licht.withValues(alpha: 0),
          ],
        ).createShader(aussen);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          aussen.deflate(1.5),
          const Radius.circular(kKartoRadius),
        ),
        glanz,
      );
      if (magisch) {
        final funke = Paint()
          ..color = licht.withValues(alpha: (1 - schimmer) * 0.65);
        for (var i = 0; i < 3; i++) {
          final x = size.width - 25 - i * 11.0;
          final y = 5.0 + (i.isEven ? 0.0 : 3.0);
          canvas.drawCircle(Offset(x, y), 1.5, funke);
        }
      }
    }

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
      oldDelegate.farbe != farbe ||
      oldDelegate.licht != licht ||
      oldDelegate.betonung != betonung ||
      oldDelegate.schimmer != schimmer ||
      oldDelegate.magisch != magisch;
}
