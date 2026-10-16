import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/alchimikum_def.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';
import 'package:dsa_heldenverwaltung/domain/inventory_item_modifier.dart';
import 'package:dsa_heldenverwaltung/domain/vitalwirkung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/alchimika_rules.dart';

const _heiltrank = AlchimikumDef(
  id: 'alch_heiltrank',
  name: 'Heiltrank',
  beleg: AlchimikumBeleg(buch: 'Wege der Alchimie', seite: '56'),
  haltbarkeit: '1W6+20 Monate',
  preisSilber: 100,
  preisText: 'ab 10 D',
  wirkung: 'Gibt LeP zurück.',
  qualitaeten: <AlchimikumQualitaet>[
    AlchimikumQualitaet(stufe: 'A', lepWurf: '1W6', lepProWunde: 7),
    AlchimikumQualitaet(
      stufe: 'C',
      lepWurf: '2W6+4',
      lepProWunde: 7,
      wirkung: 'Kurz.',
    ),
  ],
);

const _schlaftrunk = AlchimikumDef(
  id: 'alch_schlaftrunk',
  name: 'Schlaftrunk',
  qualitaeten: <AlchimikumQualitaet>[
    AlchimikumQualitaet(stufe: 'B', wirkung: 'Mehr Regeneration.'),
  ],
);

const _pulver = AlchimikumDef(id: 'alch_pulver', name: 'Wundpulver');

void main() {
  group('alchimikumVitalwirkung', () {
    test('trägt Würfelvorschläge, aber nie fertige Zahlen', () {
      final wirkung = alchimikumVitalwirkung(_heiltrank, 'C')!;
      expect(wirkung.lepWurf, '2W6+4');
      expect(wirkung.lepProWunde, 7);
      expect(wirkung.lep, 0);
      expect(wirkung.wunden, 0);
    });

    test('Stufen ohne Sofortwirkung und unbekannte Stufen liefern null', () {
      expect(alchimikumVitalwirkung(_schlaftrunk, 'B'), isNull);
      expect(alchimikumVitalwirkung(_heiltrank, 'F'), isNull);
      expect(alchimikumVitalwirkung(_pulver, null), isNull);
    });
  });

  group('wundenAusLep', () {
    final wirkung = alchimikumVitalwirkung(_heiltrank, 'C');

    test('je 7 LeP eine Wunde, abgerundet', () {
      expect(wundenAusLep(wirkung, 6), 0);
      expect(wundenAusLep(wirkung, 7), 1);
      expect(wundenAusLep(wirkung, 15), 2);
    });

    test('ohne Regel oder ohne LeP gibt es keinen Vorschlag', () {
      expect(wundenAusLep(null, 10), isNull);
      expect(wundenAusLep(const Vitalwirkung(lep: 5), 10), isNull);
      expect(wundenAusLep(wirkung, 0), isNull);
    });
  });

  group('mitAlchimikum', () {
    test('setzt Name, Typ, Beschreibung, Preis und Vitalwirkung', () {
      final eintrag = mitAlchimikum(
        const HeroInventoryEntry(anzahl: '3'),
        _heiltrank,
        'C',
      );
      expect(eintrag.gegenstand, 'Heiltrank (Qualität C)');
      expect(eintrag.itemType, InventoryItemType.verbrauchsgegenstand);
      expect(eintrag.wertSilber, 100);
      expect(eintrag.anzahl, '3');
      expect(eintrag.vitalwirkung!.lepWurf, '2W6+4');
      expect(eintrag.beschreibung, contains('Qualität C: Kurz.'));
      expect(eintrag.beschreibung, contains('Wurf: LeP 2W6+4'));
      expect(
        eintrag.beschreibung,
        contains('Je 7 zurückgewonnene LeP schließt sich eine Wunde.'),
      );
      expect(eintrag.beschreibung, contains('Quelle: Wege der Alchimie S. 56'));
    });

    test('ohne Preis im Katalog bleibt der eingetragene Wert', () {
      final eintrag = mitAlchimikum(
        const HeroInventoryEntry(wertSilber: 42),
        _schlaftrunk,
        'B',
      );
      expect(eintrag.wertSilber, 42);
      expect(eintrag.gegenstand, 'Schlaftrunk (Qualität B)');
      expect(eintrag.vitalwirkung, isNull);
    });

    test('Mittel ohne Stufen behält den schlichten Namen', () {
      final eintrag = mitAlchimikum(const HeroInventoryEntry(), _pulver, null);
      expect(eintrag.gegenstand, 'Wundpulver');
    });

    test('ein früherer Katalogvorschlag entfällt beim Wechsel', () {
      final heiltrank = mitAlchimikum(
        const HeroInventoryEntry(),
        _heiltrank,
        'C',
      );
      final schlaf = mitAlchimikum(heiltrank, _schlaftrunk, 'B');
      expect(schlaf.vitalwirkung, isNull);
    });

    test('Felder einer neueren Version überleben, alte Zahlen entfallen', () {
      const basis = HeroInventoryEntry(
        vitalwirkung: Vitalwirkung(
          lep: 4,
          unbekannteFelder: <String, Object?>{'zukunft': 1},
        ),
      );
      final eintrag = mitAlchimikum(basis, _heiltrank, 'A');
      final wirkung = eintrag.vitalwirkung!;
      expect(wirkung.unbekannteFelder, containsPair('zukunft', 1));
      expect(wirkung.lepWurf, '1W6');
      // Die Zahl aus einer früheren Eingabe ist ein Vorschlag des alten
      // Mittels und entfällt mit ihm.
      expect(wirkung.lep, 0);
    });
  });
}
