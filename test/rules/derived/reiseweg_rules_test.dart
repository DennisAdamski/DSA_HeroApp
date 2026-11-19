import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/avesmaps_route.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reise_station.dart';
import 'package:dsa_heldenverwaltung/rules/derived/karten_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reiseroute_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reiseweg_rules.dart';

const String _a = '80558060-4299-54aa-b520-814b10819885';
const String _b = '194cd8ed-9aff-57af-b658-ff353ac883a7';

HeroReiseStation _station(
  String id,
  String ortId, {
  String tag = '1',
  HeroReiseAnreise? anreise,
}) => HeroReiseStation(
  id: id,
  ort: id,
  ortId: ortId,
  kartenX: ortId.isEmpty ? null : 500,
  kartenY: ortId.isEmpty ? null : 500,
  datum: HeroAdventureDateValue(day: tag, month: 'praios', year: '1040'),
  anreise: anreise,
);

const AvesmapsRoute _weg = AvesmapsRoute(
  gefunden: true,
  meilen: 341.45,
  reisestunden: 68.39,
  reisetage: 5.78,
  etappen: <AvesmapsRoutenEtappe>[
    AvesmapsRoutenEtappe(art: 'Strasse', meilen: 4.8),
    AvesmapsRoutenEtappe(art: 'Flussweg', meilen: 334),
    AvesmapsRoutenEtappe(art: 'Umsteigen', meilen: 2.3),
    AvesmapsRoutenEtappe(art: 'Teleport', meilen: 1),
  ],
  linie: <(double, double)>[(500, 500), (510, 505), (520, 500)],
);

void main() {
  group('Anfrage je Etappe', () {
    test('braucht beide Kennungen und verschiedene Orte', () {
      final etappen = reiseEtappen(<HeroReiseStation>[
        _station('s1', _a),
        _station('s2', _b, tag: '5'),
        _station('s3', '', tag: '7'),
        _station('s4', _b, tag: '9'),
      ]);
      expect(reisewegAnfrageFuer(etappen[0]), isNull);
      expect(
        reisewegAnfrageFuer(etappen[1])!.schluessel,
        '$_a|$_b|alle|schnellste',
      );
      expect(reisewegAnfrageFuer(etappen[2]), isNull);
      expect(reisewegAnfrageFuer(etappen[3]), isNull);
      expect(reisewegAnfragen(etappen), hasLength(1));
    });

    test('nutzt die Anreise der Zielstation', () {
      final etappen = reiseEtappen(<HeroReiseStation>[
        _station('s1', _a),
        _station(
          's2',
          _b,
          tag: '5',
          anreise: const HeroReiseAnreise(
            wege: <String>['land', 'zukunft'],
            optimierung: 'kuerzeste',
          ),
        ),
      ]);
      final anfrage = reisewegAnfrageFuer(etappen[1])!;
      expect(anfrage.wege, <String>['land']);
      expect(anfrage.optimierung, kReiseOptimierungKuerzeste);
    });
  });

  group('Anreise', () {
    test('die Vorgabe ergibt kein Feld', () {
      expect(
        anreiseAus(wege: kReiseWegArten, optimierung: 'schnellste'),
        isNull,
      );
      final nurLand = anreiseAus(wege: <String>['land'], optimierung: '')!;
      expect(nurLand.toJson(), <String, Object?>{
        'wege': <String>['land'],
      });
      final kurz = anreiseAus(wege: kReiseWegArten, optimierung: 'kuerzeste')!;
      expect(kurz.toJson(), <String, Object?>{'optimierung': 'kuerzeste'});
    });

    test('Texte', () {
      expect(anreiseText(null), 'Schnellster Weg');
      expect(
        anreiseText(
          const HeroReiseAnreise(
            wege: <String>['fluss', 'land'],
            optimierung: 'kuerzeste',
          ),
        ),
        'Kürzester Weg · nur Land und Fluss',
      );
    });

    test('Station schreibt die Anreise nur bei Belegung', () {
      final ohne = _station('s1', _a).toJson();
      expect(ohne.containsKey('anreise'), isFalse);
      final mit = _station(
        's1',
        _a,
        anreise: const HeroReiseAnreise(wege: <String>['see']),
      ).toJson();
      expect(mit['anreise'], <String, Object?>{
        'wege': <String>['see'],
      });
      expect(HeroReiseStation.fromJson(mit).anreise!.wege, <String>['see']);
    });
  });

  group('Texte zum Weg', () {
    test('Wegarten nach Anteil, Umsteigen und Unbekanntes entfallen', () {
      expect(reisewegArten(_weg), <String>['Fluss', 'Straße']);
      expect(reisewegZuWasser(_weg), isTrue);
      expect(reisewegText(_weg), '341 Meilen · 5¾ Reisetage · Fluss, Straße');
      expect(
        reisewegText(const AvesmapsRoute.nichtGefunden('kein_zusammenhang')),
        'Avesmaps findet keinen Weg mit diesen Vorgaben.',
      );
    });

    test('Reisezeit in Vierteltagen oder Stunden', () {
      String zeit(double tage, [double stunden = 0]) => formatiereReisezeit(
        AvesmapsRoute(gefunden: true, reisetage: tage, reisestunden: stunden),
      );
      expect(zeit(.2, 1.6), '2 Reisestunden');
      expect(zeit(.2, .2), '1 Reisestunde');
      expect(zeit(.5), '½ Reisetag');
      expect(zeit(1.05), '1 Reisetag');
      expect(zeit(2.6), '2½ Reisetage');
      expect(zeit(3), '3 Reisetage');
    });

    test('Abstand nennt Weg statt Luftlinie', () {
      final etappen = reiseEtappen(<HeroReiseStation>[
        _station('s1', _a),
        _station('s2', _b, tag: '10').copyWith(kartenX: 600.0),
      ]);
      expect(
        reiseEtappenAbstandText(etappen[1]),
        '+9 Tage · 300 Meilen Luftlinie',
      );
      expect(
        reiseEtappenAbstandText(etappen[1], weg: _weg),
        '+9 Tage · 341 Meilen · 5¾ Reisetage',
      );
    });
  });

  test('Kartenpunkte tragen den gemerkten Weg', () {
    final etappen = reiseEtappen(<HeroReiseStation>[
      _station('s1', _a),
      _station('s2', _b, tag: '5'),
    ]);
    final schluessel = reisewegAnfrageFuer(etappen[1])!.schluessel;
    final punkte = kartenRoutenPunkte(
      etappen,
      wege: <String, AvesmapsRoute>{schluessel: _weg},
    );
    expect(punkte.first.linie, isNull);
    expect(punkte.last.linie, hasLength(3));
    expect(kartenRoutenPunkte(etappen).last.linie, isNull);
  });
}
