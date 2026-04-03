import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/probe_engine.dart';

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/// Steuert [AnimatedDiceRow] von außen (Wurf auslösen, Zustand abfragen).
class DiceRollController {
  _AnimatedDiceRowState? _state;

  bool get isRolling => _state?._phase == _DicePhase.rolling;

  /// Startet den animierten Wurf mit den übergebenen Endwerten.
  void startRoll(List<int> values) => _state?.startRoll(values);

  /// Setzt den Bereich auf den Idle-Zustand zurück.
  void reset() => _state?.reset();

  void _attach(_AnimatedDiceRowState s) => _state = s;
  void _detach() => _state = null;
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

/// Zeigt eine Reihe animierter Würfel entsprechend [DiceSpec].
///
/// Zustandsmaschine: idle → rolling → revealed → (erneut rolling via reset)
class AnimatedDiceRow extends StatefulWidget {
  const AnimatedDiceRow({
    super.key,
    required this.diceSpec,
    required this.controller,
    this.onRollComplete,
    this.probeType,
  });

  final DiceSpec diceSpec;
  final DiceRollController controller;
  final VoidCallback? onRollComplete;

  /// Wird für die Farbwahl der W20-Würfel verwendet.
  final ProbeType? probeType;

  @override
  State<AnimatedDiceRow> createState() => _AnimatedDiceRowState();
}

enum _DicePhase { idle, rolling, revealed }

class _AnimatedDiceRowState extends State<AnimatedDiceRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  _DicePhase _phase = _DicePhase.idle;
  List<int> _displayValues = const [];
  List<int>? _finalValues;
  Timer? _cycleTimer;
  final _rng = math.Random();

  static const int _baseDurationMs = 1400;
  static const int _staggerMs = 80;

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
    final totalMs =
        _baseDurationMs + (widget.diceSpec.count - 1) * _staggerMs;
    _animController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    );
    // Rebuild auf jedem Frame für flüssige Rotation.
    _animController.addListener(_onFrame);
    _animController.addStatusListener(_onStatus);
    _displayValues = List<int>.filled(widget.diceSpec.count, 0);
  }

  @override
  void dispose() {
    widget.controller._detach();
    _cycleTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _onFrame() {
    if (mounted) setState(() {});
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _cycleTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _phase = _DicePhase.revealed;
      _displayValues = _finalValues ?? _displayValues;
    });
    widget.onRollComplete?.call();
  }

  void startRoll(List<int> values) {
    if (!mounted) return;
    _cycleTimer?.cancel();
    _finalValues = values;
    setState(() {
      _phase = _DicePhase.rolling;
      _displayValues = List<int>.filled(widget.diceSpec.count, 1);
    });
    _animController.forward(from: 0);
    _cycleTimer = Timer.periodic(const Duration(milliseconds: 75), (_) {
      if (!mounted) return;
      setState(() {
        _displayValues = List<int>.generate(
          widget.diceSpec.count,
          (_) => _rng.nextInt(widget.diceSpec.sides) + 1,
        );
      });
    });
  }

  void reset() {
    if (!mounted) return;
    _cycleTimer?.cancel();
    _animController.stop();
    setState(() {
      _phase = _DicePhase.idle;
      _displayValues = List<int>.filled(widget.diceSpec.count, 0);
      _finalValues = null;
    });
  }

  bool get _isBlueVariant {
    return widget.probeType == ProbeType.attribute ||
        widget.probeType == ProbeType.combatAttack ||
        widget.probeType == ProbeType.combatParry ||
        widget.probeType == ProbeType.dodge;
  }

  int? _valueAt(int index) {
    if (_phase == _DicePhase.idle) return null;
    if (index >= _displayValues.length) return null;
    return _displayValues[index];
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: List<Widget>.generate(
        widget.diceSpec.count,
        _buildDieSlot,
      ),
    );
  }

  Widget _buildDieSlot(int index) {
    final die = _buildSingleDie(index);
    if (_phase != _DicePhase.rolling) return die;

    // Gestaffelter Start: Würfel i beginnt i*80ms später.
    final totalMs =
        _baseDurationMs + (widget.diceSpec.count - 1) * _staggerMs;
    final staggerOffset = (index * _staggerMs) / totalMs;
    final rawT = _animController.value;
    final localT = staggerOffset >= 1.0
        ? 0.0
        : ((rawT - staggerOffset) / (1.0 - staggerOffset)).clamp(0.0, 1.0);
    final easedT = Curves.easeOut.transform(localT);

    // 2,5 volle Umdrehungen, ausgebremst mit easeOut.
    final angle = easedT * 2 * math.pi * 2.5;
    // Scale-Bounce: kurzes Aufbauschen am Anfang.
    final scale = 1.0 + 0.18 * math.sin(localT * math.pi);

    return Transform.scale(
      scale: scale,
      child: Transform.rotate(
        angle: angle,
        child: die,
      ),
    );
  }

  Widget _buildSingleDie(int index) {
    final value = _valueAt(index);
    final sides = widget.diceSpec.sides;
    if (sides == 20) {
      return _W20Die(value: value, blue: _isBlueVariant);
    } else if (sides == 6) {
      return _W6Die(value: value);
    }
    return _FallbackDie(sides: sides, value: value);
  }
}

// ---------------------------------------------------------------------------
// W20-Würfel (facettierter 3D-Edelstein)
// ---------------------------------------------------------------------------

class _W20Die extends StatelessWidget {
  const _W20Die({this.value, required this.blue});

  final int? value;
  final bool blue;

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(_size, _size),
            painter: _W20Painter(blue: blue),
          ),
          if (value != null)
            Text(
              '$value',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                shadows: [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 4,
                    color: Color(0xFF000000),
                  ),
                ],
              ),
            )
          else
            Text(
              'W20',
              style: TextStyle(
                color: Colors.white.withAlpha(90),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

class _W20Painter extends CustomPainter {
  const _W20Painter({required this.blue});

  final bool blue;

  // Farben der 6 Flächen (von oben-rechts im Uhrzeigersinn).
  // Lichtquelle oben-links → Fläche 5 (TL) ist am hellsten.
  static const List<Color> _purpleFaces = [
    Color(0xFF9F7AEA), // TR
    Color(0xFF7C3AED), // R
    Color(0xFF5B21B6), // BR
    Color(0xFF3B1070), // BL
    Color(0xFF4C1D95), // L
    Color(0xFFC4B5FD), // TL (hellste)
  ];

  static const List<Color> _blueFaces = [
    Color(0xFF60A5FA), // TR
    Color(0xFF3B82F6), // R
    Color(0xFF1D4ED8), // BR
    Color(0xFF1E3A8A), // BL
    Color(0xFF1E40AF), // L
    Color(0xFF93C5FD), // TL (hellste)
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = cx - 2;

    // Sechseck-Eckpunkte (Spitze oben, im Uhrzeigersinn ab 12 Uhr).
    final verts = List<Offset>.generate(6, (i) {
      final angle = -math.pi / 2 + i * math.pi / 3;
      return Offset(cx + r * math.cos(angle), cy + r * math.sin(angle));
    });
    final center = Offset(cx, cy);

    // Schatten
    final shadowPath = Path()..addPolygon(verts, true);
    canvas.drawShadow(shadowPath, const Color(0xFF000000), 5, false);

    // 6 Dreiecksflächen
    final faces = blue ? _blueFaces : _purpleFaces;
    for (var i = 0; i < 6; i++) {
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(verts[i].dx, verts[i].dy)
        ..lineTo(verts[(i + 1) % 6].dx, verts[(i + 1) % 6].dy)
        ..close();
      canvas.drawPath(path, Paint()..color = faces[i]);
    }

    // Feine Trennlinien von Mitte zu Ecken
    for (var i = 0; i < 6; i++) {
      final isDark = i >= 3;
      canvas.drawLine(
        center,
        verts[i],
        Paint()
          ..color = (isDark ? Colors.black : Colors.white).withAlpha(
            isDark ? 100 : 38,
          )
          ..strokeWidth = 0.5,
      );
    }

    // Außenkontur
    final outline = Path()..addPolygon(verts, true);
    canvas.drawPath(
      outline,
      Paint()
        ..color = blue ? const Color(0xFF93C5FD) : const Color(0xFFA78BFA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Kanten-Highlight: TL-Kante (verts[5] → verts[0])
    canvas.drawLine(
      verts[5],
      verts[0],
      Paint()
        ..color = Colors.white.withAlpha(230)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      verts[0],
      verts[1],
      Paint()
        ..color = Colors.white.withAlpha(115)
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round,
    );

    // Spekularer Glanzpunkt (oben-links)
    canvas.save();
    canvas.translate(cx * 0.70, cy * 0.52);
    canvas.rotate(-30 * math.pi / 180);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 16, height: 10),
      Paint()..color = Colors.white.withAlpha(56),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _W20Painter old) => old.blue != blue;
}

// ---------------------------------------------------------------------------
// W6-Würfel (klassisch mit Pip-Augen)
// ---------------------------------------------------------------------------

class _W6Die extends StatelessWidget {
  const _W6Die({this.value});

  final int? value;

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(_size, _size),
            painter: _W6Painter(value: value),
          ),
          if (value == null)
            Text(
              'W6',
              style: TextStyle(
                color: const Color(0xFF2C1810).withAlpha(64),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

class _W6Painter extends CustomPainter {
  const _W6Painter({this.value});

  final int? value;

  // Pip-Positionen als (col, row) im 3×3-Raster (0-basiert).
  static const Map<int, List<(int, int)>> _pipLayout = {
    1: [(1, 1)],
    2: [(2, 0), (0, 2)],
    3: [(2, 0), (1, 1), (0, 2)],
    4: [(0, 0), (2, 0), (0, 2), (2, 2)],
    5: [(0, 0), (2, 0), (1, 1), (0, 2), (2, 2)],
    6: [(0, 0), (0, 1), (0, 2), (2, 0), (2, 1), (2, 2)],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect =
        RRect.fromRectAndRadius(rect, const Radius.circular(10));

    // Schatten
    canvas.drawShadow(
      Path()..addRRect(rrect),
      const Color(0xFF000000),
      5,
      false,
    );

    // Hintergrund-Gradient
    final gradient = const LinearGradient(
      begin: Alignment(-1, -1.2),
      end: Alignment(1, 1),
      colors: [Color(0xFFFFFDF5), Color(0xFFD4C8A8)],
    ).createShader(rect);
    canvas.drawRRect(rrect, Paint()..shader = gradient);

    // Helles Highlight oben
    canvas.drawLine(
      Offset(10, 2),
      Offset(size.width - 10, 2),
      Paint()
        ..color = Colors.white.withAlpha(179)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );

    // Pips zeichnen
    final v = value;
    if (v == null || v < 1 || v > 6) return;
    final pips = _pipLayout[v]!;
    const padding = 9.0;
    final cellSize = (size.width - 2 * padding) / 3;
    const pipRadius = 4.5;

    final pipPaint = Paint()
      ..color = const Color(0xFF2C1810)
      ..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = Colors.black.withAlpha(64)
      ..style = PaintingStyle.fill;

    for (final (col, row) in pips) {
      final pipCx = padding + col * cellSize + cellSize / 2;
      final pipCy = padding + row * cellSize + cellSize / 2;
      canvas.drawCircle(Offset(pipCx, pipCy + 0.8), pipRadius, shadowPaint);
      canvas.drawCircle(Offset(pipCx, pipCy), pipRadius, pipPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _W6Painter old) => old.value != value;
}

// ---------------------------------------------------------------------------
// Fallback-Würfel (andere Seitenanzahl)
// ---------------------------------------------------------------------------

class _FallbackDie extends StatelessWidget {
  const _FallbackDie({required this.sides, this.value});

  final int sides;
  final int? value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B4B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF7C3AED), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x80000000),
            offset: Offset(0, 3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Center(
        child: Text(
          value != null ? '$value' : 'W$sides',
          style: TextStyle(
            color: value != null
                ? Colors.white
                : Colors.white.withAlpha(102),
            fontSize: value != null ? 15 : 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
