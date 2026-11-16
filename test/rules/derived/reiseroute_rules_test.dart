import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_adventure_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reise_station.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/ort_eintrag.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reiseroute_rules.dart';

HeroAdventureDateValue _d(String tag, String monat, String jahr) =>
    HeroAdventureDateValue(day: tag, month: monat, year: jahr);

HeroReiseStation _s(
  String id, {
  HeroAdventureDateValue datum = const HeroAdventureDateValue(),
  String adventureId = '',
  double? x,
  double? y,
}) => HeroReiseStation(
  id: id,
  ort: 'Ort $id',
  datum: datum,
  adventureId: adventureId,
  kartenX: x,
  kartenY: y,
);

HeroSheet _held({
  List<HeroAdventureEntry> adventures = const <HeroAdventureEntry>[],
  List<HeroReiseStation> stationen = const <HeroReiseStation>[],
}) => HeroSheet(
  id: 'held-1',
  name: 'Testheld',
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
  adventures: adventures,
  reiseStationen: stationen,
);

List<String> _ids(Iterable<HeroReiseStation> stationen) => [
  for (final s in stationen) s.id,
];

void main() {
  group('sortiereReiseStationen', () {
    test('ordnet nach dem Kalender über Monats- und Jahresgrenzen', () {
      final sortiert = sortiereReiseStationen([
        _s('c', datum: _d('1', 'praios', '1044')),
        _s('a', datum: _d('30', 'tsa', '1043')),
        _s('b', datum: _d('1', 'phex', '1043')),
      ]);
      expect(_ids(sortiert), ['a', 'b', 'c']);
    });

    test('Stationen ohne Datum bleiben hinter ihrem Vorgänger', () {
      final sortiert = sortiereReiseStationen([
        _s('vorn'),
        _s('spaet', datum: _d('10', 'praios', '1043')),
        _s('frueh', datum: _d('1', 'praios', '1043')),
        _s('ohne'),
      ]);
      // „ohne“ wurde nach „frueh“ erfasst und bleibt dahinter.
      expect(_ids(sortiert), ['vorn', 'frueh', 'ohne', 'spaet']);
    });

    test('gleicher Tag behält die Erfassungsreihenfolge', () {
      final sortiert = sortiereReiseStationen([
        _s('x', datum: _d('3', 'efferd', '1043 BF')),
        _s('y', datum: _d('3', 'efferd', '1043')),
      ]);
      expect(_ids(sortiert), ['x', 'y']);
    });
  });

  group('Etappen', () {
    test('Tage und Luftlinie zur vorigen Station', () {
      final etappen = reiseEtappen([
        _s('b', datum: _d('5', 'rondra', '1043'), x: 103, y: 104),
        _s('a', datum: _d('1', 'rondra', '1043'), x: 100, y: 100),
      ]);
      expect(_ids(etappen.map((e) => e.station)), ['a', 'b']);
      expect(etappen.first.nummer, 1);
      expect(etappen.first.tageSeitVorher, isNull);
      expect(etappen.last.tageSeitVorher, 4);
      // 5 Karteneinheiten zu je 3 Meilen.
      expect(etappen.last.meilenSeitVorher, closeTo(15, 1e-9));
      expect(reiseEtappenAbstandText(etappen.last), '+4 Tage · 15 Meilen');
      expect(reiseTageGesamt(etappen), 4);
    });

    test('über den Jahreswechsel mit den Namenlosen Tagen', () {
      final etappen = reiseEtappen([
        _s('a', datum: _d('30', 'rahja', '1043')),
        _s('b', datum: _d('1', 'praios', '1044')),
      ]);
      expect(etappen.last.tageSeitVorher, 6);
    });

    test('ohne Position oder Datum bleibt der Abstand offen', () {
      final etappen = reiseEtappen([
        _s('a', datum: _d('1', 'rondra', '1043')),
        _s('b'),
      ]);
      expect(etappen.last.tageSeitVorher, isNull);
      expect(etappen.last.meilenSeitVorher, isNull);
      expect(reiseEtappenAbstandText(etappen.last), isNull);
      expect(reiseTageGesamt(etappen), isNull);
    });

    test('Filter nach Abenteuer nummeriert neu', () {
      final etappen = reiseEtappen([
        _s('a', adventureId: 'eins'),
        _s('b', adventureId: 'zwei'),
        _s('c', adventureId: 'eins'),
      ], adventureId: 'eins');
      expect(_ids(etappen.map((e) => e.station)), ['a', 'c']);
      expect(etappen.last.nummer, 2);
    });
  });

  group('Vorschlag einer neuen Station', () {
    test('nimmt Standort, Datum und das laufende Abenteuer', () {
      final held = _held(
        adventures: [
          HeroAdventureEntry(
            id: 'alt',
            status: HeroAdventureStatus.completed,
            endAventurianDate: _d('1', 'praios', '1040'),
          ),
          HeroAdventureEntry(
            id: 'jetzt',
            startAventurianDate: _d('1', 'boron', '1043'),
            currentAventurianDate: _d('7', 'boron', '1043'),
          ),
        ],
      );
      final station = reiseStationVorschlag(
        held: held,
        standort: '  Gareth   Alt-Gareth ',
        id: 'neu',
      );
      expect(station.id, 'neu');
      expect(station.ort, 'Gareth Alt-Gareth');
      expect(
        [station.datum.day, station.datum.month, station.datum.year],
        ['7', 'boron', '1043'],
      );
      expect(station.adventureId, 'jetzt');
    });

    test('ohne laufendes Abenteuer bleibt die Zuordnung leer', () {
      final held = _held(
        adventures: [
          HeroAdventureEntry(
            id: 'alt',
            status: HeroAdventureStatus.completed,
            endAventurianDate: _d('1', 'praios', '1040'),
          ),
        ],
      );
      final station = reiseStationVorschlag(held: held, standort: '', id: 'n');
      expect(station.ort, isEmpty);
      expect(station.adventureId, isEmpty);
      expect(station.datum.year, '1040');
    });
  });

  group('Station beim Standortwechsel', () {
    final jetzt = DateTime.utc(2026, 11, 16, 20);

    HeroSheet? wechsel(
      HeroSheet held, {
      String alt = 'Gareth',
      String neu = 'Havena',
      List<OrtEintrag> orte = const <OrtEintrag>[],
    }) => reiseStationFuerStandortwechsel(
      held: held,
      alterStandort: alt,
      neuerStandort: neu,
      id: 'neu',
      jetzt: jetzt,
      orte: orte,
    );

    test('legt eine Station mit Datum und laufendem Abenteuer an', () {
      final held = _held(
        adventures: [
          HeroAdventureEntry(
            id: 'jetzt',
            currentAventurianDate: _d('7', 'boron', '1043'),
          ),
        ],
      );
      final neu = wechsel(held)!;
      final station = neu.reiseStationen.single;
      expect(station.id, 'neu');
      expect(station.ort, 'Havena');
      expect(station.adventureId, 'jetzt');
      expect(station.datum.year, '1043');
      expect(station.lastModified, jetzt);
      expect(station.ortId, isEmpty);
    });

    test('keine Station beim Entfernen oder ohne Ortswechsel', () {
      expect(wechsel(_held(), neu: ''), isNull);
      expect(wechsel(_held(), neu: '   '), isNull);
      expect(wechsel(_held(), alt: 'Gareth', neu: '  gareth '), isNull);
    });

    test('keine zweite Station für den Ort der letzten Station', () {
      final held = _held(
        stationen: [const HeroReiseStation(id: 'a', ort: 'Havena')],
      );
      expect(wechsel(held), isNull);
      // Ein anderer Ort legt dagegen an.
      expect(wechsel(held, neu: 'Punin')!.reiseStationen, hasLength(2));
    });

    test('trägt den Kartenverweis nur bei eindeutigem Ort', () {
      final havena = OrtEintrag(
        name: 'Havena',
        art: OrtArt.siedlung,
        ortId: 'o1',
        kartenX: 10,
        kartenY: 20,
      );
      final mit = wechsel(_held(), orte: [havena])!.reiseStationen.single;
      expect(mit.ortId, 'o1');
      expect(mit.kartenX, 10);
      expect(mit.kartenY, 20);

      final ohne = wechsel(
        _held(),
        neu: 'Punin',
        orte: [havena],
      )!.reiseStationen.single;
      expect(ohne.ortId, isEmpty);
      expect(ohne.kartenX, isNull);
    });
  });

  group('Ändern der Stationsliste', () {
    test('hinzufügen, ersetzen und entfernen', () {
      var held = _held();
      held = fuegeReiseStationHinzu(held, _s('a'));
      held = fuegeReiseStationHinzu(held, _s('b'));
      expect(_ids(held.reiseStationen), ['a', 'b']);

      held = ersetzeReiseStation(held, 'a', (s) => s.copyWith(notiz: 'N'));
      expect(held.reiseStationen.first.notiz, 'N');

      held = entferneReiseStation(held, 'a');
      expect(_ids(held.reiseStationen), ['b']);
    });

    test('eine verschwundene Station wird nicht neu angelegt', () {
      expect(
        () => ersetzeReiseStation(_held(), 'fehlt', (s) => s),
        throwsStateError,
      );
      expect(
        () => fuegeReiseStationHinzu(_held(stationen: [_s('a')]), _s('a')),
        throwsStateError,
      );
    });
  });

  group('Speicherform', () {
    test('ein Held ohne Stationen schreibt keinen Schlüssel', () {
      expect(_held().toJson().containsKey('reiseStationen'), isFalse);
    });

    test('Stationen überstehen das Speichern', () {
      final held = _held(
        stationen: [_s('a', datum: _d('1', 'rondra', '1043'), x: 1.5, y: 2)],
      );
      final geladen = HeroSheet.fromJson(held.toJson());
      final station = geladen.reiseStationen.single;
      expect(station.ort, 'Ort a');
      expect(station.datum.month, 'rondra');
      expect(station.kartenX, 1.5);
      expect(station.kartenY, 2.0);
    });
  });

  group('reiseStationAbenteuerTitel', () {
    const abenteuer = <HeroAdventureEntry>[
      HeroAdventureEntry(id: 'nebel', title: '  Die Spuren im Nebel '),
      HeroAdventureEntry(id: 'leer', title: '   '),
    ];

    test('nennt den Titel des zugeordneten Abenteuers', () {
      expect(
        reiseStationAbenteuerTitel(_s('a', adventureId: 'nebel'), abenteuer),
        'Die Spuren im Nebel',
      );
    });

    test('ohne Zuordnung gibt es keinen Titel', () {
      expect(reiseStationAbenteuerTitel(_s('a'), abenteuer), isNull);
    });

    test('ein Abenteuer ohne Titel und ein entferntes bleiben sichtbar', () {
      expect(
        reiseStationAbenteuerTitel(_s('a', adventureId: 'leer'), abenteuer),
        'Ohne Titel',
      );
      expect(
        reiseStationAbenteuerTitel(_s('a', adventureId: 'weg'), abenteuer),
        'Entferntes Abenteuer',
      );
    });
  });
}
