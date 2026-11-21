import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/string_normalize.dart';

/// Filtert die allgemeinen Notizen (Chroniken) eines Helden nach [suchtext].
///
/// Gesucht wird in Titel, Beschreibung, Ort und Datum. Groß- und
/// Kleinschreibung und Umlaute spielen keine Rolle ([suchFaltung]: „ö“, „oe“
/// und „o“ fallen zusammen); jedes durch Leerzeichen getrennte Wort muss
/// vorkommen, in beliebiger Reihenfolge und auch über verschiedene Felder
/// verteilt. Ein leerer oder nur aus Leerzeichen bestehender [suchtext]
/// liefert alle Indizes.
///
/// Das Ergebnis sind **Indizes** in [notizen] in der ursprünglichen
/// Reihenfolge, keine Kopien: Aufrufer bearbeiten und löschen weiter über den
/// Originalindex der ungefilterten Liste. Die Funktion liest nur.
List<int> filtereNotizIndizes(List<HeroNoteEntry> notizen, String suchtext) {
  final woerter = suchFaltung(suchtext)
      .split(RegExp(r'\s+'))
      .where((wort) => wort.isNotEmpty)
      .toList();
  return <int>[
    for (var index = 0; index < notizen.length; index++)
      if (woerter.isEmpty || _passt(notizen[index], woerter)) index,
  ];
}

bool _passt(HeroNoteEntry notiz, List<String> woerter) {
  final heuhaufen = suchFaltung(
    <String>[
      notiz.title,
      notiz.description,
      notiz.ort,
      notiz.datum.anzeigeText,
    ].join('\n'),
  );
  return woerter.every(heuhaufen.contains);
}
