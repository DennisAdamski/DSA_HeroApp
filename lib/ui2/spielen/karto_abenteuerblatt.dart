import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:dsa_heldenverwaltung/domain/aventurian_date.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/state/advancement_providers.dart';
import 'package:dsa_heldenverwaltung/state/hero_providers.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abenteuer_karten.dart';
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

class _KartoAbenteuerblattState extends ConsumerState<KartoAbenteuerblatt> {
  bool _schreibt = false;
  String? _fehler;

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
    final gesperrt =
        ref.watch(advancementSessionProvider(widget.heroId)) != null;
    final bearbeitbar = !gesperrt && !_schreibt;
    final karto = context.karto;
    final texte = Theme.of(context).textTheme;
    final aktuell = abenteuer;
    final notizen = aktuell.notes;
    final personen = aktuell.people;

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
                        if (bearbeitbar) _datumAendern(aktuell);
                      },
              ),
            ),
            const SizedBox(height: Abstand.block),
            _Zusammenfassung(
              text: aktuell.summary,
              onTap: gesperrt
                  ? null
                  : () {
                      if (bearbeitbar) _zusammenfassungAendern(aktuell);
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
            if (_fehler != null) ...[
              const SizedBox(height: Abstand.block),
              _Hinweiszeile(
                symbol: Icons.error_outline,
                text: _fehler!,
                farbe: karto.siegel,
              ),
            ],
            const SizedBox(height: Abstand.rand),
            _Kopfzeile(titel: 'Personen', anzahl: personen.length),
            const SizedBox(height: Abstand.weit),
            if (personen.isEmpty && gesperrt)
              _leer('Noch keine Personen.')
            else
              KartoKartenraster(
                mindestbreite: 220,
                kinder: [
                  for (final person in personen)
                    KartoFigurenkarte(
                      name: person.name,
                      beschreibung: person.description,
                      onTap: bearbeitbar
                          ? () => _personBearbeiten(person)
                          : null,
                    ),
                  if (!gesperrt)
                    KartoFreieKachel(
                      key: const ValueKey<String>('karto-abenteuer-person-neu'),
                      beschriftung: 'Person hinzufügen',
                      symbol: Icons.person_add_alt,
                      onTap: bearbeitbar ? _personAnlegen : null,
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
                  for (var i = 0; i < notizen.length; i++)
                    KartoNotizkarte(
                      titel: notizen[i].title,
                      text: notizen[i].description,
                      onTap: bearbeitbar
                          ? () => _notizBearbeiten(i, notizen[i])
                          : null,
                    ),
                  if (!gesperrt)
                    KartoFreieKachel(
                      key: const ValueKey<String>('karto-abenteuer-notiz-neu'),
                      beschriftung: 'Notiz hinzufügen',
                      symbol: Icons.note_add_outlined,
                      onTap: bearbeitbar ? _notizAnlegen : null,
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

  // Einziger Schreibweg des Blatts: frisch laden, nur dieses Abenteuer
  // ersetzen, speichern. Doppelte Auslösung verhindert [_schreibt].
  Future<void> _schreibe(
    HeroAdventureEntry Function(HeroAdventureEntry abenteuer) aenderung,
  ) async {
    if (_schreibt) return;
    setState(() {
      _schreibt = true;
      _fehler = null;
    });
    try {
      if (ref.read(advancementSessionProvider(widget.heroId)) != null) {
        throw StateError('Während einer Planung ist das Abenteuer gesperrt.');
      }
      await ref
          .read(heroActionsProvider)
          .updateHero(
            widget.heroId,
            (held) => ersetzeAbenteuer(held, widget.abenteuerId, aenderung),
          );
    } catch (error) {
      if (mounted) {
        setState(() => _fehler = 'Speichern fehlgeschlagen: ${_text(error)}');
      }
    } finally {
      if (mounted) setState(() => _schreibt = false);
    }
  }

  String _text(Object error) =>
      error is StateError ? error.message : error.toString();

  Future<void> _datumAendern(HeroAdventureEntry abenteuer) async {
    final datum = await showDialog<HeroAdventureDateValue>(
      context: context,
      builder: (_) => _DatumDialog(initial: abenteuer.currentAventurianDate),
    );
    if (datum == null) return;
    await _schreibe((a) => a.copyWith(currentAventurianDate: datum));
  }

  Future<void> _zusammenfassungAendern(HeroAdventureEntry abenteuer) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(initial: abenteuer.summary),
    );
    if (text == null) return;
    await _schreibe((a) => a.copyWith(summary: text.trim()));
  }

  Future<void> _notizAnlegen() async {
    final ergebnis = await showDialog<_ZweiFelder>(
      context: context,
      builder: (_) => const _ZweiFelderDialog.notiz(),
    );
    if (ergebnis == null || ergebnis.loeschen) return;
    final notiz = HeroNoteEntry(
      title: ergebnis.erstes,
      description: ergebnis.zweites,
    );
    await _schreibe((a) => a.copyWith(notes: [...a.notes, notiz]));
  }

  Future<void> _notizBearbeiten(int index, HeroNoteEntry notiz) async {
    final ergebnis = await showDialog<_ZweiFelder>(
      context: context,
      builder: (_) => _ZweiFelderDialog.notiz(
        erstes: notiz.title,
        zweites: notiz.description,
      ),
    );
    if (ergebnis == null) return;
    if (ergebnis.loeschen && !await _bestaetigeLoeschen('Notiz')) return;
    await _schreibe((a) {
      // Der Index stammt aus der Anzeige; stimmt er nicht mehr mit dem
      // frisch geladenen Stand überein, wird nichts Falsches überschrieben.
      if (index >= a.notes.length ||
          a.notes[index].title != notiz.title ||
          a.notes[index].description != notiz.description) {
        throw StateError('Die Notiz wurde inzwischen geändert.');
      }
      final notizen = List<HeroNoteEntry>.of(a.notes);
      if (ergebnis.loeschen) {
        notizen.removeAt(index);
      } else {
        notizen[index] = HeroNoteEntry(
          title: ergebnis.erstes,
          description: ergebnis.zweites,
        );
      }
      return a.copyWith(notes: notizen);
    });
  }

  Future<void> _personAnlegen() async {
    final ergebnis = await showDialog<_ZweiFelder>(
      context: context,
      builder: (_) => const _ZweiFelderDialog.person(),
    );
    if (ergebnis == null || ergebnis.loeschen) return;
    final person = HeroAdventurePersonEntry(
      id: const Uuid().v4(),
      name: ergebnis.erstes,
      description: ergebnis.zweites,
    );
    await _schreibe((a) => a.copyWith(people: [...a.people, person]));
  }

  Future<void> _personBearbeiten(HeroAdventurePersonEntry person) async {
    final ergebnis = await showDialog<_ZweiFelder>(
      context: context,
      builder: (_) => _ZweiFelderDialog.person(
        erstes: person.name,
        zweites: person.description,
      ),
    );
    if (ergebnis == null) return;
    if (ergebnis.loeschen && !await _bestaetigeLoeschen('Person')) return;
    await _schreibe((a) {
      if (!a.people.any((p) => p.id == person.id)) {
        throw StateError('Die Person wurde inzwischen entfernt.');
      }
      return a.copyWith(
        people: [
          for (final p in a.people)
            if (p.id != person.id)
              p
            else if (!ergebnis.loeschen)
              p.copyWith(name: ergebnis.erstes, description: ergebnis.zweites),
        ],
      );
    });
  }

  Future<bool> _bestaetigeLoeschen(String was) async {
    final ja = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$was löschen?'),
        content: const Text('Das lässt sich nicht rückgängig machen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    return ja ?? false;
  }
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

/// Ergebnis der Notiz- und Personendialoge.
class _ZweiFelder {
  const _ZweiFelder(this.erstes, this.zweites, {this.loeschen = false});

  final String erstes;
  final String zweites;
  final bool loeschen;
}

/// Gemeinsamer Dialog für Notizen (Titel, Text) und Personen (Name, Rolle).
///
/// Schließt sich selbst und gibt sein Ergebnis zurück; geschrieben wird beim
/// Aufrufer, damit das Abenteuer nur an einer Stelle verändert wird.
class _ZweiFelderDialog extends StatefulWidget {
  const _ZweiFelderDialog.notiz({this.erstes, this.zweites})
    : titelNeu = 'Neue Notiz',
      titelBearbeiten = 'Notiz bearbeiten',
      etikettErstes = 'Titel',
      etikettZweites = 'Notiz';

  const _ZweiFelderDialog.person({this.erstes, this.zweites})
    : titelNeu = 'Neue Person',
      titelBearbeiten = 'Person bearbeiten',
      etikettErstes = 'Name',
      etikettZweites = 'Beschreibung';

  final String? erstes;
  final String? zweites;
  final String titelNeu;
  final String titelBearbeiten;
  final String etikettErstes;
  final String etikettZweites;

  bool get bearbeitet => erstes != null || zweites != null;

  @override
  State<_ZweiFelderDialog> createState() => _ZweiFelderDialogState();
}

class _ZweiFelderDialogState extends State<_ZweiFelderDialog> {
  late final TextEditingController _erstes = TextEditingController(
    text: widget.erstes ?? '',
  );
  late final TextEditingController _zweites = TextEditingController(
    text: widget.zweites ?? '',
  );

  @override
  void dispose() {
    _erstes.dispose();
    _zweites.dispose();
    super.dispose();
  }

  bool get _leer => _erstes.text.trim().isEmpty && _zweites.text.trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.bearbeitet ? widget.titelBearbeiten : widget.titelNeu),
      content: SizedBox(
        width: Breite.klein,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey<String>('karto-abenteuer-feld-1'),
              controller: _erstes,
              autofocus: true,
              decoration: InputDecoration(labelText: widget.etikettErstes),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Abstand.weit),
            TextField(
              key: const ValueKey<String>('karto-abenteuer-feld-2'),
              controller: _zweites,
              minLines: 3,
              maxLines: 8,
              decoration: InputDecoration(labelText: widget.etikettZweites),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.bearbeitet)
          TextButton(
            onPressed: () =>
                Navigator.of(context)
                    .pop(const _ZweiFelder('', '', loeschen: true)),
            child: const Text('Löschen'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _leer
              ? null
              : () => Navigator.of(
                  context,
                ).pop(_ZweiFelder(_erstes.text.trim(), _zweites.text.trim())),
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

/// Mehrzeiliger Textdialog für die Zusammenfassung.
class _TextDialog extends StatefulWidget {
  const _TextDialog({required this.initial});

  final String initial;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Zusammenfassung'),
      content: SizedBox(
        width: Breite.mittel,
        child: TextField(
          key: const ValueKey<String>('karto-abenteuer-text'),
          controller: _text,
          autofocus: true,
          minLines: 4,
          maxLines: 12,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_text.text),
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

/// Aventurisches Datum: Tag, Göttermonat aus dem kanonischen Kalender, Jahr.
class _DatumDialog extends StatefulWidget {
  const _DatumDialog({required this.initial});

  final HeroAdventureDateValue initial;

  @override
  State<_DatumDialog> createState() => _DatumDialogState();
}

class _DatumDialogState extends State<_DatumDialog> {
  late final TextEditingController _tag = TextEditingController(
    text: widget.initial.day,
  );
  late final TextEditingController _jahr = TextEditingController(
    text: widget.initial.year,
  );
  late String _monat = normalizeAventurianMonth(widget.initial.month);

  @override
  void dispose() {
    _tag.dispose();
    _jahr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Aktuelles Datum'),
      content: SizedBox(
        width: Breite.klein,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey<String>('karto-abenteuer-tag'),
              controller: _tag,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Tag'),
            ),
            const SizedBox(height: Abstand.weit),
            DropdownButtonFormField<String>(
              key: const ValueKey<String>('karto-abenteuer-monat'),
              initialValue: _monat,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Monat'),
              items: [
                const DropdownMenuItem(value: '', child: Text('—')),
                for (final monat in aventurianMonths)
                  DropdownMenuItem(
                    value: monat.value,
                    child: Text(monat.label),
                  ),
              ],
              onChanged: (wert) => setState(() => _monat = wert ?? ''),
            ),
            const SizedBox(height: Abstand.weit),
            TextField(
              key: const ValueKey<String>('karto-abenteuer-jahr'),
              controller: _jahr,
              decoration: const InputDecoration(
                labelText: 'Jahr',
                suffixText: 'BF',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            HeroAdventureDateValue(
              day: _tag.text.trim(),
              month: _monat,
              year: _jahr.text.trim(),
            ),
          ),
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
