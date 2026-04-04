import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';

void main() {
  group('HeroAdventureEntry', () {
    test('serializes status, people and date values', () {
      const entry = HeroAdventureEntry(
        id: 'adv_1',
        status: HeroAdventureStatus.completed,
        title: 'Die Versiegelung von Punin',
        summary: 'Die Gruppe bewacht einen verbotenen Schrein.',
        notes: <HeroNoteEntry>[
          HeroNoteEntry(
            title: 'Schlüsselstelle',
            description: 'Der Zugang ist nur bei Sonnenaufgang sicher.',
          ),
        ],
        people: <HeroAdventurePersonEntry>[
          HeroAdventurePersonEntry(
            id: 'person_1',
            name: 'Jucho',
            description: 'Informant aus dem Hafenviertel.',
          ),
        ],
        startWorldDate: HeroAdventureDateValue(
          day: '12',
          month: 'April',
          year: '2026',
        ),
        startAventurianDate: HeroAdventureDateValue(
          day: '5',
          month: 'praios',
          year: '1048',
        ),
        endWorldDate: HeroAdventureDateValue(
          day: '18',
          month: 'April',
          year: '2026',
        ),
        endAventurianDate: HeroAdventureDateValue(
          day: '11',
          month: 'praios',
          year: '1048',
        ),
        currentAventurianDate: HeroAdventureDateValue(
          day: '8',
          month: 'praios',
          year: '1048',
        ),
      );

      final reloaded = HeroAdventureEntry.fromJson(entry.toJson());

      expect(reloaded.status, HeroAdventureStatus.completed);
      expect(reloaded.people.single.id, 'person_1');
      expect(reloaded.people.single.name, 'Jucho');
      expect(reloaded.startWorldDate.month, 'April');
      expect(reloaded.startAventurianDate.month, 'praios');
      expect(reloaded.endAventurianDate.day, '11');
      expect(reloaded.currentAventurianDate.year, '1048');
      expect(reloaded.notes.single.title, 'Schlüsselstelle');
    });

    test('loads legacy payloads with current status and empty new fields', () {
      final entry = HeroAdventureEntry.fromJson(<String, dynamic>{
        'id': 'adv_legacy',
        'title': 'Altes Abenteuer',
        'summary': 'Noch ohne neue Felder.',
      });

      expect(entry.status, HeroAdventureStatus.current);
      expect(entry.people, isEmpty);
      expect(entry.startWorldDate.hasContent, isFalse);
      expect(entry.startAventurianDate.hasContent, isFalse);
      expect(entry.endWorldDate.hasContent, isFalse);
      expect(entry.endAventurianDate.hasContent, isFalse);
      expect(entry.currentAventurianDate.hasContent, isFalse);
    });
  });
}
