import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abenteuer_karten.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abenteuer_sortierung.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_tokens.dart';
import 'package:dsa_heldenverwaltung/ui2/theme/karto_typography.dart';
import 'package:dsa_heldenverwaltung/ui2/widgets/karto_kartenraster.dart';

// Suche über Notizen und Personen aller Abenteuer eines Helden, für das
// Abenteuerblatt und den Abenteuerabschnitt der Spielansicht. Sie liest nur;
// geschrieben wird weiter ausschließlich über `KartoAbenteuerSchreiben`.

/// Treffer eines Abenteuers: Indizes in `notes` und `people`.
///
/// Indizes statt Kopien, damit das Bearbeiten wie in der Kartenansicht den
/// Originalindex gegen den frisch geladenen Stand prüft.
class AbenteuerTreffer {
  /// Erstellt den Treffer für [abenteuer].
  const AbenteuerTreffer({
    required this.abenteuer,
    required this.aktuell,
    required this.notizen,
    required this.personen,
  });

  /// Das Abenteuer, in dem gesucht wurde.
  final HeroAdventureEntry abenteuer;

  /// Ob es das Abenteuer ist, von dem aus gesucht wird.
  final bool aktuell;

  /// Indizes der passenden Notizen in der gewählten Reihenfolge.
  final List<int> notizen;

  /// Indizes der passenden Personen in der gewählten Reihenfolge.
  final List<int> personen;

  /// Anzahl aller Treffer dieses Abenteuers.
  int get anzahl => notizen.length + personen.length;
}

/// Sucht [suchtext] in Notizen und Personen aller [abenteuer].
///
/// Gesucht wird in Titel, Text, Ort und Datum der Notizen sowie in Name,
/// Beschreibung, Ort und Datum der Personen. Groß- und Kleinschreibung und
/// Umlaute spielen keine Rolle; jedes durch Leerzeichen getrennte Wort muss
/// vorkommen. Das Abenteuer [aktuellId] steht immer vorn, die übrigen folgen
/// mit dem zuletzt angelegten zuerst. Abenteuer ohne Treffer fehlen. Ein
/// leerer [suchtext] liefert keine Treffer.
List<AbenteuerTreffer> sucheInAbenteuern({
  required List<HeroAdventureEntry> abenteuer,
  required String aktuellId,
  required String suchtext,
  AbenteuerSortierung sortierung = AbenteuerSortierung.zuletztBearbeitet,
}) {
  final woerter = vergleichsschluessel(suchtext)
      .split(RegExp(r'\s+'))
      .where((wort) => wort.isNotEmpty)
      .toList();
  if (woerter.isEmpty) return const <AbenteuerTreffer>[];

  bool passt(List<String> felder) {
    final heuhaufen = vergleichsschluessel(felder.join('\n'));
    return woerter.every(heuhaufen.contains);
  }

  AbenteuerTreffer? treffer(HeroAdventureEntry eintrag) {
    final notizen = [
      for (final i in sortiereNotizen(eintrag.notes, sortierung))
        if (passt([
          eintrag.notes[i].title,
          eintrag.notes[i].description,
          eintrag.notes[i].ort,
          eintrag.notes[i].datum,
        ]))
          i,
    ];
    final personen = [
      for (final i in sortierePersonen(eintrag.people, sortierung))
        if (passt([
          eintrag.people[i].name,
          eintrag.people[i].description,
          eintrag.people[i].ort,
          eintrag.people[i].datum,
        ]))
          i,
    ];
    if (notizen.isEmpty && personen.isEmpty) return null;
    return AbenteuerTreffer(
      abenteuer: eintrag,
      aktuell: eintrag.id == aktuellId,
      notizen: notizen,
      personen: personen,
    );
  }

  final ergebnis = <AbenteuerTreffer>[];
  // Neueste zuerst: neue Abenteuer werden hinten angehängt.
  for (final eintrag in abenteuer.reversed) {
    final gefunden = treffer(eintrag);
    if (gefunden == null) continue;
    if (gefunden.aktuell) {
      ergebnis.insert(0, gefunden);
    } else {
      ergebnis.add(gefunden);
    }
  }
  return ergebnis;
}

/// Suchfeld für Notizen und Personen.
///
/// Der Zustand (Text, offen oder zu) liegt beim Aufrufer; das Feld meldet nur
/// Änderungen und das Schließen.
class KartoAbenteuerSuchfeld extends StatelessWidget {
  /// Erstellt das Feld.
  const KartoAbenteuerSuchfeld({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSchliessen,
  });

  /// Text des Feldes.
  final TextEditingController controller;

  /// Wird bei jeder Änderung des Textes gerufen.
  final ValueChanged<String> onChanged;

  /// Schließt die Suche und löscht den Text.
  final VoidCallback onSchliessen;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey<String>('karto-abenteuer-suche'),
      controller: controller,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Notizen und Personen aller Abenteuer durchsuchen …',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          key: const ValueKey<String>('karto-abenteuer-suche-schliessen'),
          tooltip: 'Suche schließen',
          onPressed: onSchliessen,
          icon: const Icon(Icons.close),
        ),
      ),
    );
  }
}

/// Schaltet die Suche ein und aus.
class KartoAbenteuerSuchknopf extends StatelessWidget {
  /// Erstellt den Knopf.
  const KartoAbenteuerSuchknopf({
    super.key,
    required this.offen,
    required this.onPressed,
  });

  /// Ob das Suchfeld gerade offen ist.
  final bool offen;

  /// Öffnet oder schließt die Suche.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey<String>('karto-abenteuer-suche-knopf'),
      tooltip: offen ? 'Suche schließen' : 'Notizen und Personen suchen',
      onPressed: onPressed,
      icon: Icon(offen ? Icons.search_off : Icons.search),
    );
  }
}

/// Ergebnisliste der Suche, nach Abenteuern gruppiert.
///
/// Das Abenteuer, von dem aus gesucht wird, steht vorn. Was tippbar ist,
/// entscheidet der Aufrufer über [onNotiz] und [onPerson]: im eigenen
/// Abenteuer bearbeiten, bei anderen deren Blatt öffnen.
class KartoAbenteuerSuchergebnisse extends StatelessWidget {
  /// Erstellt die Liste für [treffer] zum [suchtext].
  const KartoAbenteuerSuchergebnisse({
    super.key,
    required this.treffer,
    required this.suchtext,
    required this.aktuellBeschriftung,
    required this.onNotiz,
    required this.onPerson,
  });

  /// Treffer, aktuelles Abenteuer zuerst.
  final List<AbenteuerTreffer> treffer;

  /// Gesuchter Text, nur für die Meldung ohne Treffer.
  final String suchtext;

  /// Beschriftung des eigenen Abenteuers, etwa `Laufendes Abenteuer`.
  final String aktuellBeschriftung;

  /// Tippen auf eine Notiz: Treffer und Index in `notes`; `null` sperrt.
  final void Function(AbenteuerTreffer treffer, int index)? onNotiz;

  /// Tippen auf eine Person: Treffer und Index in `people`; `null` sperrt.
  final void Function(AbenteuerTreffer treffer, int index)? onPerson;

  @override
  Widget build(BuildContext context) {
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    if (treffer.isEmpty) {
      return Text(
        'Keine Treffer für „${suchtext.trim()}“.',
        key: const ValueKey<String>('karto-abenteuer-suche-leer'),
        style: texte.fliess.copyWith(color: karto.schriftLeise),
      );
    }
    final gesamt = treffer.fold<int>(0, (summe, t) => summe + t.anzahl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$gesamt Treffer in '
          '${treffer.length} ${treffer.length == 1 ? 'Abenteuer' : 'Abenteuern'}',
          key: const ValueKey<String>('karto-abenteuer-suche-anzahl'),
          style: texte.etikett.copyWith(color: karto.schriftLeise),
        ),
        for (final gruppe in treffer) ...[
          const SizedBox(height: Abstand.block),
          _Gruppenkopf(
            titel: gruppe.abenteuer.title.trim().isEmpty
                ? 'Abenteuer ohne Titel'
                : gruppe.abenteuer.title.trim(),
            zusatz: gruppe.aktuell
                ? aktuellBeschriftung
                : (gruppe.abenteuer.status == HeroAdventureStatus.completed
                      ? 'Abgeschlossen'
                      : null),
          ),
          const SizedBox(height: Abstand.normal),
          if (gruppe.personen.isNotEmpty)
            KartoKartenraster(
              mindestbreite: 200,
              kinder: [
                for (final i in gruppe.personen)
                  KartoFigurenkarte(
                    name: gruppe.abenteuer.people[i].name,
                    beschreibung: gruppe.abenteuer.people[i].description,
                    ort: gruppe.abenteuer.people[i].ort,
                    datum: gruppe.abenteuer.people[i].datum,
                    onTap: onPerson == null ? null : () => onPerson!(gruppe, i),
                  ),
              ],
            ),
          if (gruppe.personen.isNotEmpty && gruppe.notizen.isNotEmpty)
            const SizedBox(height: Abstand.normal),
          if (gruppe.notizen.isNotEmpty)
            KartoKartenraster(
              mindestbreite: 260,
              kinder: [
                for (final i in gruppe.notizen)
                  KartoNotizkarte(
                    titel: gruppe.abenteuer.notes[i].title,
                    text: gruppe.abenteuer.notes[i].description,
                    ort: gruppe.abenteuer.notes[i].ort,
                    datum: gruppe.abenteuer.notes[i].datum,
                    onTap: onNotiz == null ? null : () => onNotiz!(gruppe, i),
                  ),
              ],
            ),
        ],
      ],
    );
  }
}

/// Überschrift einer Trefferguppe mit leiser Zusatzmarke.
class _Gruppenkopf extends StatelessWidget {
  const _Gruppenkopf({required this.titel, this.zusatz});

  final String titel;
  final String? zusatz;

  @override
  Widget build(BuildContext context) {
    final texte = Theme.of(context).textTheme;
    return Wrap(
      spacing: Abstand.normal,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(titel, style: texte.abschnitt),
        if (zusatz != null)
          Text(
            zusatz!,
            style: texte.etikett.copyWith(color: context.karto.meer),
          ),
      ],
    );
  }
}
