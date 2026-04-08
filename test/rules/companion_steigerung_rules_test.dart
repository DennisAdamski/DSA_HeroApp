import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/learn/learn_complexity.dart';
import 'package:dsa_heldenverwaltung/rules/derived/companion_steigerung_rules.dart';

void main() {
  group('companionApVerfuegbar', () {
    test('berechnet aus apGesamt minus apAusgegeben', () {
      const c = HeroCompanion(id: 'a', apGesamt: 100, apAusgegeben: 30);
      expect(companionApVerfuegbar(c), 70);
    });

    test('ergibt 0 bei null-Werten', () {
      const c = HeroCompanion(id: 'a');
      expect(companionApVerfuegbar(c), 0);
    });
  });

  group('poolMaxSteigerung', () {
    test('1.5 × 20 = 30', () {
      expect(poolMaxSteigerung(20), 30);
    });

    test('1.5 × 7 = 10 (floor)', () {
      expect(poolMaxSteigerung(7), 10);
    });

    test('1.5 × 0 = 0', () {
      expect(poolMaxSteigerung(0), 0);
    });

    test('1.5 × 1 = 1 (floor)', () {
      expect(poolMaxSteigerung(1), 1);
    });
  });

  group('regMaxSteigerung', () {
    test('bei 0 AP bleibt aktueller Wert', () {
      expect(
        regMaxSteigerung(aktuellerSteigerungswert: 0, verfuegbareAp: 0),
        0,
      );
    });

    test('genau eine Stufe bei exaktem AP-Wert', () {
      // Erster Schritt bei F kostet 6 AP.
      expect(
        regMaxSteigerung(aktuellerSteigerungswert: 0, verfuegbareAp: 6),
        1,
      );
    });

    test('nicht genug AP fuer naechsten Schritt', () {
      // Schritt 0->1 kostet 6, 1->2 kostet 14 => braucht 20 fuer 2.
      expect(
        regMaxSteigerung(aktuellerSteigerungswert: 0, verfuegbareAp: 19),
        1,
      );
    });

    test('mehrere Stufen bei ausreichend AP', () {
      // 0->1: 6, 1->2: 14, 2->3: 22 => 42 AP fuer 3 Stufen.
      expect(
        regMaxSteigerung(aktuellerSteigerungswert: 0, verfuegbareAp: 42),
        3,
      );
    });
  });

  group('kVertrauterKomplexitaet', () {
    test('ist LearnCost.f', () {
      expect(kVertrauterKomplexitaet, LearnCost.f);
    });
  });

  group('companionEffektivwert', () {
    test('addiert Basiswert und Steigerung', () {
      const c = HeroCompanion(
        id: 'a',
        mu: 12,
        steigerungen: {'mu': 3},
      );
      expect(companionEffektivwert(c, 'mu'), 15);
    });

    test('ohne Steigerung gibt Basiswert zurueck', () {
      const c = HeroCompanion(id: 'a', ge: 14);
      expect(companionEffektivwert(c, 'ge'), 14);
    });

    test('gibt null fuer nicht definierte Eigenschaft', () {
      const c = HeroCompanion(id: 'a');
      expect(companionEffektivwert(c, 'mu'), isNull);
    });
  });

  group('companionEffektiverPoolwert', () {
    test('nutzt startLep + Steigerung', () {
      const c = HeroCompanion(
        id: 'a',
        maxLep: 25,
        startLep: 20,
        steigerungen: {'lep': 5},
      );
      expect(companionEffektiverPoolwert(c, 'lep'), 25);
    });

    test('faellt auf maxLep zurueck wenn startLep null', () {
      const c = HeroCompanion(
        id: 'a',
        maxLep: 20,
        steigerungen: {'lep': 3},
      );
      expect(companionEffektiverPoolwert(c, 'lep'), 23);
    });

    test('MR nutzt startMr', () {
      const c = HeroCompanion(
        id: 'a',
        magieresistenz: 4,
        startMr: 4,
        steigerungen: {'mr': 2},
      );
      expect(companionEffektiverPoolwert(c, 'mr'), 6);
    });

    test('gibt null wenn kein Basiswert gesetzt', () {
      const c = HeroCompanion(id: 'a');
      expect(companionEffektiverPoolwert(c, 'asp'), isNull);
    });

    test('AuP nutzt startAup + Steigerung', () {
      const c = HeroCompanion(
        id: 'a',
        maxAup: 30,
        startAup: 25,
        steigerungen: {'aup': 4},
      );
      expect(companionEffektiverPoolwert(c, 'aup'), 29);
    });

    test('AuP faellt auf maxAup zurueck wenn startAup null', () {
      const c = HeroCompanion(
        id: 'a',
        maxAup: 20,
        steigerungen: {'aup': 2},
      );
      expect(companionEffektiverPoolwert(c, 'aup'), 22);
    });

    test('AuP gibt null wenn kein Basiswert gesetzt', () {
      const c = HeroCompanion(id: 'a');
      expect(companionEffektiverPoolwert(c, 'aup'), isNull);
    });
  });

  group('companionEffektiverRk', () {
    test('addiert Basis-RK und Steigerung', () {
      const c = HeroCompanion(
        id: 'a',
        steigerungen: {'rk': 3},
      );
      expect(companionEffektiverRk(c, 5), 8);
    });

    test('ohne Steigerung gibt Basis-RK zurueck', () {
      const c = HeroCompanion(id: 'a');
      expect(companionEffektiverRk(c, 7), 7);
    });
  });

  group('companionPoolStartwert', () {
    test('liest startAup', () {
      const c = HeroCompanion(id: 'a', startAup: 18);
      expect(companionPoolStartwert(c, 'aup'), 18);
    });

    test('gibt null fuer unbekannten Key', () {
      const c = HeroCompanion(id: 'a');
      expect(companionPoolStartwert(c, 'xyz'), isNull);
    });
  });

  group('companionPoolBasiswert', () {
    test('liest maxAup', () {
      const c = HeroCompanion(id: 'a', maxAup: 22);
      expect(companionPoolBasiswert(c, 'aup'), 22);
    });
  });
}
