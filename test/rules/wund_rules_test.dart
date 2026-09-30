import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_rules.dart';

void main() {
  group('computeWundschwelle', () {
    test('Basis = KO/2 kaufmaennisch gerundet (WdS S. 58)', () {
      expect(computeWundschwelle(ko: 14), 7);
      expect(computeWundschwelle(ko: 15), 8);
      expect(computeWundschwelle(ko: 13), 7);
      expect(computeWundschwelle(ko: 10), 5);
    });

    test('entspricht der ersten Stufe samt Eisern und Glasknochen', () {
      expect(computeWundschwelle(ko: 13, vorteileText: 'Eisern'), 9);
      expect(computeWundschwelle(ko: 13, merkmalBonus: 2), 9);
      expect(computeWundschwelle(ko: 14, nachteileText: 'Glasknochen'), 5);
      for (final ko in [7, 12, 13, 15, 18]) {
        expect(
          computeWundschwelle(ko: ko, vorteileText: 'Eisern'),
          computeWundschwellenStufen(ko: ko, vorteileText: 'Eisern').halbKo,
          reason: 'KO $ko',
        );
      }
    });

    test('mit positiven Modifikatoren', () {
      expect(
        computeWundschwelle(
          ko: 14,
          mods: [HeroTalentModifier(modifier: 1, description: 'Eisern')],
        ),
        8,
      );
    });

    test('mit negativen Modifikatoren', () {
      expect(
        computeWundschwelle(
          ko: 14,
          mods: [
            HeroTalentModifier(modifier: -1, description: 'Schmerzempfindlich'),
          ],
        ),
        6,
      );
    });

    test('mit mehreren Modifikatoren', () {
      expect(
        computeWundschwelle(
          ko: 14,
          mods: [
            HeroTalentModifier(modifier: 2, description: 'Eisern II'),
            HeroTalentModifier(modifier: -1, description: 'Schmerzempfindlich'),
          ],
        ),
        8,
      );
    });
  });

  group('computeWundschwellenStufen', () {
    test('gerade KO ohne Modifikatoren', () {
      final stufen = computeWundschwellenStufen(ko: 14);

      expect(stufen.halbKo, 7);
      expect(stufen.ko, 14);
      expect(stufen.einhalbKo, 21);
    });

    test('ungerade KO rundet 0,5 und 1,5 kaufmaennisch', () {
      final stufen = computeWundschwellenStufen(ko: 15);

      expect(stufen.halbKo, 8);
      expect(stufen.ko, 15);
      expect(stufen.einhalbKo, 23);
    });

    test('Eisern gibt +2 auf alle Stufen', () {
      final stufen = computeWundschwellenStufen(
        ko: 14,
        vorteileText: 'Eisern, Flink',
      );

      expect(stufen.halbKo, 9);
      expect(stufen.ko, 16);
      expect(stufen.einhalbKo, 23);
    });

    test('Glasknochen gibt -2 auf alle Stufen', () {
      final stufen = computeWundschwellenStufen(
        ko: 14,
        nachteileText: 'Glasknochen, Arroganz 8',
      );

      expect(stufen.halbKo, 5);
      expect(stufen.ko, 12);
      expect(stufen.einhalbKo, 19);
    });

    test('kombiniert Textbonus mit benannten Wundschwelle-Modifikatoren', () {
      final stufen = computeWundschwellenStufen(
        ko: 15,
        mods: [
          HeroTalentModifier(modifier: 1, description: 'Artefakt'),
          HeroTalentModifier(modifier: -1, description: 'Fluch'),
        ],
        vorteileText: 'Eisern',
      );

      expect(stufen.halbKo, 10);
      expect(stufen.ko, 17);
      expect(stufen.einhalbKo, 25);
    });
  });

  group('WundZustand Mutation', () {
    test('mitWundeHinzu erhoeht Zaehler', () {
      const zustand = WundZustand();
      final aktualisiert = zustand.mitWundeHinzu(WundZone.brust);
      expect(aktualisiert.wundenInZone(WundZone.brust), 1);
    });

    test('mitWundeHinzu begrenzt auf maxWundenProZone', () {
      final zustand = const WundZustand(wundenProZone: {WundZone.brust: 3});
      final aktualisiert = zustand.mitWundeHinzu(WundZone.brust);
      expect(aktualisiert.wundenInZone(WundZone.brust), 3);
    });

    test('mitWundeHinzu Kopf addiert INI-Wuerfelwert', () {
      const zustand = WundZustand();
      final a = zustand.mitWundeHinzu(WundZone.kopf, iniWuerfelWert: 7);
      expect(a.kopfIniMalus, 7);
      expect(a.wundenInZone(WundZone.kopf), 1);

      final b = a.mitWundeHinzu(WundZone.kopf, iniWuerfelWert: 4);
      expect(b.kopfIniMalus, 11);
      expect(b.wundenInZone(WundZone.kopf), 2);
    });

    test('mitWundeEntfernt reduziert Zaehler', () {
      final zustand = const WundZustand(wundenProZone: {WundZone.brust: 2});
      final aktualisiert = zustand.mitWundeEntfernt(WundZone.brust);
      expect(aktualisiert.wundenInZone(WundZone.brust), 1);
    });

    test('mitWundeEntfernt nicht unter 0', () {
      const zustand = WundZustand();
      final aktualisiert = zustand.mitWundeEntfernt(WundZone.brust);
      expect(aktualisiert.wundenInZone(WundZone.brust), 0);
    });

    test('mitWundeEntfernt Kopf reduziert INI-Malus anteilig', () {
      final zustand = const WundZustand(
        wundenProZone: {WundZone.kopf: 2},
        kopfIniMalus: 11,
      );
      final aktualisiert = zustand.mitWundeEntfernt(WundZone.kopf);
      expect(aktualisiert.wundenInZone(WundZone.kopf), 1);
      // Anteil: ceil(11/2) = 6 → 11 - 6 = 5
      expect(aktualisiert.kopfIniMalus, 5);
    });

    test('letzte Kopfwunde entfernt → INI-Malus auf 0', () {
      final zustand = const WundZustand(
        wundenProZone: {WundZone.kopf: 1},
        kopfIniMalus: 7,
      );
      final aktualisiert = zustand.mitWundeEntfernt(WundZone.kopf);
      expect(aktualisiert.wundenInZone(WundZone.kopf), 0);
      expect(aktualisiert.kopfIniMalus, 0);
    });

    test('gesamtWunden zaehlt alle Zonen', () {
      final zustand = const WundZustand(
        wundenProZone: {
          WundZone.kopf: 1,
          WundZone.brust: 2,
          WundZone.linkerArm: 3,
        },
      );
      expect(zustand.gesamtWunden, 6);
    });
  });

  group('WundZustand Serialisierung', () {
    test('toJson/fromJson Roundtrip', () {
      final zustand = const WundZustand(
        wundenProZone: {
          WundZone.kopf: 2,
          WundZone.brust: 1,
          WundZone.rechterArm: 3,
        },
        kopfIniMalus: 14,
      );
      final json = zustand.toJson();
      final wiederhergestellt = WundZustand.fromJson(json);
      expect(wiederhergestellt.wundenInZone(WundZone.kopf), 2);
      expect(wiederhergestellt.wundenInZone(WundZone.brust), 1);
      expect(wiederhergestellt.wundenInZone(WundZone.rechterArm), 3);
      expect(wiederhergestellt.wundenInZone(WundZone.bauch), 0);
      expect(wiederhergestellt.kopfIniMalus, 14);
    });

    test('fromJson mit leeren Daten', () {
      final zustand = WundZustand.fromJson(const {});
      expect(zustand.gesamtWunden, 0);
      expect(zustand.kopfIniMalus, 0);
    });

    test('fromJson clamped auf maxWundenProZone', () {
      final zustand = WundZustand.fromJson({
        'wundenProZone': {'kopf': 10},
      });
      expect(zustand.wundenInZone(WundZone.kopf), 3);
    });

    test('fromJson ignoriert unbekannte Zonen', () {
      final zustand = WundZustand.fromJson({
        'wundenProZone': {'unbekannt': 2, 'kopf': 1},
      });
      expect(zustand.wundenInZone(WundZone.kopf), 1);
      expect(zustand.gesamtWunden, 1);
    });
  });

  group('WundZustand Unterdrueckung', () {
    test('mitUnterdrueckung setzt Zaehler geclampt', () {
      final zustand = const WundZustand(wundenProZone: {WundZone.brust: 2});
      final aktualisiert = zustand.mitUnterdrueckung(WundZone.brust, 1);
      expect(aktualisiert.unterdrueckteInZone(WundZone.brust), 1);
      expect(aktualisiert.effektiveWundenInZone(WundZone.brust), 1);
    });

    test('mitUnterdrueckung clampt auf Wundenanzahl', () {
      final zustand = const WundZustand(wundenProZone: {WundZone.brust: 1});
      final aktualisiert = zustand.mitUnterdrueckung(WundZone.brust, 5);
      expect(aktualisiert.unterdrueckteInZone(WundZone.brust), 1);
    });

    test('mitUnterdrueckung clampt auf 0', () {
      final zustand = const WundZustand(
        wundenProZone: {WundZone.brust: 2},
        unterdrueckteWundenProZone: {WundZone.brust: 1},
      );
      final aktualisiert = zustand.mitUnterdrueckung(WundZone.brust, -3);
      expect(aktualisiert.unterdrueckteInZone(WundZone.brust), 0);
    });

    test('mitWundeEntfernt clampt Unterdrueckung', () {
      final zustand = const WundZustand(
        wundenProZone: {WundZone.brust: 2},
        unterdrueckteWundenProZone: {WundZone.brust: 2},
      );
      final aktualisiert = zustand.mitWundeEntfernt(WundZone.brust);
      expect(aktualisiert.wundenInZone(WundZone.brust), 1);
      expect(aktualisiert.unterdrueckteInZone(WundZone.brust), 1);
    });

    test('letzte Wunde entfernt → Unterdrueckung auf 0', () {
      final zustand = const WundZustand(
        wundenProZone: {WundZone.brust: 1},
        unterdrueckteWundenProZone: {WundZone.brust: 1},
      );
      final aktualisiert = zustand.mitWundeEntfernt(WundZone.brust);
      expect(aktualisiert.wundenInZone(WundZone.brust), 0);
      expect(aktualisiert.unterdrueckteInZone(WundZone.brust), 0);
    });

    test('Serialisierung Roundtrip mit Unterdrueckung', () {
      final zustand = const WundZustand(
        wundenProZone: {WundZone.kopf: 2, WundZone.brust: 1},
        kopfIniMalus: 10,
        unterdrueckteWundenProZone: {WundZone.kopf: 1},
        kampfunfaehigIgnoriert: true,
      );
      final json = zustand.toJson();
      final wiederhergestellt = WundZustand.fromJson(json);
      expect(wiederhergestellt.unterdrueckteInZone(WundZone.kopf), 1);
      expect(wiederhergestellt.unterdrueckteInZone(WundZone.brust), 0);
      expect(wiederhergestellt.kampfunfaehigIgnoriert, true);
      expect(wiederhergestellt.kopfIniMalus, 10);
    });

    test('fromJson ohne Unterdrueckung → leere Map', () {
      final zustand = WundZustand.fromJson({
        'wundenProZone': {'kopf': 1},
        'kopfIniMalus': 5,
      });
      expect(zustand.unterdrueckteInZone(WundZone.kopf), 0);
      expect(zustand.kampfunfaehigIgnoriert, false);
    });

    test('fromJson clampt Unterdrueckung auf Wundenanzahl', () {
      final zustand = WundZustand.fromJson({
        'wundenProZone': {'kopf': 1},
        'unterdrueckteWundenProZone': {'kopf': 3},
      });
      expect(zustand.unterdrueckteInZone(WundZone.kopf), 1);
    });
  });
}
