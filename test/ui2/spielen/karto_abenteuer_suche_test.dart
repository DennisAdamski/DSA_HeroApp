import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abenteuer_suche.dart';

HeroAdventureEntry _abenteuer(
  String id, {
  List<HeroNoteEntry> notizen = const [],
  List<HeroAdventurePersonEntry> personen = const [],
}) => HeroAdventureEntry(
  id: id,
  title: 'Abenteuer $id',
  notes: notizen,
  people: personen,
);

void main() {
  group('sucheInAbenteuern', () {
    final a1 = _abenteuer(
      'a1',
      notizen: const [
        HeroNoteEntry(title: 'Wirt', description: 'Weiß mehr.', ort: 'Punin'),
      ],
    );
    final a2 = _abenteuer(
      'a2',
      notizen: const [
        HeroNoteEntry(title: 'Wirtin', description: 'Schenkt Met aus.'),
      ],
      personen: const [
        HeroAdventurePersonEntry(
          id: 'p1',
          name: 'Ärger-Alrik',
          description: 'Wirt in Gareth',
          datum: '3. Rahja 1040 BF',
        ),
      ],
    );
    final a3 = _abenteuer(
      'a3',
      notizen: const [HeroNoteEntry(title: 'Brücke', description: 'Kaputt.')],
    );

    test('ein leerer Suchtext findet nichts', () {
      expect(
        sucheInAbenteuern(
          abenteuer: [a1, a2, a3],
          aktuellId: 'a1',
          suchtext: '  ',
        ),
        isEmpty,
      );
    });

    test('Abenteuer ohne Treffer fehlen, das aktuelle steht vorn', () {
      final treffer = sucheInAbenteuern(
        abenteuer: [a1, a2, a3],
        aktuellId: 'a1',
        suchtext: 'wirt',
      );
      expect(treffer.map((t) => t.abenteuer.id), ['a1', 'a2']);
      expect(treffer.first.aktuell, isTrue);
      expect(treffer.last.aktuell, isFalse);
    });

    test('übrige Abenteuer folgen mit dem zuletzt angelegten zuerst', () {
      final treffer = sucheInAbenteuern(
        abenteuer: [a1, a2, a3],
        aktuellId: 'a3',
        suchtext: 'wirt',
      );
      // a3 hat keinen Treffer; a2 (später angelegt) steht vor a1.
      expect(treffer.map((t) => t.abenteuer.id), ['a2', 'a1']);
      expect(treffer.any((t) => t.aktuell), isFalse);
    });

    test('das aktuelle Abenteuer steht auch vorn, wenn es hinten liegt', () {
      final treffer = sucheInAbenteuern(
        abenteuer: [a1, a2],
        aktuellId: 'a1',
        suchtext: 'wirt',
      );
      expect(treffer.first.abenteuer.id, 'a1');
    });

    test('durchsucht Titel, Text, Ort, Datum, Name und Beschreibung', () {
      List<String> ids(String text) => sucheInAbenteuern(
        abenteuer: [a1, a2, a3],
        aktuellId: 'a1',
        suchtext: text,
      ).map((t) => t.abenteuer.id).toList();

      expect(ids('punin'), ['a1']); // Ort
      expect(ids('rahja'), ['a2']); // Datum einer Person
      expect(ids('met'), ['a2']); // Text
      expect(ids('gareth'), ['a2']); // Beschreibung einer Person
      expect(ids('kaputt'), ['a3']); // Text
    });

    test('Groß- und Kleinschreibung und Umlaute spielen keine Rolle', () {
      for (final text in ['ÄRGER', 'ärger', 'arger', 'ARGER']) {
        expect(
          sucheInAbenteuern(
            abenteuer: [a2],
            aktuellId: '',
            suchtext: text,
          ).single.personen,
          [0],
          reason: text,
        );
      }
    });

    test('jedes Wort muss vorkommen, in beliebiger Reihenfolge', () {
      List<int> notizen(String text) => sucheInAbenteuern(
        abenteuer: [a1],
        aktuellId: 'a1',
        suchtext: text,
      ).expand((t) => t.notizen).toList();

      expect(notizen('wirt punin'), [0]);
      expect(notizen('punin wirt'), [0]);
      expect(notizen('wirt gareth'), isEmpty);
    });

    test('Treffer folgen der gewählten Sortierung', () {
      final abenteuer = _abenteuer(
        'a',
        notizen: [
          const HeroNoteEntry(title: 'Beta Wirt'),
          const HeroNoteEntry(title: 'Alpha Wirt'),
        ],
      );
      List<int> mit(AbenteuerSortierung s) => sucheInAbenteuern(
        abenteuer: [abenteuer],
        aktuellId: 'a',
        suchtext: 'wirt',
        sortierung: s,
      ).single.notizen;

      expect(mit(AbenteuerSortierung.alphabetisch), [1, 0]);
      expect(mit(AbenteuerSortierung.neuesteZuerst), [1, 0]);
      expect(mit(AbenteuerSortierung.aeltesteZuerst), [0, 1]);
    });

    test('anzahl zählt Notizen und Personen', () {
      final treffer = sucheInAbenteuern(
        abenteuer: [a2],
        aktuellId: 'a2',
        suchtext: 'wirt',
      );
      expect(treffer.single.anzahl, 2);
    });
  });
}
