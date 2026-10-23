import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/kurzregel_def.dart';
import 'package:dsa_heldenverwaltung/rules/derived/kurzregel_suche_rules.dart';

/// Erfundene Eintraege: geprueft wird die Suche, nicht der Regelinhalt.
void main() {
  const alle = <KurzregelDef>[
    KurzregelDef(
      id: 'a',
      titel: 'Betäubung',
      thema: 'zustaende',
      schlagworte: ['benommen'],
      kurztext: 'Erfundener Text über Erschwernisse',
    ),
    KurzregelDef(
      id: 'b',
      titel: 'Wuchtschlag',
      thema: 'kampf',
      kurztext: 'Text zur Betäubung des Gegners',
      hinweise: ['Sonderfall Lanze'],
    ),
    KurzregelDef(
      id: 'c',
      titel: 'Finte',
      thema: 'kampf',
      hausregelText: 'Hausregel-Zusatz Ausdauer',
    ),
  ];

  List<String> ids(List<KurzregelDef> liste) => [for (final e in liste) e.id];

  test('leere Anfrage liefert alle in Katalogreihenfolge', () {
    expect(ids(sucheKurzregeln(alle, '')), ['a', 'b', 'c']);
    expect(ids(sucheKurzregeln(alle, '   ')), ['a', 'b', 'c']);
  });

  test('Themenfilter schraenkt ein', () {
    expect(ids(sucheKurzregeln(alle, '', thema: 'kampf')), ['b', 'c']);
  });

  test('Umlaute und ß sind austauschbar zu ihrer Grundschreibung', () {
    expect(ids(sucheKurzregeln(alle, 'betaubung')), ['a', 'b']);
    expect(ids(sucheKurzregeln(alle, 'BETÄUBUNG')), ['a', 'b']);
  });

  test('Titeltreffer stehen vor Textreffern', () {
    expect(ids(sucheKurzregeln(alle, 'betäubung')), ['a', 'b']);
  });

  test('alle Suchwoerter muessen vorkommen', () {
    expect(ids(sucheKurzregeln(alle, 'betäubung lanze')), ['b']);
    expect(sucheKurzregeln(alle, 'betäubung xyz'), isEmpty);
  });

  test('findet Schlagworte, Hinweise, Hausregeltext und Themenname', () {
    expect(ids(sucheKurzregeln(alle, 'benommen')), ['a']);
    expect(ids(sucheKurzregeln(alle, 'lanze')), ['b']);
    expect(ids(sucheKurzregeln(alle, 'ausdauer')), ['c']);
    expect(ids(sucheKurzregeln(alle, 'zustände')), ['a']);
  });
}
