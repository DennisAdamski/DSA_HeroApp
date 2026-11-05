import 'package:dsa_heldenverwaltung/catalog/kurzregel_def.dart';
import 'package:dsa_heldenverwaltung/rules/derived/string_normalize.dart';

/// Filtert und ordnet Kurzregeln nach [anfrage] und optionalem [thema].
///
/// Jedes durch Leerraum getrennte Suchwort muss im Titel, in den
/// Schlagworten, im Themenanzeigenamen oder in den Texten vorkommen. Treffer
/// im Titel zaehlen am meisten, danach Schlagworte, dann Fliesstext; bei
/// gleichem Wert bleibt die Katalogreihenfolge. Eine leere Anfrage liefert
/// alle Eintraege des Themas in Katalogreihenfolge.
List<KurzregelDef> sucheKurzregeln(
  List<KurzregelDef> alle,
  String anfrage, {
  String? thema,
}) {
  final woerter = suchFaltung(anfrage)
      .split(RegExp(r'\s+'))
      .where((wort) => wort.isNotEmpty)
      .toList(growable: false);
  final kandidaten = [
    for (final eintrag in alle)
      if (thema == null || eintrag.thema == thema) eintrag,
  ];
  if (woerter.isEmpty) {
    return kandidaten;
  }
  final bewertet = <({KurzregelDef eintrag, int wert, int index})>[];
  for (var index = 0; index < kandidaten.length; index++) {
    final eintrag = kandidaten[index];
    final wert = _bewerte(eintrag, woerter);
    if (wert > 0) {
      bewertet.add((eintrag: eintrag, wert: wert, index: index));
    }
  }
  bewertet.sort((a, b) {
    final vergleich = b.wert.compareTo(a.wert);
    return vergleich != 0 ? vergleich : a.index.compareTo(b.index);
  });
  return [for (final treffer in bewertet) treffer.eintrag];
}

/// Summe der Wortwerte oder 0, wenn ein Suchwort nirgends vorkommt.
int _bewerte(KurzregelDef eintrag, List<String> woerter) {
  final titel = suchFaltung(eintrag.titel);
  final schlagworte = suchFaltung(eintrag.schlagworte.join(' '));
  final themaLabel = suchFaltung(kurzregelThemaLabel(eintrag.thema));
  final text = suchFaltung(
    [eintrag.kurztext, ...eintrag.hinweise, eintrag.hausregelText].join(' '),
  );
  var summe = 0;
  for (final wort in woerter) {
    final wert = titel.contains(wort)
        ? 4
        : schlagworte.contains(wort)
        ? 3
        : themaLabel.contains(wort)
        ? 2
        : text.contains(wort)
        ? 1
        : 0;
    if (wert == 0) {
      return 0;
    }
    summe += wert;
  }
  return summe;
}
