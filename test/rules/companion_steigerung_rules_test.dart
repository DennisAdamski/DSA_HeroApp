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

  group('vertrautenGrenze (WdZ S. 125: höchstens 1,5 × Startwert)', () {
    test('1,5 × 20 = 30, Zuwachs höchstens 10', () {
      expect(vertrautenGrenze(20), 30);
      expect(vertrautenMaxStandUeber(20), 10);
    });

    test('1,5 × 7 = 10 (abgerundet), Zuwachs 3', () {
      expect(vertrautenGrenze(7), 10);
      expect(vertrautenMaxStandUeber(7), 3);
    });

    test('Startwert 0 und 1 lassen keinen Zuwachs', () {
      expect(vertrautenMaxStandUeber(0), 0);
      expect(vertrautenMaxStandUeber(1), 0);
    });
  });

  group('vertrautenMaxStand', () {
    const katze = HeroCompanion(
      id: 'k',
      typ: BegleiterTyp.vertrauter,
      mu: 8,
      ini: 13,
      loyalitaet: 15,
      maxLep: 11,
      startLep: 11,
      maxAsp: 5,
      startAsp: 5,
      maxAup: 45,
      magieresistenz: 4,
      startMr: 4,
    );

    test('Eigenschaften bis 1,5 × Grundwert', () {
      expect(vertrautenMaxStand(katze, 'mu'), 4);
    });

    test('LeP und MR bis 1,5 × Startwert insgesamt', () {
      expect(vertrautenMaxStand(katze, 'lep'), 5);
      expect(vertrautenMaxStand(katze, 'mr'), 2);
    });

    test('AsP und RK sind unbegrenzt', () {
      expect(vertrautenMaxStand(katze, 'asp'), isNull);
      expect(vertrautenMaxStand(katze, 'rk'), isNull);
    });

    test('INI, Loyalität und AuP sind nicht steigerbar', () {
      for (final key in ['ini', 'loyalitaet', 'aup']) {
        expect(vertrautenWertSteigerbar(key), isFalse, reason: key);
        expect(vertrautenMaxStand(katze, key), 0, reason: key);
      }
    });
  });

  group('vertrautenSteigerungshinweis', () {
    test('Altbuchung auf nicht steigerbarem Wert bleibt mit Hinweis', () {
      const c = HeroCompanion(id: 'a', ini: 10, steigerungen: {'ini': 2});
      expect(companionEffektivwert(c, 'ini'), 12);
      expect(vertrautenSteigerungshinweis(c, 'ini'), contains('+2 bleiben'));
    });

    test('Altbuchung über der Grenze bleibt mit Hinweis', () {
      const c = HeroCompanion(
        id: 'a',
        maxLep: 10,
        startLep: 10,
        steigerungen: {'lep': 9},
      );
      expect(companionEffektiverPoolwert(c, 'lep'), 19);
      expect(vertrautenSteigerungshinweis(c, 'lep'), contains('höchstens +5'));
    });

    test('regelkonformer Stand ohne Hinweis', () {
      const c = HeroCompanion(id: 'a', mu: 10, steigerungen: {'mu': 5});
      expect(vertrautenSteigerungshinweis(c, 'mu'), isNull);
    });
  });

  group('steigereBegleiter prüft die WdZ-Grenzen', () {
    const c = HeroCompanion(
      id: 'a',
      mu: 10,
      ini: 10,
      apGesamt: 1000,
      angriffe: [HeroCompanionAttack(id: 'biss', at: 10, pa: 4)],
      geschwindigkeiten: [
        HeroCompanionSpeed(art: 'Boden', wert: 1),
        HeroCompanionSpeed(art: 'Fliegen', wert: 12),
      ],
    );

    test('weist Steigerung über 1,5 × ab', () {
      expect(
        () => steigereBegleiter(
          c,
          ziel: const BegleiterSteigerungsziel.wert('mu'),
          erwarteterStand: 0,
          neuerStand: 6,
          apKosten: 1,
        ),
        throwsStateError,
      );
    });

    test('weist nicht steigerbare Werte ab', () {
      expect(
        () => steigereBegleiter(
          c,
          ziel: const BegleiterSteigerungsziel.wert('ini'),
          erwarteterStand: 0,
          neuerStand: 1,
          apKosten: 1,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('nicht steigerbar'),
          ),
        ),
      );
    });

    test('AT bis 1,5 × Grundwert', () {
      final ergebnis = steigereBegleiter(
        c,
        ziel: const BegleiterSteigerungsziel.angriff('biss', parade: false),
        erwarteterStand: 0,
        neuerStand: 5,
        apKosten: 100,
      );
      expect(begleiterAngriffAt(ergebnis.angriffe.single), 15);
      expect(ergebnis.apAusgegeben, 100);
    });

    test('GS steigt je Bewegungsart', () {
      final ergebnis = steigereBegleiter(
        c,
        ziel: const BegleiterSteigerungsziel.geschwindigkeit('Fliegen'),
        erwarteterStand: 0,
        neuerStand: 2,
        apKosten: 50,
      );
      expect(begleiterTempo(ergebnis.geschwindigkeiten[1]), 14);
      expect(ergebnis.geschwindigkeiten[0].steigerung, 0);
      expect(
        () => steigereBegleiter(
          c,
          ziel: const BegleiterSteigerungsziel.geschwindigkeit('Boden'),
          erwarteterStand: 0,
          neuerStand: 1,
          apKosten: 1,
        ),
        throwsStateError,
        reason: 'GS 1 lässt keinen Zuwachs (⌊1,5⌋ = 1)',
      );
    });

    test('fehlende Bewegungsart wird abgewiesen', () {
      expect(
        () => steigereBegleiter(
          c,
          ziel: const BegleiterSteigerungsziel.geschwindigkeit('Schwimmen'),
          erwarteterStand: 0,
          neuerStand: 1,
          apKosten: 1,
        ),
        throwsStateError,
      );
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
      const c = HeroCompanion(id: 'a', mu: 12, steigerungen: {'mu': 3});
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
      const c = HeroCompanion(id: 'a', maxLep: 20, steigerungen: {'lep': 3});
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
      const c = HeroCompanion(id: 'a', maxAup: 20, steigerungen: {'aup': 2});
      expect(companionEffektiverPoolwert(c, 'aup'), 22);
    });

    test('AuP gibt null wenn kein Basiswert gesetzt', () {
      const c = HeroCompanion(id: 'a');
      expect(companionEffektiverPoolwert(c, 'aup'), isNull);
    });
  });

  group('companionEffektiverRk', () {
    test('addiert Basis-RK und Steigerung', () {
      const c = HeroCompanion(id: 'a', steigerungen: {'rk': 3});
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
