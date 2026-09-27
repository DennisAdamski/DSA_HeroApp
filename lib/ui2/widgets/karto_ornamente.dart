/// Ornamente der neuen Oberflaeche: Kompassrose, Kompassring, Hoehenlinien,
/// Zierlinie und Stern.
///
/// Alles hier ist Schmuck im engen Sinn: kein Ornament traegt eine Bedeutung,
/// die nicht auch ohne es da waere. Deshalb sind sie aus der Semantik
/// herausgenommen, zeichnen in `KartoTheme.messing` (nie Textfarbe) und sind
/// vollstaendig deterministisch — dieselbe Groesse ergibt dieselben Linien,
/// damit Rasterbilder in Tests stabil bleiben.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_stroke.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';

// Ein Vollkreis im Bogenmass.
const double _vollkreis = math.pi * 2;

/// Kompassrose als Marke und Leerzustandsbild.
///
/// Doppelring, acht Teilstriche, ein Vierpunktstern mit schattierten Spitzen
/// in den Haupthimmelsrichtungen, ein schmalerer in den Nebenrichtungen und
/// eine Mittelraute.
class KartoKompassrose extends StatelessWidget {
  /// Erstellt eine quadratische Rose der Kantenlaenge [groesse].
  const KartoKompassrose({super.key, required this.groesse, this.farbe});

  /// Kantenlaenge.
  final double groesse;

  /// Linienfarbe. Standard ist `KartoTheme.messing`.
  final Color? farbe;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(groesse),
          painter: _KompassrosenMaler(
            farbe: farbe ?? KartoTheme.of(context).messing,
          ),
        ),
      ),
    );
  }
}

class _KompassrosenMaler extends CustomPainter {
  const _KompassrosenMaler({required this.farbe});

  final Color farbe;

  @override
  void paint(Canvas canvas, Size size) {
    final mitte = size.center(Offset.zero);
    // Die Linie liegt auf dem Radius; ohne Abzug schnitte der Rand sie an.
    final r = size.shortestSide / 2 - Strich.grat;
    if (r <= 0) return;

    final linie = Paint()
      ..color = farbe
      ..style = PaintingStyle.stroke
      ..strokeWidth = Strich.grat
      ..isAntiAlias = true;
    final haar = Paint()
      ..color = farbe.withValues(alpha: farbe.a * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = Strich.hoehenlinie;

    canvas.drawCircle(mitte, r, linie);
    canvas.drawCircle(mitte, r * 0.84, haar);

    // Teilstriche zwischen den Ringen, kraeftiger in den Haupthimmelsrichtungen.
    for (var i = 0; i < 16; i++) {
      final winkel = i * _vollkreis / 16 - math.pi / 2;
      final haupt = i.isEven;
      final innen = haupt ? r * 0.84 : r * 0.9;
      canvas.drawLine(
        mitte + Offset.fromDirection(winkel, innen),
        mitte + Offset.fromDirection(winkel, r),
        haupt ? linie : haar,
      );
    }

    // Nebenrichtungen: schmaler Stern hinter dem Hauptstern.
    _stern(
      canvas,
      mitte,
      spitze: r * 0.5,
      taille: r * 0.1,
      drehung: math.pi / 4,
      hell: 0.08,
      dunkel: 0.3,
    );
    // Haupthimmelsrichtungen.
    _stern(
      canvas,
      mitte,
      spitze: r * 0.8,
      taille: r * 0.15,
      drehung: 0,
      hell: 0.12,
      dunkel: 0.55,
    );

    // Mittelraute.
    final raute = Path()
      ..moveTo(mitte.dx, mitte.dy - r * 0.07)
      ..lineTo(mitte.dx + r * 0.07, mitte.dy)
      ..lineTo(mitte.dx, mitte.dy + r * 0.07)
      ..lineTo(mitte.dx - r * 0.07, mitte.dy)
      ..close();
    canvas.drawPath(raute, Paint()..color = farbe);
  }

  // Vier Spitzen, jede aus zwei Dreiecken: eine Seite hell, eine dunkel, wie
  // die schattierten Strahlen alter Seekarten.
  void _stern(
    Canvas canvas,
    Offset mitte, {
    required double spitze,
    required double taille,
    required double drehung,
    required double hell,
    required double dunkel,
  }) {
    final kontur = Paint()
      ..color = farbe
      ..style = PaintingStyle.stroke
      ..strokeWidth = Strich.hoehenlinie * 1.5
      ..strokeJoin = StrokeJoin.miter;
    for (var i = 0; i < 4; i++) {
      final winkel = drehung + i * math.pi / 2 - math.pi / 2;
      final ende = mitte + Offset.fromDirection(winkel, spitze);
      final links = mitte + Offset.fromDirection(winkel - math.pi / 4, taille);
      final rechts = mitte + Offset.fromDirection(winkel + math.pi / 4, taille);
      final linkeHaelfte = Path()
        ..moveTo(mitte.dx, mitte.dy)
        ..lineTo(links.dx, links.dy)
        ..lineTo(ende.dx, ende.dy)
        ..close();
      final rechteHaelfte = Path()
        ..moveTo(mitte.dx, mitte.dy)
        ..lineTo(ende.dx, ende.dy)
        ..lineTo(rechts.dx, rechts.dy)
        ..close();
      canvas.drawPath(
        linkeHaelfte,
        Paint()..color = farbe.withValues(alpha: farbe.a * hell),
      );
      canvas.drawPath(
        rechteHaelfte,
        Paint()..color = farbe.withValues(alpha: farbe.a * dunkel),
      );
      final umriss = Path()
        ..moveTo(links.dx, links.dy)
        ..lineTo(ende.dx, ende.dy)
        ..lineTo(rechts.dx, rechts.dy);
      canvas.drawPath(umriss, kontur);
    }
  }

  @override
  bool shouldRepaint(_KompassrosenMaler alt) => alt.farbe != farbe;
}

/// Ringfassung mit Teilstrichen fuer Avatar oder Monogramm.
///
/// Der Ring ist die Konstante, nur sein Inhalt wechselt: Helden mit und ohne
/// Bild sehen an derselben Stelle gleich gebaut aus. Der Inhalt wird rund
/// beschnitten und liegt **unter** dem Ring, damit ein randvolles Bild ihn
/// nicht verdeckt.
class KartoKompassring extends StatelessWidget {
  /// Fasst [child] in einen Ring der Kantenlaenge [groesse].
  const KartoKompassring({
    super.key,
    required this.groesse,
    required this.child,
    this.farbe,
    this.schein = false,
  });

  /// Aussenmass einschliesslich Ring.
  final double groesse;

  /// Rund beschnittener Inhalt.
  final Widget child;

  /// Ringfarbe. Standard ist `KartoTheme.messing`.
  final Color? farbe;

  /// Legt einen weichen, radialen Messingschein hinter den Ring.
  ///
  /// Einer der beiden Verlaeufe, die Kartograph kennt; gedacht fuer die
  /// Heldenmarke auf dem dunklen Navigationsgrund.
  final bool schein;

  /// Abstand vom Aussenrand bis zum Inhalt.
  static double randFuer(double groesse) => math.max(6, groesse * 0.085);

  @override
  Widget build(BuildContext context) {
    final ton = farbe ?? KartoTheme.of(context).messing;
    final rand = randFuer(groesse);
    return SizedBox.square(
      dimension: groesse,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (schein)
            Positioned.fill(
              child: ExcludeSemantics(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        ton.withValues(alpha: 0.22),
                        ton.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          SizedBox.square(
            dimension: groesse - rand * 2,
            child: ClipOval(child: child),
          ),
          Positioned.fill(
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _KompassringMaler(farbe: ton, rand: rand),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KompassringMaler extends CustomPainter {
  const _KompassringMaler({required this.farbe, required this.rand});

  final Color farbe;
  final double rand;

  @override
  void paint(Canvas canvas, Size size) {
    final mitte = size.center(Offset.zero);
    final aussen = size.shortestSide / 2 - Strich.grat / 2;
    final innen = aussen - rand + Strich.grat;
    if (innen <= 0) return;
    final linie = Paint()
      ..color = farbe
      ..style = PaintingStyle.stroke
      ..strokeWidth = Strich.grat;
    final haar = Paint()
      ..color = farbe.withValues(alpha: farbe.a * 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = Strich.hoehenlinie;

    canvas.drawCircle(mitte, aussen, linie);
    canvas.drawCircle(mitte, innen, haar);

    // Teilstriche alle zehn Grad; die Haupthimmelsrichtungen tragen Rauten.
    final band = aussen - innen;
    for (var i = 0; i < 36; i++) {
      if (i % 9 == 0) continue;
      final winkel = i * _vollkreis / 36 - math.pi / 2;
      final lang = i % 3 == 0;
      canvas.drawLine(
        mitte +
            Offset.fromDirection(winkel, aussen - band * (lang ? 0.7 : 0.4)),
        mitte + Offset.fromDirection(winkel, aussen),
        haar,
      );
    }
    final fuellung = Paint()..color = farbe;
    for (var i = 0; i < 4; i++) {
      final winkel = i * math.pi / 2 - math.pi / 2;
      final punkt = mitte + Offset.fromDirection(winkel, aussen - band / 2);
      final quer = Offset.fromDirection(winkel + math.pi / 2, band * 0.45);
      final laengs = Offset.fromDirection(winkel, band * 0.75);
      final raute = Path()
        ..moveTo((punkt + laengs).dx, (punkt + laengs).dy)
        ..lineTo((punkt + quer).dx, (punkt + quer).dy)
        ..lineTo((punkt - laengs).dx, (punkt - laengs).dy)
        ..lineTo((punkt - quer).dx, (punkt - quer).dy)
        ..close();
      canvas.drawPath(raute, fuellung);
    }
  }

  @override
  bool shouldRepaint(_KompassringMaler alt) =>
      alt.farbe != farbe || alt.rand != rand;
}

/// Lage der Huegel eines Hoehenlinienbildes.
enum KartoGelaende {
  /// Zwei Kuppen, eine grosse unten links, eine kleine oben rechts.
  zweiKuppen,

  /// Ein langgestreckter Ruecken quer ueber die Flaeche.
  ruecken,
}

/// Hoehenlinien als Wasserzeichen.
///
/// Gewellte, geschlossene Konturen um wenige Kuppen — das Motiv, von dem
/// Kartographs Linienstaerken ihre Namen haben. Gedacht fuer sehr niedrige
/// Deckkraft auf Navigation und Leerflaechen. Die Wellung entsteht aus fest
/// gewaehlten Sinusueberlagerungen, nicht aus Zufall.
class KartoHoehenlinien extends StatelessWidget {
  /// Fuellt den verfuegbaren Platz mit Hoehenlinien.
  const KartoHoehenlinien({
    super.key,
    required this.farbe,
    this.gelaende = KartoGelaende.zweiKuppen,
  });

  /// Linienfarbe einschliesslich Deckkraft.
  final Color farbe;

  /// Anordnung der Kuppen.
  final KartoGelaende gelaende;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _HoehenlinienMaler(farbe: farbe, gelaende: gelaende),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

// Eine Kuppe: Lage als Anteil der Flaeche, Radius als Anteil der kuerzeren
// Seite, Zahl der Linien und die Phasen ihrer Wellung.
typedef _Kuppe = ({
  double x,
  double y,
  double radius,
  int linien,
  double phase,
  double streckung,
});

class _HoehenlinienMaler extends CustomPainter {
  const _HoehenlinienMaler({required this.farbe, required this.gelaende});

  final Color farbe;
  final KartoGelaende gelaende;

  List<_Kuppe> get _kuppen => switch (gelaende) {
    KartoGelaende.zweiKuppen => const <_Kuppe>[
      (x: 0.18, y: 0.82, radius: 0.95, linien: 9, phase: 0.4, streckung: 1.25),
      (x: 0.92, y: 0.18, radius: 0.45, linien: 5, phase: 2.1, streckung: 0.9),
    ],
    KartoGelaende.ruecken => const <_Kuppe>[
      (x: 0.35, y: 0.62, radius: 0.8, linien: 8, phase: 1.3, streckung: 1.8),
      (x: 0.88, y: 0.9, radius: 0.35, linien: 4, phase: 3.2, streckung: 1.1),
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final stift = Paint()
      ..color = farbe
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..isAntiAlias = true;
    final basis = size.shortestSide;
    for (final kuppe in _kuppen) {
      final mitte = Offset(size.width * kuppe.x, size.height * kuppe.y);
      for (var k = 1; k <= kuppe.linien; k++) {
        final anteil = k / kuppe.linien;
        final r = basis * kuppe.radius * anteil;
        // Aussen welliger als innen, wie bei echtem Gelaende.
        final wellung = 0.05 + 0.07 * anteil;
        final phase = kuppe.phase + k * 0.37;
        final pfad = Path();
        const schritte = 120;
        for (var i = 0; i <= schritte; i++) {
          final t = i / schritte * _vollkreis;
          final faktor =
              1 +
              wellung *
                  (math.sin(3 * t + phase) * 0.6 +
                      math.sin(5 * t + phase * 1.7) * 0.3 +
                      math.sin(2 * t - phase * 0.5) * 0.5);
          final punkt = Offset(
            mitte.dx + math.cos(t) * r * faktor * kuppe.streckung,
            mitte.dy + math.sin(t) * r * faktor,
          );
          if (i == 0) {
            pfad.moveTo(punkt.dx, punkt.dy);
          } else {
            pfad.lineTo(punkt.dx, punkt.dy);
          }
        }
        pfad.close();
        canvas.drawPath(pfad, stift);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HoehenlinienMaler alt) =>
      alt.farbe != farbe || alt.gelaende != gelaende;
}

/// Vierpunktstern, das kleine Zeichen der Zierlinie.
class KartoStern extends StatelessWidget {
  /// Erstellt einen Stern der Kantenlaenge [groesse].
  const KartoStern({super.key, this.groesse = 10, this.farbe});

  /// Kantenlaenge.
  final double groesse;

  /// Farbe. Standard ist `KartoTheme.messing`.
  final Color? farbe;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(groesse),
        painter: _SternMaler(farbe: farbe ?? KartoTheme.of(context).messing),
      ),
    );
  }
}

class _SternMaler extends CustomPainter {
  const _SternMaler({required this.farbe});

  final Color farbe;

  @override
  void paint(Canvas canvas, Size size) {
    final m = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final t = r * 0.22;
    final pfad = Path()
      ..moveTo(m.dx, m.dy - r)
      ..quadraticBezierTo(m.dx + t * 0.3, m.dy - t * 0.3, m.dx + r, m.dy)
      ..quadraticBezierTo(m.dx + t * 0.3, m.dy + t * 0.3, m.dx, m.dy + r)
      ..quadraticBezierTo(m.dx - t * 0.3, m.dy + t * 0.3, m.dx - r, m.dy)
      ..quadraticBezierTo(m.dx - t * 0.3, m.dy - t * 0.3, m.dx, m.dy - r)
      ..close();
    canvas.drawPath(pfad, Paint()..color = farbe);
  }

  @override
  bool shouldRepaint(_SternMaler alt) => alt.farbe != farbe;
}

/// Haarlinie mit Stern in der Mitte.
///
/// Trennt Identitaet von Navigation und schliesst eine Seite ab. Kein Ersatz
/// fuer `Divider`: wo eine Linie gliedert, bleibt es bei der Linie.
class KartoZierlinie extends StatelessWidget {
  /// Erstellt eine Zierlinie ueber die verfuegbare Breite.
  const KartoZierlinie({super.key, this.farbe, this.maxBreite});

  /// Farbe von Linie und Stern. Standard ist `KartoTheme.messing`.
  final Color? farbe;

  /// Begrenzt die Linie, etwa in einer breiten Spalte.
  final double? maxBreite;

  @override
  Widget build(BuildContext context) {
    final ton = farbe ?? KartoTheme.of(context).messing;
    final linie = Expanded(
      child: Container(
        height: Strich.hoehenlinie,
        color: ton.withValues(alpha: ton.a * 0.7),
      ),
    );
    Widget zeile = SizedBox(
      height: 12,
      child: Row(
        children: [
          linie,
          const SizedBox(width: 8),
          KartoStern(groesse: 10, farbe: ton),
          const SizedBox(width: 8),
          linie,
        ],
      ),
    );
    if (maxBreite != null) {
      zeile = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxBreite!),
          child: zeile,
        ),
      );
    }
    return ExcludeSemantics(child: zeile);
  }
}
