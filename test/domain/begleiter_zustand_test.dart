// Laufende Werte eines Begleiters (V2): JSON-Format und Rechenregeln.
import 'package:dsa_heldenverwaltung/domain/begleiter_zustand.dart';
import 'package:dsa_heldenverwaltung/domain/hero_companion.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/sync_models.dart';
import 'package:dsa_heldenverwaltung/rules/derived/begleiter_zustand_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/ressourcen_aenderung_rules.dart';
import 'package:flutter_test/flutter_test.dart';

const _tier = HeroCompanion(
  id: 'mira',
  maxLep: 20,
  maxAsp: 10,
  maxAup: 30,
  startLep: 20,
  startAsp: 10,
  startAup: 30,
);

const _leer = HeroState(
  currentLep: 10,
  currentAsp: 0,
  currentKap: 0,
  currentAu: 10,
);

void main() {
  group('BegleiterZustand', () {
    test('schreibt nur belegte Werte', () {
      expect(const BegleiterZustand().toJson(), isEmpty);
      expect(const BegleiterZustand(currentAsp: 3).toJson(), {'currentAsp': 3});
    });

    test('copyWith unterscheidet „nicht übergeben“ und „voll“ (null)', () {
      const z = BegleiterZustand(currentLep: 5, currentAsp: 2);
      expect(z.copyWith(currentAup: 4).currentLep, 5);
      expect(z.copyWith(currentLep: null).currentLep, isNull);
      expect(z.copyWith(currentLep: null).currentAsp, 2);
    });

    test('ein leerer Eintrag ändert den Inhalts-Hash nicht', () {
      expect(
        heroStateContentHash(_leer),
        heroStateContentHash(
          _leer.withBegleiterZustand('mira', const BegleiterZustand()),
        ),
      );
    });
  });

  group('Pool-Rechnung', () {
    test('„voll“ ist das wirksame Maximum', () {
      expect(begleiterAktuellerPool(_tier, _leer, BegleiterPool.lep), 20);
      expect(begleiterPoolMaximum(_tier, BegleiterPool.asp), 10);
    });

    test('rechnet vom gespeicherten Wert, nicht vom angezeigten', () {
      var z = _leer;
      for (var i = 0; i < 5; i++) {
        z = mitBegleiterPool(
          z,
          _tier,
          BegleiterPool.lep,
          begleiterPoolSchritt(BegleiterPool.lep, 20, -1),
        );
      }
      expect(z.begleiterZustaende['mira']!.currentLep, 15);
      expect(begleiterAktuellerPool(_tier, z, BegleiterPool.lep), 15);
    });

    test('Heilen bis zum Maximum speichert „voll“ (kein Eintrag)', () {
      final z = mitBegleiterPool(
        mitBegleiterPool(
          _leer,
          _tier,
          BegleiterPool.lep,
          const RessourcenAenderung.setzen(15),
        ),
        _tier,
        BegleiterPool.lep,
        begleiterPoolSchritt(BegleiterPool.lep, 20, 99),
      );
      expect(z.begleiterZustaende, isEmpty);
    });

    test('Grenzen: LeP bis −10, AsP und AuP bis 0, nie über das Maximum', () {
      var z = mitBegleiterPool(
        _leer,
        _tier,
        BegleiterPool.lep,
        const RessourcenAenderung.setzen(-9),
      );
      z = mitBegleiterPool(
        z,
        _tier,
        BegleiterPool.lep,
        begleiterPoolSchritt(BegleiterPool.lep, 20, -5),
      );
      expect(z.begleiterZustaende['mira']!.currentLep, -10);
      z = mitBegleiterPool(
        z,
        _tier,
        BegleiterPool.asp,
        begleiterPoolSchritt(BegleiterPool.asp, 10, -99),
      );
      expect(z.begleiterZustaende['mira']!.currentAsp, 0);
      final unveraendert = mitBegleiterPool(
        _leer,
        _tier,
        BegleiterPool.aup,
        begleiterPoolSchritt(BegleiterPool.aup, 30, 1),
      );
      expect(identical(unveraendert, _leer), isTrue);
    });

    test('lässt andere Begleiter und Pools unberührt', () {
      final start = _leer
          .withBegleiterZustand('rondo', const BegleiterZustand(currentLep: 2))
          .withBegleiterZustand('mira', const BegleiterZustand(currentAsp: 4));
      final z = mitBegleiterPool(
        start,
        _tier,
        BegleiterPool.lep,
        begleiterPoolSchritt(BegleiterPool.lep, 20, -3),
      );
      expect(z.begleiterZustaende['rondo']!.currentLep, 2);
      expect(z.begleiterZustaende['mira']!.currentAsp, 4);
      expect(z.begleiterZustaende['mira']!.currentLep, 17);
    });

    test('ein gestiegenes Maximum zieht einen vollen Begleiter mit', () {
      final steiger = _tier.copyWith(steigerungen: const {'lep': 2});
      expect(
        begleiterAktuellerPool(steiger, _leer, BegleiterPool.lep),
        greaterThan(20),
      );
    });
  });
}
