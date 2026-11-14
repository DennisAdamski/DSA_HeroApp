/// Bedienelemente des Anordnen-Modus der Spielansicht (SPIEL-07).
///
/// Rein darstellend: sie melden Wünsche an die Spielansicht, die den Entwurf
/// hält und erst bei „Fertig“ schreibt.
library;

import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/hero_spielansicht.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_kachelgroesse.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_spielraster_ordnung.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';

/// Anzeigename einer Kachelbreite.
String spielkachelBreiteName(SpielkachelBreite breite) => switch (breite) {
  SpielkachelBreite.schmal => 'Schmal',
  SpielkachelBreite.mittel => 'Mittel',
  SpielkachelBreite.voll => 'Ganze Breite',
};

/// Knopf „Anordnen“ im Seitenkopf; während einer Planung gesperrt.
class KartoAnordnenKnopf extends StatelessWidget {
  /// Knopf, der den Anordnen-Modus öffnet.
  const KartoAnordnenKnopf({
    super.key,
    required this.gesperrt,
    required this.onPressed,
  });

  /// Ob eine offene Planung das Anordnen sperrt.
  final bool gesperrt;

  /// Öffnet den Anordnen-Modus.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: gesperrt
          ? 'Während einer Planung lässt sich die Seite nicht anordnen.'
          : 'Kacheln verschieben, Breite wählen, ausblenden',
      child: TextButton.icon(
        key: const ValueKey<String>('karto-spiel-anordnen'),
        onPressed: gesperrt ? null : onPressed,
        icon: const Icon(Icons.dashboard_customize_outlined, size: 18),
        label: const Text('Anordnen'),
      ),
    );
  }
}

/// „Standard“, „Abbrechen“ und „Fertig“ des Anordnen-Modus.
class KartoAnordnenAbschluss extends StatelessWidget {
  /// Abschlussknöpfe; während des Speicherns gesperrt.
  const KartoAnordnenAbschluss({
    super.key,
    required this.speichert,
    required this.onStandard,
    required this.onAbbrechen,
    required this.onFertig,
  });

  /// Ob „Fertig“ gerade schreibt.
  final bool speichert;

  /// Setzt den Entwurf auf die Standardanordnung.
  final VoidCallback onStandard;

  /// Verwirft den Entwurf.
  final VoidCallback onAbbrechen;

  /// Speichert den Entwurf.
  final VoidCallback onFertig;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Abstand.normal,
      runSpacing: Abstand.eng,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton(
          key: const ValueKey<String>('karto-spiel-anordnen-standard'),
          onPressed: speichert ? null : onStandard,
          child: const Text('Standard'),
        ),
        TextButton(
          key: const ValueKey<String>('karto-spiel-anordnen-abbrechen'),
          onPressed: speichert ? null : onAbbrechen,
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const ValueKey<String>('karto-spiel-anordnen-fertig'),
          onPressed: speichert ? null : onFertig,
          child: const Text('Fertig'),
        ),
      ],
    );
  }
}

/// Hinweiszeile des Anordnen-Modus mit den ausgeblendeten Kacheln.
class KartoAnordnenHinweis extends StatelessWidget {
  /// Hinweis samt Knöpfen zum Einblenden von [ausgeblendet].
  const KartoAnordnenHinweis({
    super.key,
    required this.ausgeblendet,
    required this.onEinblenden,
  });

  /// Ausgeblendete Kacheln in Entwurfsreihenfolge.
  final List<KartoSpielkachelArt> ausgeblendet;

  /// Holt eine Kachel zurück auf die Seite.
  final ValueChanged<KartoSpielkachelArt> onEinblenden;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kacheln am Griff ziehen oder mit den Pfeilen verschieben. '
          'Gespeichert wird mit „Fertig“.',
          style: texte.etikett.copyWith(color: karto.schriftLeise),
        ),
        if (ausgeblendet.isNotEmpty) ...[
          const SizedBox(height: Abstand.normal),
          Wrap(
            spacing: Abstand.normal,
            runSpacing: Abstand.eng,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Ausgeblendet:',
                style: texte.marke.copyWith(color: karto.schriftLeise),
              ),
              for (final art in ausgeblendet)
                ActionChip(
                  key: ValueKey<String>('karto-kachel-${art.id}-einblenden'),
                  avatar: const Icon(Icons.add, size: 16),
                  label: Text(art.titel),
                  tooltip: '${art.titel} einblenden',
                  onPressed: () => onEinblenden(art),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Symbol einer Kachel für die kompakte Anordnungskarte.
IconData spielkachelSymbol(KartoSpielkachelArt art) => switch (art) {
  KartoSpielkachelArt.ressourcen => Icons.favorite_outline,
  KartoSpielkachelArt.proben => Icons.casino_outlined,
  KartoSpielkachelArt.eigenschaften => Icons.insights_outlined,
  KartoSpielkachelArt.kampf => Icons.shield_outlined,
  KartoSpielkachelArt.effekte => Icons.auto_awesome_outlined,
  KartoSpielkachelArt.zustand => Icons.monitor_heart_outlined,
  KartoSpielkachelArt.begleiter => Icons.pets_outlined,
  KartoSpielkachelArt.dabei => Icons.backpack_outlined,
  KartoSpielkachelArt.abenteuer => Icons.map_outlined,
  KartoSpielkachelArt.reiseroute => Icons.route_outlined,
  KartoSpielkachelArt.standort => Icons.place_outlined,
  KartoSpielkachelArt.wildnis => Icons.forest_outlined,
  KartoSpielkachelArt.merkmale => Icons.workspace_premium_outlined,
  KartoSpielkachelArt.protokoll => Icons.history,
};

/// Wohin eine gezogene Kachel relativ zur Zielkarte eingefügt wird.
enum KartoEinfuegeSeite {
  /// Vor die Zielkarte.
  davor,

  /// Hinter die Zielkarte.
  danach,
}

/// Kachel im Anordnen-Modus: eine kompakte Karte statt des vollen Inhalts.
///
/// Die Karte steht im selben Raster wie die echte Kachel (gleiche Breite und
/// gleiches Richtgewicht) und zeigt Symbol, Titel, Breite, die Bedienung und
/// darunter die gesperrte Vorschau in echter Höhe. So sieht man, in welcher
/// Spalte die Kachel später steht und wie viel Platz sie einnimmt. Sie ist Ziel für das Ziehen einer anderen
/// Kachel; eine Einfügelinie zeigt vor dem Loslassen, ob davor oder dahinter
/// eingefügt wird. Gezogen wird am Griff (sofort) oder am Titel (nach kurzem
/// Halten), damit die Seite sich auf Touchgeräten weiter scrollen lässt.
/// Pfeile verschieben für Tastatur und Bildschirmleser.
class KartoAnordnungskarte extends StatefulWidget {
  /// Bedienbare Karte für [kachel].
  const KartoAnordnungskarte({
    super.key,
    required this.kachel,
    required this.onAblegen,
    required this.onNachVorn,
    required this.onNachHinten,
    required this.onBreite,
    required this.onAusblenden,
    this.vorschau,
  });

  /// Wirksame Einstellung der Kachel im Entwurf.
  final KartoSpielkachel kachel;

  /// Baut den Inhalt der Kachel für die Vorschau in der Größenstufe, die sie
  /// bei der aktuellen Breite hätte; ohne Rückruf entfällt die Vorschau. Die
  /// Karte sperrt die Bedienung des Inhalts, zeigt ihn aber in voller Höhe:
  /// so sieht man beim Anordnen, wie groß die Kachel später ist. Eine
  /// eingeklappte Kachel zeigt keine Vorschau, weil auch sie später nur aus
  /// ihrem Kopf besteht.
  final Widget Function(KartoKachelGroesse groesse)? vorschau;

  /// Eine andere, hierher gezogene Kachel soll [KartoEinfuegeSeite] dieser
  /// Karte eingefügt werden.
  final void Function(KartoSpielkachelArt gezogen, KartoEinfuegeSeite seite)
  onAblegen;

  /// Eine Stelle nach vorn; `null` an der ersten Stelle.
  final VoidCallback? onNachVorn;

  /// Eine Stelle nach hinten; `null` an der letzten Stelle.
  final VoidCallback? onNachHinten;

  /// Wählt eine der erlaubten Breiten.
  final ValueChanged<SpielkachelBreite> onBreite;

  /// Blendet die Kachel aus; `null`, wenn sie das nicht erlaubt.
  final VoidCallback? onAusblenden;

  /// Unter dieser Kartenbreite liegen Karten untereinander statt nebeneinander;
  /// dann entscheidet die obere oder untere Hälfte über davor oder danach.
  static const double senkrechtBis = 420;

  @override
  State<KartoAnordnungskarte> createState() => _KartoAnordnungskarteState();
}

class _KartoAnordnungskarteState extends State<KartoAnordnungskarte> {
  KartoEinfuegeSeite? _seite;
  bool _zieht = false;

  KartoEinfuegeSeite _seiteFuer(Offset zeiger) {
    final box = context.findRenderObject()! as RenderBox;
    final lokal = box.globalToLocal(zeiger);
    final senkrecht = box.size.width < KartoAnordnungskarte.senkrechtBis;
    final davor = senkrecht
        ? lokal.dy < box.size.height / 2
        : lokal.dx < box.size.width / 2;
    return davor ? KartoEinfuegeSeite.davor : KartoEinfuegeSeite.danach;
  }

  void _setzeSeite(KartoEinfuegeSeite? seite) {
    if (seite != _seite) setState(() => _seite = seite);
  }

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final art = widget.kachel.art;
    return DragTarget<KartoSpielkachelArt>(
      onWillAcceptWithDetails: (details) => details.data != art,
      onMove: (details) => _setzeSeite(_seiteFuer(details.offset)),
      onLeave: (_) => _setzeSeite(null),
      onAcceptWithDetails: (details) {
        final seite = _seiteFuer(details.offset);
        _setzeSeite(null);
        widget.onAblegen(details.data, seite);
      },
      builder: (context, kandidaten, _) {
        final ziel = kandidaten.isNotEmpty;
        return LayoutBuilder(
          builder: (context, constraints) {
            final senkrecht =
                constraints.maxWidth < KartoAnordnungskarte.senkrechtBis;
            return Opacity(
              opacity: _zieht ? 0.35 : 1,
              child: Stack(
                // Reicht die Mindesthöhe des Lückenschlusses an die Karte.
                fit: StackFit.passthrough,
                children: [
                  _Karte(
                    karte: widget,
                    ziel: ziel,
                    karto: karto,
                    kachelbreite: constraints.maxWidth,
                    onZieht: (zieht) => setState(() => _zieht = zieht),
                  ),
                  if (ziel && _seite != null)
                    _Einfuegelinie(
                      seite: _seite!,
                      senkrecht: senkrecht,
                      farbe: karto.meer,
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Karte extends StatelessWidget {
  const _Karte({
    required this.karte,
    required this.ziel,
    required this.karto,
    required this.kachelbreite,
    required this.onZieht,
  });

  final KartoAnordnungskarte karte;
  final bool ziel;
  final KartoTheme karto;

  /// Breite, die die Kachel im Raster tatsächlich hat.
  final double kachelbreite;
  final ValueChanged<bool> onZieht;

  @override
  Widget build(BuildContext context) {
    final widget = karte;
    final kachel = widget.kachel;
    final art = kachel.art;
    final texte = Theme.of(context).textTheme;
    final schluessel = 'karto-kachel-${art.id}';

    Widget feedback() => Material(
      elevation: 6,
      color: karto.feld,
      borderRadius: BorderRadius.circular(kKartoRadiusKlein),
      child: Padding(
        padding: const EdgeInsets.all(Abstand.weit),
        child: Text(art.titel, style: texte.abschnitt),
      ),
    );

    void beginn() => onZieht(true);
    void ende() => onZieht(false);

    final griff = Draggable<KartoSpielkachelArt>(
      key: ValueKey<String>('$schluessel-griff'),
      data: art,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: feedback(),
      onDragStarted: beginn,
      onDragEnd: (_) => ende(),
      child: Tooltip(
        message: '${art.titel} ziehen',
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(Icons.drag_indicator, color: karto.schriftLeise),
          ),
        ),
      ),
    );

    final titel = LongPressDraggable<KartoSpielkachelArt>(
      key: ValueKey<String>('$schluessel-titel'),
      data: art,
      delay: const Duration(milliseconds: 200),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: feedback(),
      onDragStarted: beginn,
      onDragEnd: (_) => ende(),
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            Icon(spielkachelSymbol(art), size: 18, color: karto.messing),
            const SizedBox(width: Abstand.normal),
            Expanded(
              child: Text(
                art.titel,
                style: texte.abschnitt,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    return Material(
      color: karto.feld,
      borderRadius: BorderRadius.circular(kKartoRadius),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kKartoRadius),
          border: Border.all(
            color: ziel ? karto.meer : karto.messing,
            width: ziel ? 2.5 : 1.5,
          ),
        ),
        child: ConstrainedBox(
          // Ohne Vorschau Höhe nach Richtgewicht, damit das Raster seine
          // Spalten zeigt; mit Vorschau bestimmt sie die Höhe.
          constraints: BoxConstraints(
            minHeight: widget.vorschau == null ? 88 + art.gewicht * 0.25 : 0,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Abstand.eng),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    griff,
                    Expanded(child: titel),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: Abstand.normal),
                        child: Text(
                          kachel.eingeklappt
                              ? '${spielkachelBreiteName(kachel.breite)} · '
                                    'Eingeklappt'
                              : spielkachelBreiteName(kachel.breite),
                          key: ValueKey<String>('$schluessel-breite-name'),
                          style: texte.etikett.copyWith(
                            color: karto.schriftLeise,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    IconButton(
                      key: ValueKey<String>('$schluessel-vor'),
                      tooltip: '${art.titel} nach vorn',
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.onNachVorn,
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      key: ValueKey<String>('$schluessel-zurueck'),
                      tooltip: '${art.titel} nach hinten',
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.onNachHinten,
                      icon: const Icon(Icons.arrow_downward),
                    ),
                    if (art.breiten.length > 1)
                      PopupMenuButton<SpielkachelBreite>(
                        key: ValueKey<String>('$schluessel-breite'),
                        tooltip:
                            'Breite: ${spielkachelBreiteName(kachel.breite)}',
                        icon: const Icon(Icons.width_normal_outlined),
                        initialValue: kachel.breite,
                        onSelected: widget.onBreite,
                        itemBuilder: (context) => [
                          for (final breite in art.breiten)
                            CheckedPopupMenuItem<SpielkachelBreite>(
                              key: ValueKey<String>(
                                '$schluessel-breite-${breite.name}',
                              ),
                              value: breite,
                              checked: breite == kachel.breite,
                              child: Text(spielkachelBreiteName(breite)),
                            ),
                        ],
                      ),
                    if (widget.onAusblenden != null)
                      IconButton(
                        key: ValueKey<String>('$schluessel-ausblenden'),
                        tooltip: '${art.titel} ausblenden',
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.onAusblenden,
                        icon: const Icon(Icons.visibility_off_outlined),
                      ),
                  ],
                ),
                if (widget.vorschau != null && !kachel.eingeklappt)
                  _Vorschau(
                    schluessel: schluessel,
                    karto: karto,
                    groesse: KartoKachelGroesse.fuerBreite(kachelbreite),
                    kachelbreite: kachelbreite,
                    inhalt: widget.vorschau!,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _groessenName(KartoKachelGroesse groesse) => switch (groesse) {
  KartoKachelGroesse.kompakt => 'Kompakt',
  KartoKachelGroesse.normal => 'Normal',
  KartoKachelGroesse.weit => 'Weit',
};

/// Gesperrte Vorschau des Kachelinhalts in der Größenstufe der Karte.
///
/// Der Inhalt wird mit der echten Kachelbreite und in seiner echten Höhe
/// ausgelegt, ist aber weder bedienbar noch fokussierbar noch für
/// Bildschirmleser sichtbar.
class _Vorschau extends StatelessWidget {
  const _Vorschau({
    required this.schluessel,
    required this.karto,
    required this.groesse,
    required this.kachelbreite,
    required this.inhalt,
  });

  final String schluessel;
  final KartoTheme karto;
  final KartoKachelGroesse groesse;
  final double kachelbreite;
  final Widget Function(KartoKachelGroesse groesse) inhalt;

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Abstand.eng),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Abstand.normal,
              0,
              Abstand.normal,
              Abstand.eng,
            ),
            child: Text(
              'Vorschau: ${_groessenName(groesse)} · '
              '${kachelbreite.round()} dp',
              key: ValueKey<String>('$schluessel-vorschau-stufe'),
              style: texte.etikett.copyWith(color: karto.schriftLeise),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(kKartoRadiusKlein),
            child: Material(
              color: karto.blatt,
              child: KeyedSubtree(
                key: ValueKey<String>('$schluessel-vorschau'),
                child: ExcludeSemantics(
                  child: ExcludeFocus(
                    child: IgnorePointer(child: inhalt(groesse)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Linie an der Kante der Zielkarte, die zeigt, wo eingefügt wird.
class _Einfuegelinie extends StatelessWidget {
  const _Einfuegelinie({
    required this.seite,
    required this.senkrecht,
    required this.farbe,
  });

  final KartoEinfuegeSeite seite;
  final bool senkrecht;
  final Color farbe;

  @override
  Widget build(BuildContext context) {
    final davor = seite == KartoEinfuegeSeite.davor;
    const dicke = 5.0;
    return Positioned(
      key: ValueKey<String>('karto-einfuegelinie-${seite.name}'),
      left: senkrecht || davor ? 0 : null,
      right: senkrecht || !davor ? 0 : null,
      top: senkrecht && davor || !senkrecht ? 0 : null,
      bottom: senkrecht && !davor || !senkrecht ? 0 : null,
      width: senkrecht ? null : dicke,
      height: senkrecht ? dicke : null,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: farbe,
            borderRadius: BorderRadius.circular(dicke),
          ),
        ),
      ),
    );
  }
}
