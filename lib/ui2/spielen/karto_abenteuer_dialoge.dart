import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/domain/aventurian_date.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/ui2/foundation/karto_spacing.dart';

// Eingabedialoge für Abenteuerblatt und Abenteuerabschnitt (Notiz, Person,
// Zusammenfassung, Datum). Sie schließen sich selbst und geben nur ihr
// Ergebnis zurück; geschrieben wird ausschließlich über
// `KartoAbenteuerSchreiben`.

/// Ergebnis der Notiz- und Personendialoge.
class KartoZweiFelder {
  const KartoZweiFelder(
    this.erstes,
    this.zweites, {
    this.ort = '',
    this.datum = '',
    this.loeschen = false,
  });

  final String erstes;
  final String zweites;

  /// Ort des Eintrags, ohne Randleerzeichen; leer, wenn keiner angegeben ist.
  final String ort;

  /// Aventurisches Datum als Text, ohne Randleerzeichen; leer ohne Angabe.
  final String datum;
  final bool loeschen;
}

/// Gemeinsamer Dialog für Notizen (Titel, Text) und Personen (Name, Rolle),
/// beide mit Ort und aventurischem Datum.
///
/// Schließt sich selbst und gibt sein Ergebnis zurück; geschrieben wird beim
/// Aufrufer, damit das Abenteuer nur an einer Stelle verändert wird. Ort und
/// Datum eines **neuen** Eintrags legt der Aufrufer als Vorbelegung ein (Standort
/// des Helden, Datum des Abenteuers); beim Bearbeiten stehen die gespeicherten
/// Werte darin.
class KartoZweiFelderDialog extends StatefulWidget {
  const KartoZweiFelderDialog.notiz({
    super.key,
    this.erstes,
    this.zweites,
    this.ort = '',
    this.datum = '',
  }) : titelNeu = 'Neue Notiz',
       titelBearbeiten = 'Notiz bearbeiten',
       etikettErstes = 'Titel',
       etikettZweites = 'Notiz';

  const KartoZweiFelderDialog.person({
    super.key,
    this.erstes,
    this.zweites,
    this.ort = '',
    this.datum = '',
  }) : titelNeu = 'Neue Person',
       titelBearbeiten = 'Person bearbeiten',
       etikettErstes = 'Name',
       etikettZweites = 'Beschreibung';

  final String? erstes;
  final String? zweites;
  final String ort;
  final String datum;
  final String titelNeu;
  final String titelBearbeiten;
  final String etikettErstes;
  final String etikettZweites;

  bool get bearbeitet => erstes != null || zweites != null;

  @override
  State<KartoZweiFelderDialog> createState() => _KartoZweiFelderDialogState();
}

class _KartoZweiFelderDialogState extends State<KartoZweiFelderDialog> {
  late final TextEditingController _erstes = TextEditingController(
    text: widget.erstes ?? '',
  );
  late final TextEditingController _zweites = TextEditingController(
    text: widget.zweites ?? '',
  );
  late final TextEditingController _ort = TextEditingController(
    text: widget.ort,
  );
  late final TextEditingController _datum = TextEditingController(
    text: widget.datum,
  );

  @override
  void dispose() {
    _erstes.dispose();
    _zweites.dispose();
    _ort.dispose();
    _datum.dispose();
    super.dispose();
  }

  bool get _leer => _erstes.text.trim().isEmpty && _zweites.text.trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.bearbeitet ? widget.titelBearbeiten : widget.titelNeu),
      content: SizedBox(
        width: Breite.klein,
        // Mit Ort und Datum wird der Dialog hoch; auf kleinen Bildschirmen und
        // bei Tastatur bleibt er so erreichbar.
        child: SingleChildScrollView(
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
              const SizedBox(height: Abstand.weit),
              TextField(
                key: const ValueKey<String>('karto-abenteuer-feld-ort'),
                controller: _ort,
                decoration: const InputDecoration(labelText: 'Ort'),
              ),
              const SizedBox(height: Abstand.weit),
              TextField(
                key: const ValueKey<String>('karto-abenteuer-feld-datum'),
                controller: _datum,
                decoration: const InputDecoration(
                  labelText: 'Datum',
                  hintText: 'z. B. 17. Boron 1020 BF',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.bearbeitet)
          TextButton(
            onPressed: () =>
                Navigator.of(context)
                    .pop(const KartoZweiFelder('', '', loeschen: true)),
            child: const Text('Löschen'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _leer
              ? null
              : () => Navigator.of(context).pop(
                  KartoZweiFelder(
                    _erstes.text.trim(),
                    _zweites.text.trim(),
                    ort: _ort.text.trim(),
                    datum: _datum.text.trim(),
                  ),
                ),
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

/// Mehrzeiliger Textdialog für die Zusammenfassung.
class KartoTextDialog extends StatefulWidget {
  const KartoTextDialog({super.key, required this.initial});

  final String initial;

  @override
  State<KartoTextDialog> createState() => _KartoTextDialogState();
}

class _KartoTextDialogState extends State<KartoTextDialog> {
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
class KartoDatumDialog extends StatefulWidget {
  const KartoDatumDialog({super.key, required this.initial});

  final HeroAdventureDateValue initial;

  @override
  State<KartoDatumDialog> createState() => _KartoDatumDialogState();
}

class _KartoDatumDialogState extends State<KartoDatumDialog> {
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
            widget.initial.copyWith(
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
