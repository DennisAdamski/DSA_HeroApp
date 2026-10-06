part of 'karto_abenteuerblatt.dart';

// Eingabedialoge des Abenteuerblatts (Notiz, Person, Zusammenfassung,
// Datum). Sie schließen sich selbst und geben nur ihr Ergebnis zurück;
// geschrieben wird ausschließlich im Blatt.

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
