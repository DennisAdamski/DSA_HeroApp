import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_laufendes_abenteuer.dart';

import '../shell/karto_test_support.dart';

void main() {
  final held = testHero().copyWith(
    notes: const [HeroNoteEntry(title: 'Chronik')],
    adventures: const [
      HeroAdventureEntry(id: 'alt', title: 'Altes Abenteuer'),
      HeroAdventureEntry(id: 'nebel', title: 'Die Spuren im Nebel'),
    ],
  );

  test('ersetzt nur das gewaehlte Abenteuer', () {
    final neu = ersetzeAbenteuer(
      held,
      'nebel',
      (a) => a.copyWith(summary: 'Spur gefunden'),
    );
    expect(neu.adventures[1].summary, 'Spur gefunden');
    expect(neu.adventures[0].title, 'Altes Abenteuer');
    expect(neu.adventures[0].summary, isEmpty);
    expect(neu.notes.single.title, 'Chronik');
  });

  test('ein inzwischen entferntes Abenteuer wird nicht neu angelegt', () {
    expect(() => ersetzeAbenteuer(held, 'weg', (a) => a), throwsStateError);
  });

  test('laufend ist nur ein aktuelles Abenteuer mit Titel', () {
    final gemischt = testHero().copyWith(
      adventures: const [
        HeroAdventureEntry(id: 'leer'),
        HeroAdventureEntry(
          id: 'fertig',
          title: 'Fertig',
          status: HeroAdventureStatus.completed,
        ),
        HeroAdventureEntry(id: 'nebel', title: 'Nebel'),
      ],
    );
    expect(laufendesAbenteuer(gemischt)!.id, 'nebel');
  });
}
