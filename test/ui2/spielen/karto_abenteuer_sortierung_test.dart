import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/app_settings.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_note_entry.dart';
import 'package:dsa_heldenverwaltung/ui2/spielen/karto_abenteuer_sortierung.dart';

void main() {
  final notizen = [
    HeroNoteEntry(title: 'Wirt', lastModified: DateTime.utc(2026, 1, 1)),
    const HeroNoteEntry(title: 'ärger im Hafen'),
    HeroNoteEntry(title: 'Karte', lastModified: DateTime.utc(2026, 3, 1)),
    const HeroNoteEntry(title: 'Ast'),
    const HeroNoteEntry(),
  ];

  group('sortiereNotizen', () {
    test('ältere zuerst behält die Erfassung', () {
      expect(sortiereNotizen(notizen, AbenteuerSortierung.aeltesteZuerst), [
        0,
        1,
        2,
        3,
        4,
      ]);
    });

    test('neueste zuerst kehrt die Erfassung um', () {
      expect(sortiereNotizen(notizen, AbenteuerSortierung.neuesteZuerst), [
        4,
        3,
        2,
        1,
        0,
      ]);
    });

    test('zuletzt bearbeitet: Stempel absteigend, dann Bestand jüngste '
        'zuerst', () {
      expect(sortiereNotizen(notizen, AbenteuerSortierung.zuletztBearbeitet), [
        2,
        0,
        4,
        3,
        1,
      ]);
    });

    test('alphabetisch ordnet Umlaute ein und leere Titel ans Ende', () {
      expect(sortiereNotizen(notizen, AbenteuerSortierung.alphabetisch), [
        1,
        3,
        2,
        0,
        4,
      ]);
    });

    test('Gleichstand bleibt stabil', () {
      const gleich = [HeroNoteEntry(title: 'A'), HeroNoteEntry(title: 'a')];
      expect(sortiereNotizen(gleich, AbenteuerSortierung.alphabetisch), [0, 1]);
    });
  });

  test('sortierePersonen nutzt Name und Stempel', () {
    final personen = [
      const HeroAdventurePersonEntry(id: 'a', name: 'Zelda'),
      HeroAdventurePersonEntry(
        id: 'b',
        name: 'Alrik',
        lastModified: DateTime.utc(2026),
      ),
    ];
    expect(sortierePersonen(personen, AbenteuerSortierung.alphabetisch), [
      1,
      0,
    ]);
    expect(sortierePersonen(personen, AbenteuerSortierung.zuletztBearbeitet), [
      1,
      0,
    ]);
  });

  group('lastModified im Modell', () {
    test('fehlt im JSON, solange es nicht belegt ist', () {
      expect(const HeroNoteEntry(title: 'T').toJson(), {
        'title': 'T',
        'description': '',
      });
      expect(
        const HeroAdventurePersonEntry(id: 'p')
            .toJson()
            .containsKey('lastModified'),
        isFalse,
      );
    });

    test('übersteht den Rundweg und lässt sich zurücksetzen', () {
      final zeit = DateTime.utc(2026, 10, 20, 12);
      final notiz = HeroNoteEntry.fromJson(
        HeroNoteEntry(title: 'T', lastModified: zeit).toJson(),
      );
      expect(notiz.lastModified, zeit);
      expect(notiz.copyWith(lastModified: null).lastModified, isNull);
      final person = HeroAdventurePersonEntry.fromJson(
        HeroAdventurePersonEntry(id: 'p', lastModified: zeit).toJson(),
      );
      expect(person.lastModified, zeit);
    });
  });

  test('Einstellung übersteht den Rundweg', () {
    const settings = AppSettings(
      abenteuerSortierung: AbenteuerSortierung.alphabetisch,
    );
    expect(
      AppSettings.fromJson(settings.toJson()).abenteuerSortierung,
      AbenteuerSortierung.alphabetisch,
    );
    expect(
      AppSettings.fromJson(const {}).abenteuerSortierung,
      AbenteuerSortierung.zuletztBearbeitet,
    );
  });
}
