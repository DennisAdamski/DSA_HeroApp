import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/artefakt_daten.dart';
import 'package:dsa_heldenverwaltung/domain/hero_inventory_entry.dart';

void main() {
  group('HeroInventoryEntry.artefaktDaten', () {
    test('ohne Artefaktdaten schreibt der Eintrag den Schlüssel nicht', () {
      final json = const HeroInventoryEntry(gegenstand: 'Seil').toJson();

      expect(json.containsKey('artefaktDaten'), isFalse);
      expect(HeroInventoryEntry.fromJson(json).artefaktDaten, isNull);
    });

    test('Roundtrip erhält alle Angaben des Matrixgebers', () {
      const eintrag = HeroInventoryEntry(
        gegenstand: 'Armschiene',
        isMagisch: true,
        artefaktDaten: ArtefaktDaten(
          stabilitaet: MatrixStabilitaet.sehrStabil,
          regelfassung: MatrixRegelfassung.staebeRinge2011,
          ersteller: 'Meister Okharim',
          ausloeser: 'Schlüsselwort',
          ausloeserAktionen: 2,
          pAsP: 4,
          defekt: true,
          zauber: <ArtefaktZauber>[
            ArtefaktZauber(
              spellId: 'spell_armatrutz',
              name: 'Armatrutz',
              repraesentation: 'Mag',
              zfw: 12,
              zfpStern: 7,
              kostenAsp: 8,
              reichweite: 'Selbst',
              wirkungsdauer: '1 Stunde',
              zielHinweis: 'Träger',
              spontaneModifikation: 'Kosten einsparen',
              notiz: 'x',
            ),
          ],
        ),
      );

      final neu = HeroInventoryEntry.fromJson(
        jsonDecode(jsonEncode(eintrag.toJson())) as Map<String, dynamic>,
      );

      expect(neu.toJson(), eintrag.toJson());
      final daten = neu.artefaktDaten!;
      expect(daten.stabilitaet, MatrixStabilitaet.sehrStabil);
      expect(daten.regelfassung, MatrixRegelfassung.staebeRinge2011);
      expect(daten.defekt, isTrue);
      expect(daten.pAsP, 4);
      expect(daten.zauber.single.repraesentation, 'Mag');
      expect(daten.zauber.single.zfpStern, 7);
    });

    test('copyWith ändert die Artefaktdaten und kann sie entfernen', () {
      const eintrag = HeroInventoryEntry(artefaktDaten: ArtefaktDaten());

      final ohne = eintrag.copyWith(artefaktDaten: null);
      final gleich = eintrag.copyWith(gegenstand: 'Ring');

      expect(ohne.artefaktDaten, isNull);
      expect(ohne.toJson().containsKey('artefaktDaten'), isFalse);
      expect(gleich.artefaktDaten, isNotNull);
    });
  });

  group('ArtefaktDaten', () {
    test('Standardwerte entsprechen der Wege-der-Alchimie-Fassung', () {
      const daten = ArtefaktDaten();

      expect(daten.art, ArtefaktArt.matrixgeber);
      expect(daten.stabilitaet, MatrixStabilitaet.stabil);
      expect(daten.regelfassung, MatrixRegelfassung.alchimie2012);
      expect(daten.ausloeserAktionen, 1);
      expect(daten.defekt, isFalse);
    });

    test('fehlende Felder und falsche Typen fallen tolerant zurück', () {
      final daten = ArtefaktDaten.fromJson(<String, dynamic>{
        'zauber': 'kein Array',
        'ausloeserAktionen': 'x',
      });

      expect(daten.zauber, isEmpty);
      expect(daten.ausloeserAktionen, 1);
      expect(daten.pAsP, isNull);
    });

    test('ein Zauber ohne Zahlen schreibt sie nicht', () {
      final json = const ArtefaktZauber(name: 'Flim Flam').toJson();

      expect(json.containsKey('zfw'), isFalse);
      expect(json.containsKey('zfpStern'), isFalse);
      expect(json.containsKey('kostenAsp'), isFalse);
      expect(json.containsKey('spellId'), isFalse);
    });
  });
}
