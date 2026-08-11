import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/catalog_constants.dart';
import 'package:dsa_heldenverwaltung/rules/derived/magic_acquisition_rules.dart';

void main() {
  group('Merkmalsklassifikation', () {
    test('deckt genau die 34 Katalog-Merkmale ab', () {
      final klassifiziert = <String>[
        ...kMerkmaleKlassifikationI,
        ...kMerkmaleKlassifikationII,
        ...kMerkmaleKlassifikationIII,
      ];

      expect(kMerkmaleKlassifikationI, hasLength(19));
      expect(kMerkmaleKlassifikationII, hasLength(10));
      expect(kMerkmaleKlassifikationIII, hasLength(5));
      expect(klassifiziert.toSet(), kMerkmale.toSet());
    });

    test('ordnet die Stufen korrekt zu', () {
      expect(merkmalsklassifikation('Heilung'), 1);
      expect(merkmalsklassifikation('Elementar (Feuer)'), 1);
      expect(merkmalsklassifikation('Dämonisch (Mishkara)'), 1);
      expect(merkmalsklassifikation('Antimagie'), 2);
      expect(merkmalsklassifikation('Objekt'), 2);
      expect(merkmalsklassifikation('Limbus'), 3);
      expect(merkmalsklassifikation('Dämonisch (allgemein)'), 3);
      expect(merkmalsklassifikation('Elementar (allgemein)'), 3);
    });

    test('behandelt unbekannte Merkmale als Stufe II', () {
      expect(merkmalsklassifikation('Hausregel-Merkmal'), 2);
      expect(merkmalsklassifikation('   '), 2);
    });

    test('ist umlauttolerant', () {
      expect(merkmalsklassifikation('Verstaendigung'), 1);
      expect(merkmalsklassifikation('Beschwoerung'), 2);
    });
  });

  group('Merkmalskenntnis-Kosten', () {
    test('kostet 100 / 200 / 300 AP je Klassifikation', () {
      expect(merkmalskenntnisApCost('Telekinese'), 100);
      expect(merkmalskenntnisApCost('Hellsicht'), 200);
      expect(merkmalskenntnisApCost('Metamagie'), 300);
    });

    test('liefert fuer jedes Katalog-Merkmal einen der drei Preise', () {
      for (final merkmal in kMerkmale) {
        expect(
          merkmalskenntnisApCost(merkmal),
          anyOf(100, 200, 300),
          reason: 'Merkmal $merkmal',
        );
      }
    });
  });

  group('Repraesentationskosten', () {
    test('erste Repraesentation kostet nichts', () {
      expect(
        repraesentationApCost(anzahlVorhanden: 0, istHalbzauberer: false),
        0,
      );
      expect(
        repraesentationApCost(anzahlVorhanden: 0, istHalbzauberer: true),
        0,
      );
    });

    test('zweite kostet 2000 AP bzw. 3000 AP', () {
      expect(
        repraesentationApCost(anzahlVorhanden: 1, istHalbzauberer: false),
        2000,
      );
      expect(
        repraesentationApCost(anzahlVorhanden: 1, istHalbzauberer: true),
        3000,
      );
    });

    test('dritte kostet Vollzauberer 4000 AP', () {
      expect(
        repraesentationApCost(anzahlVorhanden: 2, istHalbzauberer: false),
        4000,
      );
    });

    test('dritte ist fuer Halbzauberer nicht vorgesehen', () {
      expect(
        repraesentationApCost(anzahlVorhanden: 2, istHalbzauberer: true),
        isNull,
      );
    });

    test('jenseits der dritten gibt es keine Regelangabe', () {
      expect(
        repraesentationApCost(anzahlVorhanden: 3, istHalbzauberer: false),
        isNull,
      );
    });
  });

  test('Ritualkenntnis einer fremden Tradition kostet 250 AP', () {
    expect(kRitualkenntnisFremdeTraditionAp, 250);
  });
}
