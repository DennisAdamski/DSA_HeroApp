import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_bewegung.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_ornamente.dart';

/// Endlicher Kompassauftritt am Spieltisch; danach bleibt das Siegel ruhig.
class KartoSpieltischSiegel extends StatefulWidget {
  /// Zeigt die vorhandene Kompassrose mit optionalem Messinglicht.
  const KartoSpieltischSiegel({super.key});

  @override
  State<KartoSpieltischSiegel> createState() => _SpieltischSiegelState();
}

class _SpieltischSiegelState extends State<KartoSpieltischSiegel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _licht = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    value: 1,
  );
  bool _aufgetreten = false;

  // Keine Timer oder Schleifen: nur Auftritt und bewusste Interaktionen.
  void _anregen() {
    if (kartoDekorationAktiv(context)) _licht.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!kartoDekorationAktiv(context)) {
      _licht.stop();
      _licht.value = 1;
    } else if (!_aufgetreten) {
      _anregen();
    }
    // Einschalten oder ein Themewechsel spielt den Auftritt nicht erneut ab.
    _aufgetreten = true;
  }

  @override
  void dispose() {
    _licht.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final farbe = context.karto.messing;
    return ExcludeSemantics(
      child: MouseRegion(
        onEnter: (_) => _anregen(),
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _anregen(),
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _licht,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: KartoKompassrose(groesse: 32),
              ),
              builder: (context, child) {
                final fortschritt = Curves.easeOutCubic.transform(_licht.value);
                return CustomPaint(
                  foregroundPainter: _SiegelLicht(farbe, _licht.value),
                  child: Transform.rotate(
                    angle: (1 - fortschritt) * -math.pi / 5,
                    child: child,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// Ein kurzer Lichtbogen zieht außen herum und verschwindet vollständig.
class _SiegelLicht extends CustomPainter {
  const _SiegelLicht(this.farbe, this.fortschritt);

  final Color farbe;
  final double fortschritt;

  @override
  void paint(Canvas canvas, Size size) {
    if (fortschritt <= 0 || fortschritt >= 1) return;
    final staerke = math.sin(fortschritt * math.pi);
    final pinsel = Paint()
      ..color = farbe.withValues(alpha: staerke * 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final ring = (Offset.zero & size).deflate(1.5);
    final winkel = fortschritt * math.pi * 2 - math.pi / 2;
    canvas.drawArc(ring, winkel, math.pi * 0.65, false, pinsel);
    final punkt = ring.center + Offset.fromDirection(winkel, ring.width / 2);
    canvas.drawCircle(punkt, 1.8, Paint()..color = pinsel.color);
  }

  @override
  bool shouldRepaint(_SiegelLicht oldDelegate) =>
      oldDelegate.farbe != farbe || oldDelegate.fortschritt != fortschritt;
}
