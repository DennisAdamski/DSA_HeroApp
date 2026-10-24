import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_bewegung.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Darstellender Ressourcenwert mit Balken.
///
/// Das Widget kennt weder Persistenz noch DSA-Grenzen: es zeigt genau die
/// uebergebenen Zahlen und meldet den Bearbeitungswunsch nach oben. Der
/// Balkenanteil ist **Darstellung** — er wird auf 0..1 begrenzt, damit ein
/// negativer oder ueberheilter Wert ueberhaupt zeichenbar bleibt. Der
/// gespeicherte Wert selbst wird dafuer nie gekuerzt, sondern unveraendert
/// als Text ausgegeben.
///
/// Farbe und Groesse sind bewusst getrennt verteilt: der **aktuelle** Wert
/// steht gross in Tinte, sein Maximum klein und leise daneben, und die
/// Ressourcenfarbe traegt allein das Symbol und die Balkenfuellung. Traegt
/// stattdessen die ganze Zeile die Ressourcenfarbe, ist nicht mehr erkennbar,
/// welche der beiden Zahlen zaehlt, und vier bunte Zeilen nebeneinander lesen
/// sich als Dekoration statt als Messwerte.
///
/// Mit [kuerzel] steht unter dem Balken, was bis zum Maximum fehlt — die
/// Frage, die am Spieltisch tatsaechlich gestellt wird. Aendert sich der Wert,
/// laeuft der Balken kurz nach; beim ersten Aufbau steht er sofort.
class KartoRessourcenwert extends StatelessWidget {
  /// Erstellt die Anzeige einer einzelnen Ressource.
  const KartoRessourcenwert({
    super.key,
    required this.bezeichnung,
    required this.aktuell,
    required this.maximum,
    this.icon,
    this.farbe,
    this.kuerzel,
    this.onBearbeiten,
  });

  /// Ausgeschriebener Name, etwa `Lebenspunkte`.
  final String bezeichnung;

  /// Gespeicherter aktueller Wert; darf negativ oder groesser als [maximum] sein.
  final int aktuell;

  /// Gespeichertes Maximum; `0` bedeutet „kein Balken“, nicht „Division“.
  final int maximum;

  /// Symbol vor der Bezeichnung; traegt zusammen mit dem Balken die Farbe.
  final IconData? icon;

  /// Ressourcenfarbe. `null` bleibt bewusst einfarbig: nur die drei Token
  /// [KartoTheme.lebensenergie], [KartoTheme.astralenergie] und
  /// [KartoTheme.ausdauer] stehen in der Spielansicht fuer sich.
  final Color? farbe;

  /// Kurzform fuer die Hinweiszeile, etwa `LeP`. `null` laesst sie weg.
  final String? kuerzel;

  /// Oeffnet die Bearbeitung. `null` blendet das Bearbeitungsziel aus.
  final VoidCallback? onBearbeiten;

  /// Abstand zum Maximum in Worten, oder `null` ohne [kuerzel] und Maximum.
  ///
  /// Wortlaut gepinnt in `karto_ressourcenwert_test.dart`. Ein negativer Wert
  /// zaehlt voll mit: bei -3 von 35 fehlen 38.
  String? get hinweis {
    final kurz = kuerzel;
    if (kurz == null || maximum <= 0) return null;
    final fehlt = maximum - aktuell;
    if (fehlt == 0) return 'Voll';
    if (fehlt < 0) return '${-fehlt} über Maximum';
    return fehlt == 1 ? '1 $kurz fehlt' : '$fehlt $kurz fehlen';
  }

  // Anteil fuer den Balken; ausserhalb von 0..1 gibt es nichts zu zeichnen.
  double get _anteil {
    if (maximum <= 0) return 0;
    return (aktuell / maximum).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final akzent = farbe ?? karto.schriftLeise;
    final werteZeile = '$aktuell / $maximum';
    final zusatz = hinweis;

    final inhalt = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Abstand.weit,
        vertical: Abstand.normal,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: akzent),
                const SizedBox(width: Abstand.knapp),
              ],
              Expanded(
                child: Text(
                  bezeichnung,
                  style: texte.etikett.copyWith(color: karto.schriftLeise),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Nur Hinweis auf die Bedienbarkeit; getippt wird die ganze Zelle.
              if (onBearbeiten != null)
                Icon(Icons.tune, size: 14, color: karto.schriftStumm),
            ],
          ),
          const SizedBox(height: Abstand.eng),
          // Wert und Fehlbetrag teilen sich eine Zeile: die Zelle bleibt so
          // niedrig, dass vier Ressourcen auf einem Telefon in zwei Reihen
          // passen. Eine Textzeile aus zwei Spans, nicht zwei Widgets:
          // `find.text` wertet bei `Text.rich` den zusammengesetzten Klartext
          // aus, die Zeile bleibt also als Ganzes auffindbar und vorlesbar.
          //
          // Der Wert hat Vorrang vor dem Fehlbetrag. Teilten sich beide den
          // Platz, kuerzte eine schmale Zelle das Maximum zu „51 / …“ – die
          // Zahl, um die es geht. Passt der Fehlbetrag nicht mehr daneben,
          // rueckt er deshalb in eine eigene Zeile unter den Wert
          // ([_WertZeile]).
          _WertZeile(
            wert: Text.rich(
              TextSpan(
                style: texte.wertGross.copyWith(color: karto.schrift),
                children: <InlineSpan>[
                  TextSpan(text: '$aktuell'),
                  TextSpan(
                    text: ' / $maximum',
                    style: texte.wert.copyWith(color: karto.schriftStumm),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            hinweis: zusatz == null
                ? null
                : Text(
                    zusatz,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: texte.marke.copyWith(
                      color: karto.schriftLeise,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
          const SizedBox(height: Abstand.knapp),
          Semantics(
            label: bezeichnung,
            value: werteZeile,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(kKartoRadiusKlein),
              // Ohne Anfangswert beginnt die Tween am Ziel: der erste Aufbau
              // zeichnet sofort, erst eine Aenderung laeuft nach.
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: _anteil),
                duration: kartoDauer(context, Bewegung.mittel),
                curve: Bewegung.kurve,
                builder: (context, anteil, _) => LinearProgressIndicator(
                  value: anteil,
                  minHeight: 4,
                  backgroundColor: karto.raster,
                  valueColor: AlwaysStoppedAnimation<Color>(akzent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (onBearbeiten == null) return inhalt;
    return Tooltip(
      message: '$bezeichnung ändern',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onBearbeiten,
          borderRadius: BorderRadius.circular(kKartoRadiusKlein),
          child: inhalt,
        ),
      ),
    );
  }
}

/// Wert und Fehlbetrag: nebeneinander auf gemeinsamer Grundlinie, wenn beide
/// ungekuerzt passen, sonst der Fehlbetrag in einer eigenen Zeile darunter.
///
/// Ein eigenes Layout statt `LayoutBuilder`: die Ressourcenleiste gleicht die
/// Zellen einer Reihe mit `IntrinsicHeight` an, und `LayoutBuilder` kann keine
/// intrinsischen Masse liefern.
class _WertZeile extends MultiChildRenderObjectWidget {
  _WertZeile({required Widget wert, Widget? hinweis})
    : super(children: <Widget>[wert, ?hinweis]);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderWertZeile();
}

class _WertZeileDaten extends ContainerBoxParentData<RenderBox> {}

class _RenderWertZeile extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _WertZeileDaten>,
        RenderBoxContainerDefaultsMixin<RenderBox, _WertZeileDaten> {
  static const double _luecke = Abstand.normal;

  RenderBox get _wert => firstChild!;
  RenderBox? get _hinweis => childCount > 1 ? lastChild : null;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _WertZeileDaten) {
      child.parentData = _WertZeileDaten();
    }
  }

  // Ob beide in voller Laenge nebeneinander passen.
  bool _nebeneinander(RenderBox hinweis, double breite) =>
      _wert.getMaxIntrinsicWidth(double.infinity) +
          _luecke +
          hinweis.getMaxIntrinsicWidth(double.infinity) <=
      breite;

  @override
  double computeMinIntrinsicWidth(double height) {
    final hinweis = _hinweis;
    final wert = _wert.getMinIntrinsicWidth(height);
    return hinweis == null
        ? wert
        : math.max(wert, hinweis.getMinIntrinsicWidth(height));
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final hinweis = _hinweis;
    final wert = _wert.getMaxIntrinsicWidth(height);
    return hinweis == null
        ? wert
        : wert + _luecke + hinweis.getMaxIntrinsicWidth(height);
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      computeMaxIntrinsicHeight(width);

  // Nebeneinander bestimmt der grosse Wert die Hoehe; der Fehlbetrag ist
  // kleiner gesetzt und reicht weder ueber noch unter ihn hinaus.
  @override
  double computeMaxIntrinsicHeight(double width) {
    final hinweis = _hinweis;
    final wert = _wert.getMaxIntrinsicHeight(width);
    if (hinweis == null) return wert;
    final klein = hinweis.getMaxIntrinsicHeight(width);
    return _nebeneinander(hinweis, width)
        ? math.max(wert, klein)
        : wert + klein;
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final breite = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : computeMaxIntrinsicWidth(double.infinity);
    return constraints.constrain(
      Size(breite, computeMaxIntrinsicHeight(breite)),
    );
  }

  @override
  void performLayout() {
    final breite = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : computeMaxIntrinsicWidth(double.infinity);
    final locker = BoxConstraints(maxWidth: breite);
    _wert.layout(locker, parentUsesSize: true);
    final wertDaten = _wert.parentData! as _WertZeileDaten
      ..offset = Offset.zero;
    final hinweis = _hinweis;
    if (hinweis == null) {
      size = constraints.constrain(Size(breite, _wert.size.height));
      return;
    }
    final hinweisDaten = hinweis.parentData! as _WertZeileDaten;
    if (!_nebeneinander(hinweis, breite)) {
      hinweis.layout(locker, parentUsesSize: true);
      hinweisDaten.offset = Offset(0, _wert.size.height);
      size = constraints.constrain(
        Size(breite, _wert.size.height + hinweis.size.height),
      );
      return;
    }
    hinweis.layout(
      BoxConstraints(maxWidth: breite - _wert.size.width - _luecke),
      parentUsesSize: true,
    );
    // Gemeinsame Grundlinie, der Fehlbetrag buendig rechts.
    final grundWert = _wert.getDistanceToBaseline(TextBaseline.alphabetic)!;
    final grundHinweis = hinweis.getDistanceToBaseline(
      TextBaseline.alphabetic,
    )!;
    final grund = math.max(grundWert, grundHinweis);
    wertDaten.offset = Offset(0, grund - grundWert);
    hinweisDaten.offset = Offset(
      breite - hinweis.size.width,
      grund - grundHinweis,
    );
    size = constraints.constrain(
      Size(
        breite,
        math.max(
          wertDaten.offset.dy + _wert.size.height,
          hinweisDaten.offset.dy + hinweis.size.height,
        ),
      ),
    );
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
