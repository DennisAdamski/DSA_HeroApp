import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abenteuer_karten.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abenteuer_schreiben.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abenteuer_sortierung.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_kartenraster.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_laufendes_abenteuer.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_flaeche.dart';

/// Öffnet das Abenteuerblatt für ein Abenteuer des Helden.
///
/// Das Blatt ist modal; solange es offen ist, entsteht in der Verwaltung kein
/// neuer Entwurf, der seine Änderungen später überschreiben könnte.
Future<void> zeigeAbenteuerblatt({
  required BuildContext context,
  required String heroId,
  required String abenteuerId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    // Das Blatt ist eine eigene Seite: Grund `blatt`, Karten darauf `feld`.
    backgroundColor: context.karto.blatt,
    constraints: const BoxConstraints(maxWidth: Breite.gross),
    // Kartograph kennt nur zwei Radien; Materials 28 waere eine dritte Stufe.
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(kKartoRadius)),
    ),
    builder: (context) => FractionallySizedBox(
      heightFactor: .9,
      child: KartoAbenteuerblatt(heroId: heroId, abenteuerId: abenteuerId),
    ),
  );
}

/// Abenteuer am Spieltisch: Datum, Zusammenfassung, Notizen und Personen.
///
/// UI2-eigen, weil der Verwaltungseditor beim Speichern seinen **gesamten**
/// Entwurf (Notizen, Kontakte, alle Abenteuer) über den Helden legt. Das Blatt
/// schreibt dagegen gezielt dieses eine Abenteuer über
/// `HeroActions.updateHero` und [ersetzeAbenteuer]. Abschluss, Belohnungen und
/// Beute bleiben der Verwaltung vorbehalten.
///
/// Gespeichert wird im Blatt selbst, nicht über die Laufzeitaktion des
/// Workspace: das Öffnen läuft bereits in deren Re-Entrancy-Guard, jede
/// weitere Aktion darin würde still verworfen.
class KartoAbenteuerblatt extends ConsumerStatefulWidget {
  /// Bindet das Blatt an ein Abenteuer eines Helden.
  const KartoAbenteuerblatt({
    super.key,
    required this.heroId,
    required this.abenteuerId,
  });

  /// ID im gemeinsam genutzten Heldenspeicher.
  final String heroId;

  /// Stabile ID des gezeigten Abenteuers.
  final String abenteuerId;

  @override
  ConsumerState<KartoAbenteuerblatt> createState() =>
      _KartoAbenteuerblattState();
}

class _KartoAbenteuerblattState extends ConsumerState<KartoAbenteuerblatt>
    with KartoAbenteuerSchreiben<KartoAbenteuerblatt> {
  @override
  String get heroId => widget.heroId;

  @override
  String get abenteuerId => widget.abenteuerId;

  @override
  Widget build(BuildContext context) {
    final berechnet = ref.watch(heroComputedProvider(widget.heroId));
    final werte = berechnet.asData?.value;
    if (werte == null) {
      return berechnet.hasError
          ? _meldung('Der Held konnte nicht geladen werden.')
          : const Center(child: CircularProgressIndicator());
    }
    HeroAdventureEntry? abenteuer;
    for (final eintrag in werte.hero.adventures) {
      if (eintrag.id == widget.abenteuerId) abenteuer = eintrag;
    }
    if (abenteuer == null) {
      return _meldung('Dieses Abenteuer gibt es nicht mehr.');
    }

    // Jede Heldenänderung bräche den Inhalts-Hash einer offenen Runde, und
    // deren Übernahme scheiterte dann. Lesen bleibt möglich.
    final gesperrt = this.gesperrt;
    final bearbeitbar = !gesperrt && !schreibt;
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final aktuell = abenteuer;
    final notizen = aktuell.notes;
    final personen = aktuell.people;
    final sortierung = ref.watch(abenteuerSortierungProvider);
    final notizfolge = sortiereNotizen(notizen, sortierung);
    final personenfolge = sortierePersonen(personen, sortierung);

    return LayoutBuilder(
      builder: (context, constraints) {
        final rand = constraints.maxWidth < Breite.klein
            ? Abstand.block
            : Abstand.bahn;
        return ListView(
          padding: EdgeInsets.fromLTRB(rand, 0, rand, Abstand.bahn),
          children: [
            Text(aktuell.title.trim(), style: texte.titel),
            const SizedBox(height: Abstand.normal),
            Align(
              alignment: Alignment.centerLeft,
              child: _Datumsmarke(
                datum: abenteuerDatum(aktuell),
                onTap: gesperrt
                    ? null
                    : () {
                        if (bearbeitbar) datumAendern(aktuell);
                      },
              ),
            ),
            const SizedBox(height: Abstand.block),
            _Zusammenfassung(
              text: aktuell.summary,
              onTap: gesperrt
                  ? null
                  : () {
                      if (bearbeitbar) zusammenfassungAendern(aktuell);
                    },
            ),
            if (gesperrt) ...[
              const SizedBox(height: Abstand.block),
              _Hinweiszeile(
                key: const ValueKey<String>('karto-abenteuer-gesperrt'),
                symbol: Icons.lock_outline,
                text:
                    'Während eine Entwicklung geplant wird, ist das Abenteuer '
                    'schreibgeschützt.',
                farbe: karto.schriftLeise,
              ),
            ],
            if (fehler != null) ...[
              const SizedBox(height: Abstand.block),
              _Hinweiszeile(
                symbol: Icons.error_outline,
                text: fehler!,
                farbe: karto.siegel,
              ),
            ],
            const SizedBox(height: Abstand.bahn),
            const Align(
              alignment: Alignment.centerLeft,
              child: KartoAbenteuerSortierwahl(),
            ),
            const SizedBox(height: Abstand.normal),
            _Kopfzeile(titel: 'Personen', anzahl: personen.length),
            const SizedBox(height: Abstand.weit),
            if (personen.isEmpty && gesperrt)
              _leer('Noch keine Personen.')
            else
              KartoKartenraster(
                mindestbreite: 220,
                kinder: [
                  for (final person in [
                    for (final i in personenfolge) personen[i],
                  ])
                    KartoFigurenkarte(
                      name: person.name,
                      beschreibung: person.description,
                      onTap: bearbeitbar
                          ? () => personBearbeiten(person)
                          : null,
                    ),
                  if (!gesperrt)
                    KartoFreieKachel(
                      key: const ValueKey<String>('karto-abenteuer-person-neu'),
                      beschriftung: 'Person hinzufügen',
                      symbol: Icons.person_add_alt,
                      onTap: bearbeitbar ? personAnlegen : null,
                    ),
                ],
              ),
            const SizedBox(height: Abstand.rand),
            _Kopfzeile(titel: 'Notizen', anzahl: notizen.length),
            const SizedBox(height: Abstand.weit),
            if (notizen.isEmpty && gesperrt)
              _leer('Noch keine Notizen.')
            else
              KartoKartenraster(
                mindestbreite: 300,
                kinder: [
                  for (final i in notizfolge)
                    KartoNotizkarte(
                      titel: notizen[i].title,
                      text: notizen[i].description,
                      onTap: bearbeitbar
                          ? () => notizBearbeiten(i, notizen[i])
                          : null,
                    ),
                  if (!gesperrt)
                    KartoFreieKachel(
                      key: const ValueKey<String>('karto-abenteuer-notiz-neu'),
                      beschriftung: 'Notiz hinzufügen',
                      symbol: Icons.note_add_outlined,
                      onTap: bearbeitbar ? notizAnlegen : null,
                    ),
                ],
              ),
            const SizedBox(height: Abstand.rand),
            Text(
              'Abschluss und Belohnungen pflegst du in der Verwaltung.',
              style: texte.etikett.copyWith(color: karto.schriftLeise),
            ),
          ],
        );
      },
    );
  }

  Widget _leer(String text) => Text(
    text,
    style: Theme.of(context).textTheme.fliess
        .copyWith(color: context.karto.schriftLeise),
  );

  Widget _meldung(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Abstand.bahn),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

/// Abschnittsueberschrift des Blatts mit leiser Anzahl.
///
/// Keine Flaeche drumherum: die Karten darunter tragen bereits die Tiefe, ein
/// zusaetzlicher Kasten ergaebe Karten in Kaesten.
class _Kopfzeile extends StatelessWidget {
  const _Kopfzeile({required this.titel, required this.anzahl});

  final String titel;
  final int anzahl;

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // Flexible: bei grosser Systemschrift bricht der Titel um, statt die
        // Anzahl aus dem Blatt zu schieben.
        Flexible(child: Text(titel, style: texte.abschnitt)),
        if (anzahl > 0) ...[
          const SizedBox(width: Abstand.normal),
          Text('$anzahl', style: texte.etikett),
        ],
      ],
    );
  }
}

/// Aventurisches Datum als kleine Marke; antippbar, wenn bearbeitbar.
class _Datumsmarke extends StatelessWidget {
  const _Datumsmarke({required this.datum, this.onTap});

  final String? datum;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final leer = datum == null;
    final beschriftung =
        datum ?? (onTap == null ? 'Kein Datum erfasst' : 'Datum festlegen');
    final inhalt = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Abstand.normal,
        vertical: Abstand.knapp,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_outlined, size: 16, color: karto.schriftLeise),
          const SizedBox(width: Abstand.knapp),
          Flexible(
            child: Text(
              beschriftung,
              style: texte.etikett.copyWith(
                color: leer && onTap != null ? karto.meer : karto.schrift,
              ),
            ),
          ),
        ],
      ),
    );
    return KartoFlaeche(
      stufe: KartoFlaechenstufe.senke,
      klein: true,
      child: onTap == null
          ? inhalt
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: const ValueKey<String>('karto-abenteuer-datum'),
                onTap: onTap,
                borderRadius: BorderRadius.circular(kKartoRadiusKlein),
                child: inhalt,
              ),
            ),
    );
  }
}

/// Zusammenfassung als Lesetext; antippbar mit leisem Stift als Hinweis.
class _Zusammenfassung extends StatelessWidget {
  const _Zusammenfassung({required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final inhalt = text.trim();
    final String anzeige;
    if (inhalt.isNotEmpty) {
      anzeige = inhalt;
    } else if (onTap == null) {
      anzeige = 'Noch keine Zusammenfassung.';
    } else {
      anzeige = 'Noch keine Zusammenfassung. Antippen zum Ergänzen.';
    }
    final absatz = Text(
      anzeige,
      style: inhalt.isEmpty
          ? texte.fliess.copyWith(color: karto.schriftLeise)
          : texte.fliess,
    );
    if (onTap == null) return absatz;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: const ValueKey<String>('karto-abenteuer-zusammenfassung'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(kKartoRadiusKlein),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: Breite.lesespalte),
                child: absatz,
              ),
            ),
            const SizedBox(width: Abstand.normal),
            Icon(Icons.edit_outlined, size: 18, color: karto.schriftLeise),
          ],
        ),
      ),
    );
  }
}

/// Meldung mit Symbol, etwa Schreibschutz oder Fehler.
class _Hinweiszeile extends StatelessWidget {
  const _Hinweiszeile({
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
    return KartoFlaeche(
      stufe: KartoFlaechenstufe.senke,
      innen: const EdgeInsets.all(Abstand.weit),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(symbol, size: 18, color: farbe),
          const SizedBox(width: Abstand.normal),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.fliess.copyWith(color: farbe),
            ),
          ),
        ],
      ),
    );
  }
}
