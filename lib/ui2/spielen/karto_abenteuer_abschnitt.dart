import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abenteuer_karten.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abenteuer_schreiben.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abenteuer_sortierung.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abschnitt.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_info_chip.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_laufendes_abenteuer.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_standort.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_kartenraster.dart';

/// Abenteuer am Spieltisch: alles Wichtige an einer Stelle.
///
/// Der Abschnitt verschmilzt, was vorher auf Seitenkopf, Standortabschnitt und
/// Abenteuerblatt verteilt war: Titel, aventurisches Datum, Standort und
/// Kurzbeschreibung stehen oben, darunter die Schnell-Erfassung und die
/// Karten für Personen und Notizen. Alles lässt sich **direkt hier** ändern;
/// das Vollblatt ([onOeffnen]) bleibt für die ganze Liste.
///
/// Der Standort hängt am Zustand des Helden, nicht am Abenteuer. Der Abschnitt
/// steht deshalb auch ohne laufendes Abenteuer ([abenteuer] ist `null`) und
/// zeigt dann nur den Standort.
///
/// Geschrieben wird über [KartoAbenteuerSchreiben]: frisch laden, nur dieses
/// Abenteuer ändern. Während einer Planung ist alles schreibgeschützt.
class KartoAbenteuerAbschnitt extends ConsumerStatefulWidget {
  /// Erstellt den Abschnitt für das laufende [abenteuer] (oder keines).
  const KartoAbenteuerAbschnitt({
    super.key,
    required this.heroId,
    required this.abenteuer,
    required this.standort,
    required this.sortierung,
    required this.onStandortSpeichern,
    required this.onOeffnen,
    this.oeffneLink,
  });

  /// ID im gemeinsam genutzten Heldenspeicher.
  final String heroId;

  /// Das laufende Abenteuer, oder `null`.
  final HeroAdventureEntry? abenteuer;

  /// Gespeicherter Standort des Helden; leer, solange keiner festgehalten ist.
  final String standort;

  /// Reihenfolge von Personen und Notizen.
  final AbenteuerSortierung sortierung;

  /// Speichert den Standort über den Zustandsweg der Brücke.
  final Future<void> Function(String standort) onStandortSpeichern;

  /// Öffnet das Vollblatt des Abenteuers.
  final VoidCallback onOeffnen;

  /// Öffnet den Kartenlink; `null` nimmt den Systembrowser. In Tests ersetzbar.
  final KartoLinkOeffner? oeffneLink;

  /// Höchstzahl gezeigter Personen, solange nicht alle aufgeklappt sind.
  static const int maxPersonen = 3;

  /// Höchstzahl gezeigter Notizen, solange nicht alle aufgeklappt sind.
  static const int maxNotizen = 4;

  /// Ab dieser Länge bietet die Kurzbeschreibung „Mehr“ an.
  static const int _langerText = 150;

  @override
  ConsumerState<KartoAbenteuerAbschnitt> createState() =>
      _KartoAbenteuerAbschnittState();
}

class _KartoAbenteuerAbschnittState
    extends ConsumerState<KartoAbenteuerAbschnitt>
    with KartoAbenteuerSchreiben<KartoAbenteuerAbschnitt> {
  final TextEditingController _schnell = TextEditingController();
  bool _alleZeigen = false;
  bool _textOffen = false;

  @override
  String get heroId => widget.heroId;

  @override
  String get abenteuerId => widget.abenteuer?.id ?? '';

  @override
  void dispose() {
    _schnell.dispose();
    super.dispose();
  }

  KartoStandortZeile _standort() {
    final link = widget.oeffneLink;
    return link == null
        ? KartoStandortZeile(
            standort: widget.standort,
            onSpeichern: widget.onStandortSpeichern,
          )
        : KartoStandortZeile(
            standort: widget.standort,
            onSpeichern: widget.onStandortSpeichern,
            oeffneLink: link,
          );
  }

  @override
  Widget build(BuildContext context) {
    final abenteuer = widget.abenteuer;
    if (abenteuer == null) return _ohneAbenteuer(context);

    final gesperrt = this.gesperrt;
    final bearbeitbar = !gesperrt && !schreibt;
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final personen = abenteuer.people;
    final notizen = abenteuer.notes;
    final personenfolge = sortierePersonen(personen, widget.sortierung);
    final notizfolge = sortiereNotizen(notizen, widget.sortierung);
    final personenSicht = _alleZeigen
        ? personenfolge.toList()
        : personenfolge.take(KartoAbenteuerAbschnitt.maxPersonen).toList();
    final notizenSicht = _alleZeigen
        ? notizfolge.toList()
        : notizfolge.take(KartoAbenteuerAbschnitt.maxNotizen).toList();
    final verborgen =
        (personen.length - personenSicht.length) +
        (notizen.length - notizenSicht.length);
    final datum = abenteuerDatum(abenteuer);

    return KartoAbschnitt(
      titel: abenteuer.title.trim(),
      symbol: Icons.explore_outlined,
      akzent: KartoAkzent.messing,
      aktion: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Abstand.knapp,
        children: [
          const KartoAbenteuerSortierwahl(),
          TextButton(
            key: const ValueKey<String>('karto-spiel-abenteuer-oeffnen'),
            onPressed: widget.onOeffnen,
            child: const Text('Öffnen'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: Abstand.normal,
            runSpacing: Abstand.knapp,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              KartoInfoChip(
                key: const ValueKey<String>('karto-spiel-abenteuer-datum'),
                symbol: Icons.event_outlined,
                text:
                    datum ??
                    (gesperrt ? 'Kein Datum erfasst' : 'Datum festlegen'),
                leer: datum == null,
                onTap: bearbeitbar ? () => datumAendern(abenteuer) : null,
              ),
              _standort(),
            ],
          ),
          const SizedBox(height: Abstand.weit),
          _kurzbeschreibung(context, abenteuer, bearbeitbar: bearbeitbar),
          if (gesperrt) ...[
            const SizedBox(height: Abstand.weit),
            _Hinweis(
              key: const ValueKey<String>('karto-spiel-abenteuer-gesperrt'),
              symbol: Icons.lock_outline,
              text:
                  'Während eine Entwicklung geplant wird, ist das Abenteuer '
                  'schreibgeschützt.',
              farbe: karto.schriftLeise,
            ),
          ] else ...[
            const SizedBox(height: Abstand.weit),
            _schnellErfassung(bearbeitbar: bearbeitbar),
          ],
          if (fehler != null) ...[
            const SizedBox(height: Abstand.weit),
            _Hinweis(
              symbol: Icons.error_outline,
              text: fehler!,
              farbe: karto.siegel,
            ),
          ],
          if (personen.isEmpty && notizen.isEmpty) ...[
            const SizedBox(height: Abstand.weit),
            Text(
              'Noch keine Notizen oder Personen.',
              style: texte.fliess.copyWith(color: karto.schriftLeise),
            ),
          ],
          if (personen.isNotEmpty) ...[
            const SizedBox(height: Abstand.block),
            _Zwischenzeile(titel: 'Personen', anzahl: personen.length),
            const SizedBox(height: Abstand.normal),
            KartoKartenraster(
              mindestbreite: 200,
              kinder: [
                for (final i in personenSicht)
                  KartoFigurenkarte(
                    name: personen[i].name,
                    beschreibung: personen[i].description,
                    onTap: bearbeitbar
                        ? () => personBearbeiten(personen[i])
                        : null,
                  ),
              ],
            ),
          ],
          if (notizen.isNotEmpty) ...[
            const SizedBox(height: Abstand.block),
            _Zwischenzeile(titel: 'Notizen', anzahl: notizen.length),
            const SizedBox(height: Abstand.normal),
            KartoKartenraster(
              mindestbreite: 260,
              kinder: [
                for (final i in notizenSicht)
                  KartoNotizkarte(
                    titel: notizen[i].title,
                    text: notizen[i].description,
                    onTap: bearbeitbar
                        ? () => notizBearbeiten(i, notizen[i])
                        : null,
                  ),
              ],
            ),
          ],
          if (verborgen > 0 || (_alleZeigen && _gibtMehr(abenteuer))) ...[
            const SizedBox(height: Abstand.normal),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey<String>('karto-spiel-abenteuer-alle'),
                onPressed: () => setState(() => _alleZeigen = !_alleZeigen),
                child: Text(
                  _alleZeigen ? 'Weniger zeigen' : 'Alle zeigen (+$verborgen)',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Ob es überhaupt mehr gibt, als im eingeklappten Zustand sichtbar wäre —
  // sonst bliebe „Weniger zeigen“ ohne Wirkung stehen.
  bool _gibtMehr(HeroAdventureEntry abenteuer) =>
      abenteuer.people.length > KartoAbenteuerAbschnitt.maxPersonen ||
      abenteuer.notes.length > KartoAbenteuerAbschnitt.maxNotizen;

  // Ohne laufendes Abenteuer bleibt nur der Standort; er hängt am Zustand.
  Widget _ohneAbenteuer(BuildContext context) {
    final karto = context.karto;
    return KartoAbschnitt(
      titel: 'Abenteuer',
      symbol: Icons.explore_outlined,
      akzent: KartoAkzent.messing,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(alignment: Alignment.centerLeft, child: _standort()),
          const SizedBox(height: Abstand.weit),
          Text(
            'Kein laufendes Abenteuer. Lege in der Verwaltung eines mit Titel '
            'an und setze es auf „laufend“, dann stehen hier Datum, Notizen '
            'und Personen bereit.',
            key: const ValueKey<String>('karto-spiel-abenteuer-leer'),
            style: Theme.of(context).textTheme.fliess
                .copyWith(color: karto.schriftLeise),
          ),
        ],
      ),
    );
  }

  Widget _kurzbeschreibung(
    BuildContext context,
    HeroAdventureEntry abenteuer, {
    required bool bearbeitbar,
  }) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final inhalt = abenteuer.summary.trim();
    final lang =
        inhalt.length > KartoAbenteuerAbschnitt._langerText ||
        '\n'.allMatches(inhalt).length >= 3;
    final anzeige = inhalt.isNotEmpty
        ? inhalt
        : (bearbeitbar
              ? 'Kurzbeschreibung ergänzen'
              : 'Noch keine Kurzbeschreibung.');
    final absatz = Text(
      anzeige,
      key: const ValueKey<String>('karto-spiel-abenteuer-zusammenfassung'),
      maxLines: _textOffen ? null : 3,
      overflow: _textOffen ? TextOverflow.visible : TextOverflow.ellipsis,
      style: inhalt.isEmpty
          ? texte.fliess.copyWith(color: karto.schriftLeise)
          : texte.fliess,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: bearbeitbar ? () => zusammenfassungAendern(abenteuer) : null,
            borderRadius: BorderRadius.circular(kKartoRadiusKlein),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: absatz),
                if (bearbeitbar) ...[
                  const SizedBox(width: Abstand.normal),
                  Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: karto.schriftLeise,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (lang)
          TextButton(
            key: const ValueKey<String>('karto-spiel-abenteuer-mehr'),
            onPressed: () => setState(() => _textOffen = !_textOffen),
            child: Text(_textOffen ? 'Weniger' : 'Mehr'),
          ),
      ],
    );
  }

  // Eine Zeile für das, was am Tisch gerade auffällt; ausführlich geht über
  // die Knöpfe daneben. Enter speichert und behält den Fokus für die nächste.
  Widget _schnellErfassung({required bool bearbeitbar}) {
    Future<void> absenden(String text) async {
      if (!bearbeitbar || text.trim().isEmpty) return;
      _schnell.clear();
      await notizSchnell(text);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey<String>('karto-spiel-abenteuer-schnellnotiz'),
            controller: _schnell,
            enabled: bearbeitbar,
            textInputAction: TextInputAction.send,
            onSubmitted: absenden,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Notiz festhalten …',
              prefixIcon: const Icon(Icons.edit_note_outlined),
              suffixIcon: IconButton(
                key: const ValueKey<String>(
                  'karto-spiel-abenteuer-schnellnotiz-senden',
                ),
                tooltip: 'Notiz speichern',
                onPressed: bearbeitbar ? () => absenden(_schnell.text) : null,
                icon: const Icon(Icons.send_outlined),
              ),
            ),
          ),
        ),
        IconButton(
          key: const ValueKey<String>('karto-spiel-abenteuer-notiz-neu'),
          tooltip: 'Notiz ausführlich anlegen',
          onPressed: bearbeitbar ? notizAnlegen : null,
          icon: const Icon(Icons.note_add_outlined),
        ),
        IconButton(
          key: const ValueKey<String>('karto-spiel-abenteuer-person-neu'),
          tooltip: 'Person hinzufügen',
          onPressed: bearbeitbar ? personAnlegen : null,
          icon: const Icon(Icons.person_add_alt),
        ),
      ],
    );
  }
}

/// Leise Zwischenzeile mit Gesamtanzahl.
class _Zwischenzeile extends StatelessWidget {
  const _Zwischenzeile({required this.titel, required this.anzahl});

  final String titel;
  final int anzahl;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$titel · $anzahl',
      style: Theme.of(context).textTheme.etikett
          .copyWith(color: context.karto.schriftLeise),
    );
  }
}

/// Meldung mit Symbol, etwa Schreibschutz oder Fehler.
class _Hinweis extends StatelessWidget {
  const _Hinweis({
    super.key,
    required this.symbol,
    required this.text,
    required this.farbe,
  });

  final IconData symbol;
  final String text;
  final Color farbe;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(symbol, size: 18, color: farbe),
        const SizedBox(width: Abstand.normal),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.etikett.copyWith(color: farbe),
          ),
        ),
      ],
    );
  }
}
