import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/domain/zustands_buchung.dart';
import 'package:dsa_heldenverwaltung/rules/derived/schaden_ruecknahme_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/schaden_rules.dart';

final _zeit = DateTime.utc(2026, 10, 7, 12);
final _spaeter = DateTime.utc(2026, 10, 7, 13);

const _start = HeroState(
  currentLep: 30,
  currentAsp: 0,
  currentKap: 0,
  currentAu: 30,
);

/// Bucht [buchung] wie der Ablauf: anwenden und die Buchung vermerken.
HeroState _bucheTreffer(
  HeroState vorher,
  SchadensBuchung buchung, {
  String id = 'treffer',
}) {
  final anwendung = wendeSchadenAn(vorher, buchung);
  return anwendung.zustand.withBuchung(
    schadensBuchungAus(
      vorher: vorher,
      anwendung: anwendung,
      buchung: buchung,
      id: id,
      zeitpunkt: _zeit,
    ),
  );
}

SchadensRuecknahmePlan _plan(HeroState zustand, [String id = 'treffer']) {
  final pruefung = planeSchadensRuecknahme(zustand, id);
  expect(pruefung, isA<RuecknahmeMoeglich>());
  return (pruefung as RuecknahmeMoeglich).plan;
}

HeroState _nimmZurueck(HeroState zustand, [String id = 'treffer']) {
  return wendeSchadensRuecknahmeAn(
    zustand,
    _plan(zustand, id),
    gegenbuchungId: 'gegen-$id',
    zeitpunkt: _spaeter,
  );
}

void main() {
  group('Buchung festhalten', () {
    test('die Deltas sind die tatsächlichen Änderungen', () {
      final nachher = _bucheTreffer(
        _start.copyWith(currentAu: 3),
        SchadensBuchung(art: SchadensArt.ausdauer, tp: 12, rs: 2),
      );
      final buchung = nachher.buchungen.single;

      expect(buchung.art, ZustandsBuchungsArt.schaden);
      // SP(A) 10, aber nur 3 AuP vorhanden.
      expect(buchung.auDelta, -3);
      expect(buchung.lepDelta, -5);
      expect(buchung.wundenDelta, 0);
      expect(buchung.zone, isNull);
    });

    test('Wunden zählen nur, soweit die Zone Platz hatte', () {
      final vorher = _start.copyWith(
        wpiZustand: const WundZustand(
          wundenProZone: <WundZone, int>{WundZone.brust: 2},
        ),
      );
      final nachher = _bucheTreffer(
        vorher,
        SchadensBuchung(
          art: SchadensArt.lebensenergie,
          tp: 20,
          rs: 0,
          zone: WundZone.brust,
          wunden: 3,
        ),
      );

      expect(nachher.buchungen.single.wundenDelta, 1);
      expect(nachher.buchungen.single.zone, WundZone.brust);
    });
  });

  group('Rücknahme', () {
    test('stellt LeP, Zusatzschaden und Wunden wieder her', () {
      final getroffen = _bucheTreffer(
        _start,
        SchadensBuchung(
          art: SchadensArt.lebensenergie,
          tp: 14,
          rs: 3,
          zone: WundZone.bauch,
          wunden: 2,
          zusatzSchaden: 4,
        ),
      );
      expect(getroffen.currentLep, 30 - 11 - 4);

      final zurueck = _nimmZurueck(getroffen);

      expect(zurueck.currentLep, 30);
      expect(zurueck.wpiZustand.wundenInZone(WundZone.bauch), 0);
      final gegen = zurueck.buchungen.last;
      expect(gegen.art, ZustandsBuchungsArt.schadenRuecknahme);
      expect(gegen.ruecknahmeVon, 'treffer');
      expect(gegen.lepDelta, 15);
      expect(gegen.wundenDelta, -2);
      expect(gegen.zeitpunkt, _spaeter);
    });

    test('TP(A) gibt nur die tatsächlich abgezogenen AuP zurück', () {
      final getroffen = _bucheTreffer(
        _start.copyWith(currentAu: 3),
        SchadensBuchung(art: SchadensArt.ausdauer, tp: 12, rs: 2),
      );

      final zurueck = _nimmZurueck(getroffen);

      expect(zurueck.currentAu, 3);
      expect(zurueck.currentLep, 30);
    });

    test('zwischenzeitliche Heilung bleibt, LeP dürfen über das Maximum', () {
      final getroffen = _bucheTreffer(
        _start,
        SchadensBuchung(art: SchadensArt.lebensenergie, tp: 10, rs: 0),
      );
      final geheilt = getroffen.copyWith(currentLep: 30, currentAsp: 7);

      final zurueck = _nimmZurueck(geheilt);

      expect(zurueck.currentLep, 40);
      expect(zurueck.currentAsp, 7);
    });

    test('bereits geheilte Wunden werden gemeldet, nicht doppelt entfernt', () {
      final getroffen = _bucheTreffer(
        _start,
        SchadensBuchung(
          art: SchadensArt.lebensenergie,
          tp: 20,
          rs: 0,
          zone: WundZone.linkerArm,
          wunden: 2,
        ),
      );
      final teilGeheilt = getroffen.copyWith(
        wpiZustand: getroffen.wpiZustand.mitWundeEntfernt(WundZone.linkerArm),
      );

      final plan = _plan(teilGeheilt);
      expect(plan.wundenEntfernt, 1);
      expect(plan.wundenNichtMehrVorhanden, 1);
      expect(
        _nimmZurueck(teilGeheilt).wpiZustand.wundenInZone(WundZone.linkerArm),
        0,
      );

      final ganzGeheilt = teilGeheilt.copyWith(wpiZustand: const WundZustand());
      expect(_plan(ganzGeheilt).wundenEntfernt, 0);
      expect(_plan(ganzGeheilt).wundenNichtMehrVorhanden, 2);
    });

    test('Wunden aus anderen Treffern derselben Zone bleiben', () {
      final vorher = _start.copyWith(
        wpiZustand: const WundZustand(
          wundenProZone: <WundZone, int>{WundZone.brust: 1},
          unterdrueckteWundenProZone: <WundZone, int>{WundZone.brust: 1},
        ),
      );
      final getroffen = _bucheTreffer(
        vorher,
        SchadensBuchung(
          art: SchadensArt.lebensenergie,
          tp: 20,
          rs: 0,
          zone: WundZone.brust,
          wunden: 1,
        ),
      );

      final zurueck = _nimmZurueck(getroffen);

      // Die ältere, unterdrückte Wunde bleibt samt Unterdrückung.
      expect(zurueck.wpiZustand.wundenInZone(WundZone.brust), 1);
      expect(zurueck.wpiZustand.unterdrueckteInZone(WundZone.brust), 1);
    });

    test('eine vermerkte Unterdrückung des Treffers entfällt mit ihm', () {
      final getroffen = _bucheTreffer(
        _start.copyWith(
          wpiZustand: const WundZustand(
            wundenProZone: <WundZone, int>{WundZone.brust: 1},
          ),
        ),
        SchadensBuchung(
          art: SchadensArt.lebensenergie,
          tp: 20,
          rs: 0,
          zone: WundZone.brust,
          wunden: 2,
        ),
      );
      final unterdrueckt = vermerkeUnterdrueckung(
        getroffen.copyWith(
          wpiZustand: getroffen.wpiZustand.mitUnterdrueckung(WundZone.brust, 2),
        ),
        'treffer',
        2,
      );
      expect(unterdrueckt.buchungen.single.unterdrueckt, 2);

      final zurueck = _nimmZurueck(unterdrueckt);

      expect(zurueck.wpiZustand.wundenInZone(WundZone.brust), 1);
      expect(zurueck.wpiZustand.unterdrueckteInZone(WundZone.brust), 0);
    });

    test('der Kopf-INI-Malus sinkt um den Wurf und mit der letzten Kopfwunde '
        'auf 0', () {
      final vorher = _start.copyWith(
        wpiZustand: const WundZustand(
          wundenProZone: <WundZone, int>{WundZone.kopf: 1},
          kopfIniMalus: 5,
        ),
      );
      final getroffen = _bucheTreffer(
        vorher,
        SchadensBuchung(
          art: SchadensArt.lebensenergie,
          tp: 30,
          rs: 0,
          zone: WundZone.kopf,
          wunden: 2,
          kopfIniWurf: 9,
        ),
      );
      expect(getroffen.wpiZustand.kopfIniMalus, 14);

      final voll = _nimmZurueck(getroffen);
      expect(voll.wpiZustand.kopfIniMalus, 5);
      expect(voll.buchungen.last.kopfIniMalusDelta, -9);

      // Eine Kopfwunde ist inzwischen geheilt: Die Rücknahme entfernt die
      // beiden übrigen, der Kopf ist frei und der Malus entfällt ganz.
      final teil = getroffen.copyWith(
        wpiZustand: getroffen.wpiZustand.mitWundeEntfernt(WundZone.kopf),
      );
      expect(_plan(teil).wundenEntfernt, 2);
      expect(_nimmZurueck(teil).wpiZustand.kopfIniMalus, 0);

      // Mit der letzten Kopfwunde entfällt der Malus ganz.
      final letzte = _bucheTreffer(
        _start,
        SchadensBuchung(
          art: SchadensArt.lebensenergie,
          tp: 30,
          rs: 0,
          zone: WundZone.kopf,
          wunden: 1,
          kopfIniWurf: 4,
        ),
      );
      final mitFremdMalus = letzte.copyWith(
        wpiZustand: letzte.wpiZustand.copyWith(kopfIniMalus: 6),
      );
      expect(_nimmZurueck(mitFremdMalus).wpiZustand.kopfIniMalus, 0);
    });

    test('eine Zone einer neueren App-Version lässt die Wunden stehen', () {
      final buchung = ZustandsBuchung.fromJson(<String, dynamic>{
        'id': 'treffer',
        'art': 'schaden',
        'zeitpunkt': _zeit.toIso8601String(),
        'lepDelta': -6,
        'zone': 'schwanz',
        'wundenDelta': 1,
      });
      final zustand = _start.copyWith(currentLep: 24).withBuchung(buchung);

      final plan = _plan(zustand);
      expect(plan.zoneUnbekannt, isTrue);
      expect(plan.wundenEntfernt, 0);
      expect(_nimmZurueck(zustand).currentLep, 30);
    });
  });

  group('Grenzen der Rücknahme', () {
    late HeroState getroffen;

    setUp(() {
      getroffen = _bucheTreffer(
        _start,
        SchadensBuchung(art: SchadensArt.lebensenergie, tp: 8, rs: 0),
      );
    });

    test('eine Buchung lässt sich nur einmal zurücknehmen', () {
      final zurueck = _nimmZurueck(getroffen);

      expect(
        planeSchadensRuecknahme(zurueck, 'treffer'),
        isA<RuecknahmeUnmoeglich>().having(
          (u) => u.hindernis,
          'hindernis',
          RuecknahmeHindernis.bereitsZurueckgenommen,
        ),
      );
      expect(
        schadensBuchungsStatus(zurueck, 'treffer'),
        SchadensBuchungsStatus.zurueckgenommen,
      );
    });

    test('die Gegenbuchung selbst ist nicht zurücknehmbar', () {
      final zurueck = _nimmZurueck(getroffen);

      expect(
        planeSchadensRuecknahme(zurueck, 'gegen-treffer'),
        isA<RuecknahmeUnmoeglich>().having(
          (u) => u.hindernis,
          'hindernis',
          RuecknahmeHindernis.keineSchadensbuchung,
        ),
      );
      expect(
        schadensBuchungsStatus(zurueck, 'gegen-treffer'),
        SchadensBuchungsStatus.keine,
      );
    });

    test(
      'eine unbekannte oder verdrängte Buchung ist nicht mehr verfügbar',
      () {
        expect(
          planeSchadensRuecknahme(getroffen, 'fehlt'),
          isA<RuecknahmeUnmoeglich>().having(
            (u) => u.hindernis,
            'hindernis',
            RuecknahmeHindernis.nichtGefunden,
          ),
        );
        expect(
          schadensBuchungsStatus(getroffen, 'fehlt'),
          SchadensBuchungsStatus.nichtMehrVerfuegbar,
        );
        expect(
          schadensBuchungsStatus(getroffen, null),
          SchadensBuchungsStatus.keine,
        );

        var voll = getroffen;
        for (var i = 0; i < HeroState.buchungenMax; i++) {
          voll = _bucheTreffer(
            voll,
            SchadensBuchung(art: SchadensArt.lebensenergie, tp: 1, rs: 0),
            id: 'weitere-$i',
          );
        }
        expect(voll.buchungen, hasLength(HeroState.buchungenMax));
        expect(
          schadensBuchungsStatus(voll, 'treffer'),
          SchadensBuchungsStatus.nichtMehrVerfuegbar,
        );
      },
    );

    test('eine Buchung unbekannter Art ist nie zurücknehmbar', () {
      final fremd = ZustandsBuchung.fromJson(<String, dynamic>{
        'id': 'fremd',
        'art': 'kuenftigeArt',
        'zeitpunkt': _zeit.toIso8601String(),
        'lepDelta': -3,
      });
      final zustand = _start.withBuchung(fremd);

      expect(
        schadensBuchungsStatus(zustand, 'fremd'),
        SchadensBuchungsStatus.keine,
      );
      expect(
        planeSchadensRuecknahme(zustand, 'fremd'),
        isA<RuecknahmeUnmoeglich>(),
      );
    });
  });
}
