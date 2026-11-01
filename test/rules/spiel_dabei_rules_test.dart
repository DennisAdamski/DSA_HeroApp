import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/rules/derived/currency_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/spiel_dabei_rules.dart';

// Block „Dabei“ (SPIEL-02): Geldstand und Verbrauchsgegenstände zählen. Die
// Schritte rechnen vom gespeicherten Wert, ändern nur ihr eigenes Feld und
// geben bei „nichts zu tun“ den Helden selbst zurück.

HeroInventoryEntry _verbrauch(
  String name,
  String anzahl, {
  String? id,
  int? menge,
  InventoryItemSource source = InventoryItemSource.manuell,
  InventoryTraeger traeger = InventoryTraeger.held,
  InventoryItemType typ = InventoryItemType.verbrauchsgegenstand,
}) => HeroInventoryEntry(
  gegenstand: name,
  anzahl: anzahl,
  menge: menge,
  instanzId: id,
  itemType: typ,
  source: source,
  traegerTyp: traeger,
);

HeroSheet _held({
  String dukaten = '',
  List<HeroInventoryEntry> eintraege = const [],
}) => HeroSheet(
  id: 'held',
  name: 'Rondra',
  level: 1,
  attributes: const Attributes(
    mu: 12,
    kl: 12,
    inn: 12,
    ch: 12,
    ff: 12,
    ge: 12,
    ko: 12,
    kk: 12,
  ),
  dukaten: dukaten,
  inventoryEntries: eintraege,
);

void main() {
  group('Auswahl der Verbrauchsgegenstände', () {
    test('nur manuelle Verbrauchsgegenstände des Helden', () {
      final fackel = _verbrauch('Fackel', '3', id: 'a');
      final liste = dabeiVerbrauchsgegenstaende([
        fackel,
        _verbrauch('Pfeil', '20', source: InventoryItemSource.geschoss),
        _verbrauch('Proviant', '2', traeger: InventoryTraeger.begleiter),
        _verbrauch('Seil', '1', typ: InventoryItemType.ausruestung),
        _verbrauch('Wein', '1', source: InventoryItemSource.abenteuer),
      ]);
      expect(liste.map((e) => e.gegenstand), ['Fackel', 'Wein']);
    });

    test('Namen, Menge und Änderbarkeit', () {
      expect(dabeiName(_verbrauch('  ', '1')), 'Unbenannt');
      expect(dabeiMengeText(_verbrauch('A', '4')), '4');
      expect(dabeiMengeText(_verbrauch('A', 'ein paar')), 'ein paar');
      expect(dabeiMengeText(_verbrauch('A', '')), '–');
      expect(dabeiMengeAenderbar(_verbrauch('A', '4')), isTrue);
      expect(dabeiMengeAenderbar(_verbrauch('A', 'ein paar')), isFalse);
      // Eine ältere App hat `anzahl` abweichend von `menge` geändert.
      expect(dabeiMengeAenderbar(_verbrauch('A', '5', menge: 4)), isFalse);
    });
  });

  group('Menge ändern', () {
    test('rechnet vom gespeicherten Wert und schreibt Menge und Anzahl', () {
      final fackel = _verbrauch('Fackel', '3', id: 'a', menge: 3);
      final held = _held(eintraege: [fackel]);
      // Der Aufrufer hält einen veralteten Stand (2 statt 3): gezählt wird ab
      // dem gespeicherten.
      final alt = _verbrauch('Fackel', '2', id: 'a', menge: 2);
      final neu = mitVerbrauchsmengenSchritt(held, alt, -1);
      expect(neu.inventoryEntries.single.menge, 2);
      expect(neu.inventoryEntries.single.anzahl, '2');
      // Nur dieser Eintrag, nur seine Menge.
      expect(neu.inventoryEntries.single.gegenstand, 'Fackel');
      expect(neu.dukaten, held.dukaten);
    });

    test('zwei Schritte nacheinander zählen beide', () {
      final fackel = _verbrauch('Fackel', '3', id: 'a', menge: 3);
      var held = _held(eintraege: [fackel]);
      held = mitVerbrauchsmengenSchritt(held, fackel, -1);
      held = mitVerbrauchsmengenSchritt(held, fackel, -1);
      expect(held.inventoryEntries.single.menge, 1);
    });

    test('trifft nur den Eintrag mit der Instanz-ID', () {
      final a = _verbrauch('Fackel', '3', id: 'a', menge: 3);
      final b = _verbrauch('Fackel', '3', id: 'b', menge: 3);
      final neu = mitVerbrauchsmengenSchritt(_held(eintraege: [a, b]), b, 2);
      expect(neu.inventoryEntries.map((e) => e.menge), [3, 5]);
    });

    test('ohne Instanz-ID trifft er den inhaltsgleichen Eintrag', () {
      final fackel = _verbrauch('Fackel', '3');
      final neu = mitVerbrauchsmengenSchritt(
        _held(eintraege: [_verbrauch('Seil', '1'), fackel]),
        fackel,
        1,
      );
      expect(neu.inventoryEntries.map((e) => e.anzahl), ['1', '4']);
    });

    test('bleibt zwischen 0 und dem Höchstbestand', () {
      final fackel = _verbrauch('Fackel', '1', id: 'a', menge: 1);
      final leer = mitVerbrauchsmengenSchritt(
        _held(eintraege: [fackel]),
        fackel,
        -5,
      );
      expect(leer.inventoryEntries.single.menge, 0);
      expect(leer.inventoryEntries, hasLength(1));

      final voll = _verbrauch('Fackel', '9999', id: 'a', menge: 9999);
      final held = _held(eintraege: [voll]);
      expect(
        identical(mitVerbrauchsmengenSchritt(held, voll, 1), held),
        isTrue,
      );
    });

    test('ohne Änderung kommt der Held selbst zurück', () {
      final fackel = _verbrauch('Fackel', '0', id: 'a', menge: 0);
      final held = _held(eintraege: [fackel]);
      expect(
        identical(mitVerbrauchsmengenSchritt(held, fackel, -1), held),
        isTrue,
      );
    });

    test('weist Freitext, Abweichung, Fremdes und Verlorenes ab', () {
      final frei = _verbrauch('Wein', 'ein paar', id: 'a');
      expect(
        () => mitVerbrauchsmengenSchritt(_held(eintraege: [frei]), frei, 1),
        throwsA(isA<StateError>()),
      );
      final abweichend = _verbrauch('Wein', '5', id: 'a', menge: 4);
      expect(
        () => mitVerbrauchsmengenSchritt(
          _held(eintraege: [abweichend]),
          abweichend,
          1,
        ),
        throwsA(isA<StateError>()),
      );
      final pfeil = _verbrauch(
        'Pfeil',
        '20',
        id: 'p',
        menge: 20,
        source: InventoryItemSource.geschoss,
      );
      expect(
        () => mitVerbrauchsmengenSchritt(_held(eintraege: [pfeil]), pfeil, -1),
        throwsA(isA<StateError>()),
      );
      expect(
        () => mitVerbrauchsmengenSchritt(
          _held(),
          _verbrauch('Fackel', '3', id: 'weg', menge: 3),
          1,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('lässt Hash-relevante Felder des Eintrags unberührt', () {
      final fackel = HeroInventoryEntry(
        gegenstand: 'Fackel',
        anzahl: '3',
        menge: 3,
        instanzId: 'a',
        itemType: InventoryItemType.verbrauchsgegenstand,
        beschreibung: 'brennt',
        unbekannteFelder: const {'zukunft': 1},
      );
      final neu = mitVerbrauchsmengenSchritt(
        _held(eintraege: [fackel]),
        fackel,
        -1,
      );
      final eintrag = neu.inventoryEntries.single;
      expect(eintrag.beschreibung, 'brennt');
      expect(eintrag.unbekannteFelder, {'zukunft': 1});
      expect(eintrag.instanzId, 'a');
    });
  });

  group('Geld', () {
    test('Aufschlüsselung und Unlesbares', () {
      expect(dabeiGeldText('12,53'), '12 D / 5 S / 30 K');
      expect(dabeiGeldText(''), '0 D');
      expect(dabeiGeldText('ca. viel'), isNull);
      expect(dabeiGeldKreuzer('1'), 1000);
    });

    test('Betrag lesen: nur positive, lesbare Beträge', () {
      expect(dabeiBetragKreuzer('12 D 5 S'), 12500);
      expect(dabeiBetragKreuzer('12,5'), 12500);
      expect(dabeiBetragKreuzer('0'), isNull);
      expect(dabeiBetragKreuzer('-3'), isNull);
      expect(dabeiBetragKreuzer('viel'), isNull);
      expect(dabeiBetragKreuzer(''), isNull);
    });

    test('Abziehen nur bis zum Bestand', () {
      expect(dabeiKannAbziehen('1', dsaKreuzerPerDukat), isTrue);
      expect(dabeiKannAbziehen('1', dsaKreuzerPerDukat + 1), isFalse);
      expect(dabeiKannAbziehen('ca. viel', 1), isFalse);
      expect(dabeiKannAbziehen('', 1), isFalse);
    });

    test('Schritt rechnet vom gespeicherten Geldstand', () {
      var held = _held(dukaten: '12,5');
      held = mitGeldSchritt(held, dsaKreuzerPerSilber);
      expect(held.dukaten, '12,6');
      held = mitGeldSchritt(held, -dsaKreuzerPerDukat);
      expect(held.dukaten, '11,6');
      held = mitGeldSchritt(held, 3);
      expect(held.dukaten, '11,603');
    });

    test('Abzug über den Bestand wirft, statt still bei 0 zu kappen', () {
      final held = _held(dukaten: '1');
      expect(
        () => mitGeldSchritt(held, -(dsaKreuzerPerDukat + 1)),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Nicht genug Geld'),
          ),
        ),
      );
      expect(mitGeldSchritt(held, -dsaKreuzerPerDukat).dukaten, '0');
    });

    test('unlesbarer Geldstand wirft; Schritt 0 ändert nichts', () {
      final held = _held(dukaten: 'ca. viel');
      expect(() => mitGeldSchritt(held, 1), throwsA(isA<StateError>()));
      expect(identical(mitGeldSchritt(held, 0), held), isTrue);
    });
  });
}
