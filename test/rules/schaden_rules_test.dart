import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/trefferzonen.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/schaden_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_rules.dart';

import '../test_support/hero_fixtures.dart';

// KO 14: 7 / 14 / 21 / 28.
final _stufen = computeWundschwellenStufen(ko: 14);

const _zustand = HeroState(
  currentLep: 30,
  currentAsp: 12,
  currentKap: 0,
  currentAu: 20,
);

void main() {
  group('berechneSchadenspunkte', () {
    test('zieht RS ab und wird nie negativ', () {
      expect(berechneSchadenspunkte(tp: 12, rs: 3), 9);
      expect(berechneSchadenspunkte(tp: 3, rs: 3), 0);
      expect(berechneSchadenspunkte(tp: 2, rs: 5), 0);
    });
  });

  group('schlageWundenVor', () {
    test('zählt nur echt überschrittene Stufen', () {
      final erwartet = <int, int>{
        0: 0,
        7: 0,
        8: 1,
        14: 1,
        15: 2,
        21: 2,
        22: 3,
        28: 3,
        29: 4,
        60: 4,
      };
      erwartet.forEach((sp, wunden) {
        expect(
          schlageWundenVor(sp: sp, stufen: _stufen).wunden,
          wunden,
          reason: 'SP $sp',
        );
      });
    });

    test('der Angriffsmodifikator verschiebt alle Stufen', () {
      final vorschlag = schlageWundenVor(
        sp: 13,
        stufen: _stufen,
        angriffsModifikator: -2,
      );
      expect(vorschlag.schwellen, [5, 12, 19, 26]);
      expect(vorschlag.wunden, 2);
      expect(schlageWundenVor(sp: 13, stufen: _stufen).wunden, 1);
    });

    test('Eisern hebt die Stufen über den Merkmalsbonus', () {
      final eisern = computeWundschwellenStufen(ko: 14, merkmalBonus: 2);
      expect(schlageWundenVor(sp: 8, stufen: eisern).wunden, 0);
      expect(schlageWundenVor(sp: 10, stufen: eisern).wunden, 1);
    });
  });

  group('schadensZusatzwuerfe', () {
    test('Brust: 1W6 SP je neuer Wunde', () {
      final wuerfe = schadensZusatzwuerfe(
        zone: WundZone.brust,
        bisherigeWunden: 0,
        neueWunden: 2,
      );
      expect(wuerfe, hasLength(1));
      expect(wuerfe.single.diceSpec.label, '2W6');
      expect(wuerfe.single.wirkung, TrefferzonenZusatzwirkung.schaden);
    });

    test('Kopf: INI-Malus je Wunde, dritte Wunde bringt 2W6 SP', () {
      final wuerfe = schadensZusatzwuerfe(
        zone: WundZone.kopf,
        bisherigeWunden: 1,
        neueWunden: 2,
      );
      expect(wuerfe.map((wurf) => wurf.label), [
        'INI-Malus',
        '3. Wunde: Extraschaden',
      ]);
      expect(wuerfe[0].diceSpec.label, '4W6');
      expect(wuerfe[0].wirkung, TrefferzonenZusatzwirkung.iniMalus);
      expect(wuerfe[1].diceSpec.label, '2W6');
      expect(wuerfe[1].wirkung, TrefferzonenZusatzwirkung.schaden);
    });

    test('keine dritte Wunde, wenn die Zone schon voll war', () {
      final wuerfe = schadensZusatzwuerfe(
        zone: WundZone.kopf,
        bisherigeWunden: 3,
        neueWunden: 1,
      );
      expect(wuerfe.map((wurf) => wurf.label), ['INI-Malus']);
    });

    test('ohne Wunden und für Arme/Beine keine Würfe', () {
      expect(
        schadensZusatzwuerfe(
          zone: WundZone.brust,
          bisherigeWunden: 0,
          neueWunden: 0,
        ),
        isEmpty,
      );
      for (final zone in [
        WundZone.linkerArm,
        WundZone.rechterArm,
        WundZone.linkesBein,
        WundZone.rechtesBein,
        WundZone.ruecken,
      ]) {
        expect(
          schadensZusatzwuerfe(zone: zone, bisherigeWunden: 0, neueWunden: 2),
          isEmpty,
          reason: zone.name,
        );
      }
    });
  });

  group('SchadensBuchung', () {
    test('weist widersprüchliche Angaben zurück', () {
      expect(
        () => SchadensBuchung(art: SchadensArt.lebensenergie, tp: -1, rs: 0),
        throwsArgumentError,
      );
      expect(
        () => SchadensBuchung(
          art: SchadensArt.ausdauer,
          tp: 5,
          rs: 0,
          zone: WundZone.brust,
          wunden: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => SchadensBuchung(
          art: SchadensArt.lebensenergie,
          tp: 20,
          rs: 0,
          wunden: 1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('wendeSchadenAn', () {
    test('Lebensenergie: LeP, Wunden und Zusatzschaden', () {
      final anwendung = wendeSchadenAn(
        _zustand,
        SchadensBuchung(
          art: SchadensArt.lebensenergie,
          tp: 12,
          rs: 3,
          zone: WundZone.brust,
          wunden: 1,
          zusatzSchaden: 4,
        ),
      );
      expect(anwendung.zustand.currentLep, 30 - 9 - 4);
      expect(anwendung.zustand.wpiZustand.wundenInZone(WundZone.brust), 1);
      expect(anwendung.hinzugefuegteWunden, 1);
      expect(anwendung.verfalleneWunden, 0);
      expectNurGeaendert(_zustand.toJson(), anwendung.zustand.toJson(), {
        'currentLep',
        'wpiZustand',
      });
    });

    test('negative LeP bleiben ohne Untergrenze stehen', () {
      final anwendung = wendeSchadenAn(
        _zustand.copyWith(currentLep: -3),
        SchadensBuchung(art: SchadensArt.lebensenergie, tp: 20, rs: 0),
      );
      expect(anwendung.zustand.currentLep, -23);
    });

    test('kappt Wunden an der vollen Zone', () {
      final vorher = _zustand.copyWith(
        wpiZustand: const WundZustand(
          wundenProZone: <WundZone, int>{WundZone.bauch: 2},
        ),
      );
      final anwendung = wendeSchadenAn(
        vorher,
        SchadensBuchung(
          art: SchadensArt.lebensenergie,
          tp: 30,
          rs: 0,
          zone: WundZone.bauch,
          wunden: 3,
        ),
      );
      expect(anwendung.zustand.wpiZustand.wundenInZone(WundZone.bauch), 3);
      expect(anwendung.hinzugefuegteWunden, 1);
      expect(anwendung.verfalleneWunden, 2);
    });

    test('Kopf: der INI-Wurf zählt einmal', () {
      final anwendung = wendeSchadenAn(
        _zustand.copyWith(wpiZustand: const WundZustand(kopfIniMalus: 3)),
        SchadensBuchung(
          art: SchadensArt.lebensenergie,
          tp: 20,
          rs: 0,
          zone: WundZone.kopf,
          wunden: 2,
          kopfIniWurf: 9,
        ),
      );
      final wunden = anwendung.zustand.wpiZustand;
      expect(wunden.wundenInZone(WundZone.kopf), 2);
      expect(wunden.kopfIniMalus, 12);
    });

    test('ohne Wunden bleibt der Wundzustand unberührt', () {
      final anwendung = wendeSchadenAn(
        _zustand,
        SchadensBuchung(
          art: SchadensArt.lebensenergie,
          tp: 5,
          rs: 1,
          zone: WundZone.brust,
        ),
      );
      expectNurGeaendert(_zustand.toJson(), anwendung.zustand.toJson(), {
        'currentLep',
      });
      expect(anwendung.zustand.currentLep, 26);
    });

    test('Ausdauer: nur AuP, höchstens bis 0', () {
      final anwendung = wendeSchadenAn(
        _zustand,
        SchadensBuchung(art: SchadensArt.ausdauer, tp: 9, rs: 2),
      );
      expect(anwendung.zustand.currentAu, 13);
      expectNurGeaendert(_zustand.toJson(), anwendung.zustand.toJson(), {
        'currentAu',
      });

      final leer = wendeSchadenAn(
        _zustand,
        SchadensBuchung(art: SchadensArt.ausdauer, tp: 40, rs: 0),
      );
      expect(leer.zustand.currentAu, 0);
      expect(leer.zustand.currentLep, 30);
    });
  });
}
