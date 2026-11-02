/// Bedienelemente des Anordnen-Modus der Spielansicht (SPIEL-07).
///
/// Rein darstellend: sie melden Wünsche an die Spielansicht, die den Entwurf
/// hält und erst bei „Fertig“ schreibt.
library;

import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/hero_spielansicht.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
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

/// Kachel im Anordnen-Modus: Bedienleiste über dem stillgelegten Inhalt.
///
/// Die Kachel ist Ziel für das Ziehen einer anderen Kachel; gezogen wird nur
/// am Griff, damit die Seite sich auf Touchgeräten weiter scrollen lässt.
/// Pfeile verschieben für Tastatur und Bildschirmleser.
class KartoAnordnungskachel extends StatelessWidget {
  /// Bedienbare Fassung von [kachel] mit dem Inhalt [child].
  const KartoAnordnungskachel({
    super.key,
    required this.kachel,
    required this.onAblegen,
    required this.onNachVorn,
    required this.onNachHinten,
    required this.onBreite,
    required this.onAusblenden,
    required this.child,
  });

  /// Wirksame Einstellung der Kachel im Entwurf.
  final KartoSpielkachel kachel;

  /// Eine andere, hierher gezogene Kachel soll diesen Platz einnehmen.
  final ValueChanged<KartoSpielkachelArt> onAblegen;

  /// Eine Stelle nach vorn; `null` an der ersten Stelle.
  final VoidCallback? onNachVorn;

  /// Eine Stelle nach hinten; `null` an der letzten Stelle.
  final VoidCallback? onNachHinten;

  /// Wählt eine der erlaubten Breiten.
  final ValueChanged<SpielkachelBreite> onBreite;

  /// Blendet die Kachel aus; `null`, wenn sie das nicht erlaubt.
  final VoidCallback? onAusblenden;

  /// Inhalt der Kachel; im Modus nicht bedienbar.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final art = kachel.art;
    return DragTarget<KartoSpielkachelArt>(
      onWillAcceptWithDetails: (details) => details.data != art,
      onAcceptWithDetails: (details) => onAblegen(details.data),
      builder: (context, kandidaten, _) {
        final ziel = kandidaten.isNotEmpty;
        return DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kKartoRadius),
            border: Border.all(
              color: ziel ? karto.meer : karto.messing,
              width: ziel ? 2.5 : 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Leiste(
                kachel: kachel,
                onNachVorn: onNachVorn,
                onNachHinten: onNachHinten,
                onBreite: onBreite,
                onAusblenden: onAusblenden,
              ),
              IgnorePointer(
                child: ExcludeFocus(child: Opacity(opacity: 0.6, child: child)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Leiste extends StatelessWidget {
  const _Leiste({
    required this.kachel,
    required this.onNachVorn,
    required this.onNachHinten,
    required this.onBreite,
    required this.onAusblenden,
  });

  final KartoSpielkachel kachel;
  final VoidCallback? onNachVorn;
  final VoidCallback? onNachHinten;
  final ValueChanged<SpielkachelBreite> onBreite;
  final VoidCallback? onAusblenden;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final art = kachel.art;
    final schluessel = 'karto-kachel-${art.id}';
    final griff = Icon(Icons.drag_indicator, color: karto.schriftLeise);
    return Material(
      color: karto.senke,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(kKartoRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Abstand.eng),
        child: Row(
          children: [
            Draggable<KartoSpielkachelArt>(
              key: ValueKey<String>('$schluessel-griff'),
              data: art,
              feedback: Material(
                elevation: 6,
                color: karto.feld,
                borderRadius: BorderRadius.circular(kKartoRadiusKlein),
                child: Padding(
                  padding: const EdgeInsets.all(Abstand.weit),
                  child: Text(art.titel, style: texte.abschnitt),
                ),
              ),
              child: Tooltip(
                message: '${art.titel} ziehen',
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: SizedBox(width: 40, height: 40, child: griff),
                ),
              ),
            ),
            // Der Titel steht schon im Kopf der Kachel darunter.
            const Spacer(),
            IconButton(
              key: ValueKey<String>('$schluessel-vor'),
              tooltip: '${art.titel} nach vorn',
              visualDensity: VisualDensity.compact,
              onPressed: onNachVorn,
              icon: const Icon(Icons.arrow_upward),
            ),
            IconButton(
              key: ValueKey<String>('$schluessel-zurueck'),
              tooltip: '${art.titel} nach hinten',
              visualDensity: VisualDensity.compact,
              onPressed: onNachHinten,
              icon: const Icon(Icons.arrow_downward),
            ),
            if (art.breiten.length > 1)
              PopupMenuButton<SpielkachelBreite>(
                key: ValueKey<String>('$schluessel-breite'),
                tooltip: 'Breite: ${spielkachelBreiteName(kachel.breite)}',
                icon: const Icon(Icons.width_normal_outlined),
                initialValue: kachel.breite,
                onSelected: onBreite,
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
            if (onAusblenden != null)
              IconButton(
                key: ValueKey<String>('$schluessel-ausblenden'),
                tooltip: '${art.titel} ausblenden',
                visualDensity: VisualDensity.compact,
                onPressed: onAusblenden,
                icon: const Icon(Icons.visibility_off_outlined),
              ),
          ],
        ),
      ),
    );
  }
}
