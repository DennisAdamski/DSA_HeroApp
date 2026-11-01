import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_flaeche.dart';

/// Abschnittsrahmen der Spielansicht: Überschrift, optionale Aktion, Inhalt.
///
/// Der Abschnitt ist eine **gefüllte** Fläche. Vorher trug er nur einen Rahmen
/// auf dem Seitengrund; dadurch entstand keine Tiefe, und sechs Abschnitte
/// untereinander sahen aus wie sechs gleiche Formularkästen. Die Fläche trennt
/// jetzt, die Kante schärft nur noch.
///
/// Listenaktionen stehen laut Projektrichtlinie im Abschnittskopf.
///
/// Ein [akzent] hebt einzelne Begleitflaechen hervor, ohne eine weitere
/// Flaechenstufe einzufuehren: eine Messingkante oben wie bei einer
/// Kartenkartusche, oder eine leichte astrale Toenung fuer laufende Zauber.
class KartoAbschnitt extends StatelessWidget {
  /// Erstellt einen benannten Abschnitt.
  const KartoAbschnitt({
    super.key,
    required this.titel,
    required this.child,
    this.hinweis,
    this.aktion,
    this.stufe = KartoFlaechenstufe.feld,
    this.symbol,
    this.akzent,
    this.dicht = false,
  });

  /// Überschrift des Abschnitts.
  final String titel;

  /// Inhalt unterhalb der Überschrift.
  final Widget child;

  /// Ruhige Zweitzeile unter der Überschrift.
  ///
  /// Sparsam einsetzen. Eine Zeile unter **jeder** Überschrift ergibt sechs
  /// Erklärungen pro Ansicht, von denen die meisten das Offensichtliche sagen.
  /// Der Seitenkopf trägt die Einordnung der Ansicht, nicht der Abschnitt.
  final String? hinweis;

  /// Aktion im Abschnittskopf, etwa `Effekte verwalten`.
  final Widget? aktion;

  /// Flächenstufe; die Kontextspalte sitzt bewusst zurückgesetzt.
  final KartoFlaechenstufe stufe;

  /// Kleines Symbol vor der Überschrift, in der Farbe des Akzents.
  final IconData? symbol;

  /// Hervorhebung einer Begleitfläche; `null` lässt den Abschnitt schlicht.
  final KartoAkzent? akzent;

  /// Knapperer Innenabstand für schmale Hilfsleisten wie die Eigenschaften.
  final bool dicht;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final steuerung = KartoKachelSteuerung._von(context);
    final knapp = dicht || (steuerung?.dicht ?? false);
    final eingeklappt = steuerung?.eingeklappt ?? false;
    final zweitzeile = hinweis?.trim() ?? '';
    final akzentFarbe = akzent?.farbe(karto);
    final ueberschrift = symbol == null
        ? Text(titel, style: texte.abschnitt)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(symbol, size: 18, color: akzentFarbe ?? karto.messing),
              const SizedBox(width: Abstand.normal),
              Flexible(child: Text(titel, style: texte.abschnitt)),
            ],
          );

    final flaeche = KartoFlaeche(
      stufe: stufe,
      toenung: akzent?.toenung(karto),
      innen: EdgeInsets.all(knapp ? Abstand.weit : Abstand.block),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _mitEinklappknopf(
            steuerung: steuerung,
            karto: karto,
            kopfzeile: LayoutBuilder(
              builder: (context, constraints) {
                final kopf = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ueberschrift,
                    if (zweitzeile.isNotEmpty) ...[
                      const SizedBox(height: Abstand.eng),
                      // Etikett statt der kursiven Legende: kursiv gesetzte
                      // Serife in Fliesstextgroesse liest sich als zweite
                      // Ueberschrift, nicht als Beiwerk.
                      Text(
                        zweitzeile,
                        style: texte.etikett.copyWith(
                          color: karto.schriftLeise,
                        ),
                      ),
                    ],
                  ],
                );
                if (aktion == null) return kopf;
                // Wrap statt Row: in einer schmalen Seitenspalte passt eine
                // ausgeschriebene Kopfaktion sonst nicht mehr neben den Titel
                // und laeuft um Bruchteile eines Pixels ueber.
                return Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: Abstand.normal,
                  runSpacing: Abstand.normal,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth,
                      ),
                      child: kopf,
                    ),
                    aktion!,
                  ],
                );
              },
            ),
          ),
          if (!eingeklappt) ...[
            SizedBox(height: knapp ? Abstand.normal : Abstand.weit),
            // Die Steuerung gilt nur dem äußersten Abschnitt einer Kachel.
            steuerung == null
                ? child
                : KartoKachelSteuerung._leer(child: child),
          ],
        ],
      ),
    );
    final kante = akzent?.kante(karto);
    if (kante == null) return flaeche;
    // Eine einseitige Kante vertraegt keinen Radius an der Dekoration; sie
    // liegt deshalb als Leiste ueber der Flaeche und wird mit ihr gerundet.
    return ClipRRect(
      borderRadius: BorderRadius.circular(kKartoRadius),
      child: Stack(
        children: [
          flaeche,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 3,
            child: ColoredBox(color: kante),
          ),
        ],
      ),
    );
  }

  // Der Einklappknopf steht neben Titel und Kopfaktion, nicht in deren
  // Umbruch: so bleibt er auch in einer schmalen Kachel rechts oben.
  Widget _mitEinklappknopf({
    required KartoKachelSteuerung? steuerung,
    required KartoTheme karto,
    required Widget kopfzeile,
  }) {
    final einklappen = steuerung?.onEinklappen;
    if (steuerung == null || einklappen == null) return kopfzeile;
    final eingeklappt = steuerung.eingeklappt;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: kopfzeile),
        IconButton(
          key: ValueKey<String>('karto-kachel-${steuerung.kennung}-einklappen'),
          tooltip: eingeklappt ? '$titel aufklappen' : '$titel einklappen',
          visualDensity: VisualDensity.compact,
          icon: Icon(
            eingeklappt ? Icons.expand_more : Icons.expand_less,
            color: karto.schriftLeise,
          ),
          onPressed: () => einklappen(!eingeklappt),
        ),
      ],
    );
  }
}

/// Reicht die Einstellungen einer Rasterkachel an ihren Abschnitt (SPIEL-07).
///
/// Die Spielansicht legt sie um jede Kachel; der äußerste [KartoAbschnitt]
/// darin zeigt dann den Einklappknopf, blendet eingeklappt seinen Inhalt aus
/// und setzt im Raster den knappen Innenabstand. Verschachtelte Abschnitte
/// bleiben unberührt, damit nicht jede Teilkarte einen Knopf bekommt. So
/// müssen die Kacheln, die ihren Abschnitt selbst bauen (Dabei, Abenteuer,
/// Begleiter), nichts durchreichen.
class KartoKachelSteuerung extends InheritedWidget {
  /// Steuerung der Kachel [kennung].
  const KartoKachelSteuerung({
    super.key,
    required this.kennung,
    this.eingeklappt = false,
    this.onEinklappen,
    this.dicht = true,
    required super.child,
  });

  const KartoKachelSteuerung._leer({required super.child})
    : kennung = '',
      eingeklappt = false,
      onEinklappen = null,
      dicht = false;

  /// Kennung der Kachel für Schlüssel und Tests.
  final String kennung;

  /// Ob nur der Kopf sichtbar ist.
  final bool eingeklappt;

  /// Schaltet das Einklappen; ohne Rückruf entfällt der Knopf.
  final ValueChanged<bool>? onEinklappen;

  /// Knapper Innenabstand wie bei [KartoAbschnitt.dicht].
  final bool dicht;

  static KartoKachelSteuerung? _von(BuildContext context) {
    final steuerung = context
        .dependOnInheritedWidgetOfExactType<KartoKachelSteuerung>();
    return steuerung == null || steuerung.kennung.isEmpty ? null : steuerung;
  }

  @override
  bool updateShouldNotify(KartoKachelSteuerung oldWidget) =>
      oldWidget.kennung != kennung ||
      oldWidget.eingeklappt != eingeklappt ||
      oldWidget.dicht != dicht ||
      oldWidget.onEinklappen != onEinklappen;
}

/// Die zwei Hervorhebungen einer Begleitfläche.
///
/// Bewusst eine Aufzählung und keine freie Farbe: so bleibt die Spielansicht
/// bei den Token, und die drei Ressourcenfarben behalten ihren Vorrang.
enum KartoAkzent {
  /// Messingkante oben, etwa für den Kampf.
  messing,

  /// Leichte astrale Tönung, für laufende Zauber und Effekte.
  astral;

  /// Farbe des Symbols.
  Color farbe(KartoTheme token) => switch (this) {
    KartoAkzent.messing => token.messing,
    KartoAkzent.astral => token.astralenergie,
  };

  /// Oberkante oder `null`.
  Color? kante(KartoTheme token) => switch (this) {
    KartoAkzent.messing => token.messing,
    KartoAkzent.astral => null,
  };

  /// Tönung der Fläche oder `null`.
  Color? toenung(KartoTheme token) => switch (this) {
    KartoAkzent.messing => null,
    KartoAkzent.astral => token.astralenergie.withValues(alpha: 0.08),
  };
}
