import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:dsa_heldenverwaltung/ui2/foundation/karto_bewegung.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_kachelgroesse.dart';
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
    final vergroessern = steuerung?.onVergroessern;
    final titelBlock = symbol == null
        ? Text(titel, style: texte.abschnitt)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(symbol, size: 18, color: akzentFarbe ?? karto.messing),
              const SizedBox(width: Abstand.normal),
              Flexible(child: Text(titel, style: texte.abschnitt)),
            ],
          );
    // Mit Rückruf ist der Name die Klickfläche für die vergrößerte Ansicht;
    // das leise Symbol zeigt, dass sich hinter ihm etwas öffnet.
    final ueberschrift = vergroessern == null
        ? titelBlock
        : Tooltip(
            message: '$titel vergrößern',
            child: InkWell(
              key: ValueKey<String>(
                'karto-kachel-${steuerung!.kennung}-vergroessern',
              ),
              onTap: vergroessern,
              borderRadius: BorderRadius.circular(kKartoRadiusKlein),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Abstand.haar),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: titelBlock),
                    const SizedBox(width: Abstand.knapp),
                    _BeiBedarf(
                      child: Icon(
                        Icons.open_in_full,
                        size: 14,
                        color: karto.schriftLeise,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                : KartoKachelSteuerung._leer(
                    groesse: steuerung.groesse,
                    child: child,
                  ),
          ],
        ],
      ),
    );
    final kante = akzent?.kante(karto);
    // Eine einseitige Kante vertraegt keinen Radius an der Dekoration; sie
    // liegt deshalb als Leiste ueber der Flaeche und wird mit ihr gerundet.
    final kachel = kante == null
        ? flaeche
        : ClipRRect(
            borderRadius: BorderRadius.circular(kKartoRadius),
            child: Stack(
              // Reicht die Vorgaben durch: dehnt das Raster die Kachel
              // (Lückenschluss), füllt die Fläche die ganze Höhe.
              fit: StackFit.passthrough,
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
    // Nur der äußerste Abschnitt einer Kachel blendet seine Kopf-Bedienung
    // bei Bedarf ein.
    return steuerung == null ? kachel : _Kachelzeiger(child: kachel);
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
        // Eingeklappt bleibt der Pfeil stehen: er ist dann der einzige
        // Hinweis, dass die Kachel mehr enthält.
        _BeiBedarf(
          immer: eingeklappt,
          child: IconButton(
            key: ValueKey<String>(
              'karto-kachel-${steuerung.kennung}-einklappen',
            ),
            tooltip: eingeklappt ? '$titel aufklappen' : '$titel einklappen',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              eingeklappt ? Icons.expand_more : Icons.expand_less,
              color: karto.schriftLeise,
            ),
            onPressed: () => einklappen(!eingeklappt),
          ),
        ),
      ],
    );
  }
}

/// Merkt, ob der Zeiger über einer Kachel steht oder der Fokus in ihr liegt.
///
/// [_BeiBedarf] blendet danach die Kopf-Bedienung (Vergrößern, Einklappen)
/// ein. So zeigt eine Seite mit vielen Kacheln nicht an jeder dauerhaft zwei
/// Bediensymbole.
class _Kachelzeiger extends StatefulWidget {
  const _Kachelzeiger({required this.child});

  final Widget child;

  @override
  State<_Kachelzeiger> createState() => _KachelzeigerState();
}

class _KachelzeigerState extends State<_Kachelzeiger> {
  final ValueNotifier<bool> _aktiv = ValueNotifier<bool>(false);
  bool _zeiger = false;
  bool _fokus = false;

  void _setze({bool? zeiger, bool? fokus}) {
    _zeiger = zeiger ?? _zeiger;
    _fokus = fokus ?? _fokus;
    _aktiv.value = _zeiger || _fokus;
  }

  @override
  void dispose() {
    _aktiv.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _setze(zeiger: true),
      onExit: (_) => _setze(zeiger: false),
      child: Focus(
        // Nimmt selbst keinen Fokus; meldet nur den der Bedienelemente darin.
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (fokus) => _setze(fokus: fokus),
        child: _KachelzeigerScope(notifier: _aktiv, child: widget.child),
      ),
    );
  }
}

class _KachelzeigerScope extends InheritedNotifier<ValueNotifier<bool>> {
  const _KachelzeigerScope({required super.notifier, required super.child});
}

/// Blendet [child] nur ein, solange die Kachel den Zeiger oder Fokus hat.
///
/// Ohne angeschlossene Maus (Touch-Geräte) bleibt [child] immer sichtbar,
/// weil es dort kein Hover gibt. Ausgeblendet bleibt es im Baum und
/// bedienbar: ein Klick auf die Stelle oder der Tabulator erreicht es weiter.
class _BeiBedarf extends StatelessWidget {
  const _BeiBedarf({required this.child, this.immer = false});

  final Widget child;

  /// Hält [child] unabhängig vom Zeiger sichtbar.
  final bool immer;

  @override
  Widget build(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_KachelzeigerScope>();
    final maus = RendererBinding.instance.mouseTracker.mouseIsConnected;
    final sichtbar =
        immer || scope == null || !maus || (scope.notifier?.value ?? true);
    return AnimatedOpacity(
      opacity: sichtbar ? 1 : 0,
      duration: kartoDauer(context, Bewegung.kurz),
      curve: Bewegung.kurve,
      // Auch ausgeblendet für Vorleseprogramme vorhanden.
      alwaysIncludeSemantics: true,
      child: child,
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
    this.onVergroessern,
    this.dicht = true,
    this.groesse = KartoKachelGroesse.normal,
    required super.child,
  });

  const KartoKachelSteuerung._leer({
    required this.groesse,
    required super.child,
  }) : kennung = '',
       eingeklappt = false,
       onEinklappen = null,
       onVergroessern = null,
       dicht = false;

  /// Kennung der Kachel für Schlüssel und Tests.
  final String kennung;

  /// Ob nur der Kopf sichtbar ist.
  final bool eingeklappt;

  /// Schaltet das Einklappen; ohne Rückruf entfällt der Knopf.
  final ValueChanged<bool>? onEinklappen;

  /// Öffnet die Kachel vergrößert; ohne Rückruf bleibt der Name Text.
  final VoidCallback? onVergroessern;

  /// Knapper Innenabstand wie bei [KartoAbschnitt.dicht].
  final bool dicht;

  /// Größenstufe nach der tatsächlichen Breite der Kachel.
  final KartoKachelGroesse groesse;

  /// Größenstufe der umgebenden Kachel; außerhalb einer Kachel
  /// [KartoKachelGroesse.normal].
  ///
  /// Gilt auch in verschachtelten Abschnitten, deren Steuerung leer ist.
  static KartoKachelGroesse groesseVon(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<KartoKachelSteuerung>()
          ?.groesse ??
      KartoKachelGroesse.normal;

  /// Ob die umgebende Kachel [KartoKachelGroesse.weit] ist.
  ///
  /// Der übliche Schalter der Kachelinhalte: mehr Angaben und nebeneinander
  /// statt untereinander. Außerhalb einer Kachel `false`.
  static bool istWeit(BuildContext context) =>
      groesseVon(context) == KartoKachelGroesse.weit;

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
      oldWidget.groesse != groesse ||
      oldWidget.onEinklappen != onEinklappen ||
      oldWidget.onVergroessern != onVergroessern;
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
