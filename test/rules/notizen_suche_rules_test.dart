import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_adventure_date_value.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/notizen_suche_rules.dart';

void main() {
  const notizen = <HeroNoteEntry>[
    HeroNoteEntry(
      title: 'Das Rätsel der Höhle',
      description: 'Ein Zwerg nannte den Pfad nach Angbar.',
    ),
    HeroNoteEntry(
      title: 'Schulden',
      description: 'Zwei Dukaten an die Wirtin.',
      ort: 'Gareth',
      datum: HeroAdventureDateValue(day: '17', month: 'Boron', year: '1020'),
    ),
    HeroNoteEntry(title: 'Leer'),
  ];

  group('filtereNotizIndizes', () {
    test('leerer oder blanker Suchtext liefert alle Indizes', () {
      expect(filtereNotizIndizes(notizen, ''), <int>[0, 1, 2]);
      expect(filtereNotizIndizes(notizen, '   '), <int>[0, 1, 2]);
    });

    test('sucht in Titel, Beschreibung, Ort und Datum', () {
      expect(filtereNotizIndizes(notizen, 'schulden'), <int>[1]);
      expect(filtereNotizIndizes(notizen, 'angbar'), <int>[0]);
      expect(filtereNotizIndizes(notizen, 'gareth'), <int>[1]);
      expect(filtereNotizIndizes(notizen, 'boron'), <int>[1]);
    });

    test('Umlaute und Umschreibungen fallen zusammen', () {
      expect(filtereNotizIndizes(notizen, 'raetsel'), <int>[0]);
      expect(filtereNotizIndizes(notizen, 'Rätsel'), <int>[0]);
      expect(filtereNotizIndizes(notizen, 'hohle'), <int>[0]);
      expect(filtereNotizIndizes(notizen, 'HÖHLE'), <int>[0]);
    });

    test('jedes Wort muss vorkommen, auch über Felder verteilt', () {
      expect(filtereNotizIndizes(notizen, 'dukaten gareth'), <int>[1]);
      expect(filtereNotizIndizes(notizen, 'gareth dukaten'), <int>[1]);
      expect(filtereNotizIndizes(notizen, 'dukaten angbar'), isEmpty);
    });

    test('liefert Originalindizes in der Reihenfolge der Liste', () {
      expect(filtereNotizIndizes(notizen, 'e'), <int>[0, 1, 2]);
      expect(filtereNotizIndizes(notizen, 'leer'), <int>[2]);
    });

    test('ohne Notizen oder Treffer kommt eine leere Liste', () {
      expect(filtereNotizIndizes(const <HeroNoteEntry>[], 'x'), isEmpty);
      expect(filtereNotizIndizes(notizen, 'drache'), isEmpty);
    });
  });
}
