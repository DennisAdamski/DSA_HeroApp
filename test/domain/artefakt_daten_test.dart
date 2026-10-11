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
              variante: 'Dauerhaft',
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
      expect(daten.zauber.single.variante, 'Dauerhaft');
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
      expect(json.containsKey('pAsP'), isFalse);
    });

    test('ein Matrixgeber schreibt keine Spruchspeicher-Schlüssel', () {
      final json = const ArtefaktDaten(
        zauber: <ArtefaktZauber>[ArtefaktZauber(name: 'A')],
      ).toJson();

      for (final schluessel in [
        'ladungen',
        'aufladungen',
        'gesamtAspErschaffung',
      ]) {
        expect(json.containsKey(schluessel), isFalse, reason: schluessel);
      }
    });

    test('Ladungen, Aufladezähler und Gesamt-AsP überstehen den Rundlauf', () {
      const daten = ArtefaktDaten(
        art: ArtefaktArt.spruchspeicherAufladbar,
        aufladungen: 2,
        gesamtAspErschaffung: 75,
        ladungen: <ArtefaktLadung>[
          ArtefaktLadung(
            id: 'l1',
            verbraucht: true,
            zauber: <ArtefaktZauber>[
              ArtefaktZauber(name: 'Psychostabilis', kostenAsp: 9),
              ArtefaktZauber(name: 'Illusion auflösen', kostenAsp: 6),
            ],
          ),
          ArtefaktLadung(id: 'l2'),
        ],
      );

      final neu = ArtefaktDaten.fromJson(
        jsonDecode(jsonEncode(daten.toJson())) as Map<String, dynamic>,
      );

      expect(neu.toJson(), daten.toJson());
      expect(neu.art, ArtefaktArt.spruchspeicherAufladbar);
      expect(neu.aufladungen, 2);
      expect(neu.gesamtAspErschaffung, 75);
      expect(neu.ladungen.map((l) => l.id), ['l1', 'l2']);
      expect(neu.ladungen.first.verbraucht, isTrue);
      expect(neu.ladungen.first.zauber, hasLength(2));
      expect(neu.alleZauber.map((z) => z.name), [
        'Psychostabilis',
        'Illusion auflösen',
      ]);
    });

    test('alleZauber nennt erst die Matrix, dann die Ladungen', () {
      const daten = ArtefaktDaten(
        zauber: <ArtefaktZauber>[ArtefaktZauber(name: 'Matrix')],
        ladungen: <ArtefaktLadung>[
          ArtefaktLadung(
            id: 'l',
            zauber: <ArtefaktZauber>[ArtefaktZauber(name: 'Ladung')],
          ),
        ],
      );

      expect(daten.alleZauber.map((z) => z.name), ['Matrix', 'Ladung']);
    });

    test('ein unbekanntes Feld der Ladung bleibt erhalten', () {
      final ladung = ArtefaktLadung.fromJson(<String, dynamic>{
        'id': 'l',
        'zukunft': 7,
      });

      expect(ladung.unbekannteFelder, {'zukunft': 7});
      expect(ladung.copyWith(verbraucht: true).toJson()['zukunft'], 7);
    });

    test('eine Ladung ohne Angaben fällt tolerant zurück', () {
      final daten = ArtefaktDaten.fromJson(<String, dynamic>{
        'ladungen': <Object>[
          <String, dynamic>{'zauber': 'kein Array'},
          'kein Objekt',
        ],
        'aufladungen': 'x',
      });

      expect(daten.ladungen, hasLength(1));
      expect(daten.ladungen.single.id, '');
      expect(daten.ladungen.single.zauber, isEmpty);
      expect(daten.aufladungen, 0);
    });

    test('permanente AsP je Zauber überstehen den Rundlauf', () {
      const zauber = ArtefaktZauber(name: 'Gardianum', pAsP: 3);

      final neu = ArtefaktZauber.fromJson(
        jsonDecode(jsonEncode(zauber.toJson())) as Map<String, dynamic>,
      );

      expect(neu.pAsP, 3);
      expect(neu.toJson(), zauber.toJson());
      expect(neu.copyWith(pAsP: null).pAsP, isNull);
      expect(neu.copyWith(name: 'x').pAsP, 3);
      expect(neu.unbekannteFelder, isEmpty);
    });
  });
}
