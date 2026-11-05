import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';

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
        dukatenReward: 12.5,
        lootRewards: <HeroAdventureLootEntry>[
          HeroAdventureLootEntry(
            id: 'loot_1',
            name: 'Mondsilberring',
            quantity: '1',
            itemType: InventoryItemType.wertvolles,
            weightGramm: 25,
            valueSilver: 80,
            origin: 'Punin',
            description: 'Belohnung des Geweihten.',
          ),
        ],
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
      expect(reloaded.dukatenReward, 12.5);
      expect(reloaded.lootRewards.single.name, 'Mondsilberring');
      expect(
        reloaded.lootRewards.single.itemType,
        InventoryItemType.wertvolles,
      );
    });

    test('Notiz und Person tragen Ort und Datum durch Speichern und Laden', () {
      const notiz = HeroNoteEntry(
        title: 'Wirt',
        ort: 'Punin',
        datum: HeroAdventureDateValue(day: '17', month: 'boron', year: '1020'),
      );
      const person = HeroAdventurePersonEntry(
        id: 'p1',
        name: 'Alrik',
        ort: 'Gareth',
        datum: HeroAdventureDateValue(day: '3', month: 'rahja', year: '1040'),
      );

      final notizNeu = HeroNoteEntry.fromJson(notiz.toJson());
      final personNeu = HeroAdventurePersonEntry.fromJson(person.toJson());

      expect(notizNeu.ort, 'Punin');
      expect(notizNeu.datum.anzeigeText, '17. Boron 1020 BF');
      expect(notizNeu.toJson()['datum'], <String, dynamic>{
        'day': '17',
        'month': 'boron',
        'year': '1020',
      });
      expect(personNeu.ort, 'Gareth');
      expect(personNeu.datum.anzeigeText, '3. Rahja 1040 BF');
    });

    test(
      'ein als Freitext gespeichertes Datum wird zerlegt, nie verworfen',
      () {
        // Eine Zwischenfassung speicherte das Datum von Notiz und Person als
        // Text; er wird beim Lesen strukturiert.
        final notiz = HeroNoteEntry.fromJson(const <String, dynamic>{
          'title': 'Wirt',
          'datum': '17. Boron 1020 BF',
        });
        expect(notiz.datum.day, '17');
        expect(notiz.datum.month, 'boron');
        expect(notiz.datum.year, '1020 BF');
        expect(notiz.datum.anzeigeText, '17. Boron 1020 BF');

        final ohneTag = HeroAdventurePersonEntry.fromJson(
          const <String, dynamic>{'id': 'p', 'datum': 'Namenlose Tage'},
        );
        expect(ohneTag.datum.month, 'namenlose_tage');
        expect(ohneTag.datum.day, isEmpty);

        // Unlesbarer Text bleibt vollständig erhalten.
        final unklar = HeroNoteEntry.fromJson(const <String, dynamic>{
          'title': 'T',
          'datum': 'kurz vor dem Fest',
        });
        expect(unklar.datum.anzeigeText, 'kurz vor dem Fest');
      },
    );

    test('Ort und Datum erscheinen nur bei Belegung im JSON (Hash-Schutz)', () {
      // Bestandseinträge dürfen sich im JSON nicht ändern, sonst ändert sich
      // der Inhalts-Hash jedes Bestandshelden und der Sync meldet Konflikte.
      final notiz = const HeroNoteEntry(title: 'Wirt').toJson();
      final person = const HeroAdventurePersonEntry(
        id: 'p1',
        name: 'Alrik',
      ).toJson();
      expect(notiz.containsKey('ort'), isFalse);
      expect(notiz.containsKey('datum'), isFalse);
      expect(person.containsKey('ort'), isFalse);
      expect(person.containsKey('datum'), isFalse);

      // Ein Bestands-JSON lädt unverändert zurück.
      const altNotiz = <String, dynamic>{'title': 'Wirt', 'description': 'x'};
      expect(HeroNoteEntry.fromJson(altNotiz).toJson(), altNotiz);
    });

    test('copyWith erhält Ort und Datum und setzt sie gezielt', () {
      const heute = HeroAdventureDateValue(day: '1', month: 'praios');
      const notiz = HeroNoteEntry(title: 'T', ort: 'Punin', datum: heute);
      expect(notiz.copyWith(title: 'U').ort, 'Punin');
      expect(notiz.copyWith(title: 'U').datum, same(heute));
      expect(notiz.copyWith(ort: '').ort, isEmpty);
      const person = HeroAdventurePersonEntry(id: 'p', ort: 'Gareth');
      expect(person.copyWith(name: 'N').ort, 'Gareth');
      const morgen = HeroAdventureDateValue(day: '2', month: 'praios');
      expect(person.copyWith(datum: morgen).datum, same(morgen));
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
      expect(entry.dukatenReward, 0);
      expect(entry.lootRewards, isEmpty);
    });
  });
}
