import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_rules.dart';

void main() {
  group('computeWundschwelle', () {
    test('Basis = KO/2 abgerundet', () {
      expect(computeWundschwelle(ko: 14), 7);
      expect(computeWundschwelle(ko: 15), 7);
      expect(computeWundschwelle(ko: 10), 5);
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

  group('computeWundEffekte', () {
    test('keine Wunden → alle Mali 0', () {
      const zustand = WundZustand();
      final effekte = computeWundEffekte(zustand);
      expect(effekte.atMalus, 0);
      expect(effekte.paMalus, 0);
      expect(effekte.fkMalus, 0);
      expect(effekte.iniMalus, 0);
      expect(effekte.gsMalus, 0);
      expect(effekte.talentProbeMalus, 0);
      expect(effekte.zauberExtraMalus, 0);
      expect(effekte.kampfunfaehig, false);
      expect(effekte.kampfunfaehigeZonen, isEmpty);
      expect(effekte.hinweise, isEmpty);
    });

    test('einzelne Kopfwunde: Basis + zonenspezifisch', () {
      final zustand = const WundZustand(
        wundenProZone: {WundZone.kopf: 1},
        kopfIniMalus: 8,
      );
      final e = computeWundEffekte(zustand);
      // Basis: AT -2, PA -2, FK -2, INI -2, GS -1
      // Kopf:  AT -1, PA -1, FK -1, Zauber -3
      expect(e.atMalus, -3);
      expect(e.paMalus, -3);
      expect(e.fkMalus, -3);
      expect(e.iniMalus, -2);
      expect(e.kopfIniWuerfelMalus, 8);
      expect(e.iniGesamt, -10);
      expect(e.gsMalus, -1);
      expect(e.talentProbeMalus, -3);
      expect(e.zauberExtraMalus, -3);
      expect(e.zauberProbeMalus, -6);
      expect(e.kampfunfaehig, false);
    });

    test('einzelne Brustwunde: Basis + zonenspezifisch + Hinweis', () {
      final zustand = const WundZustand(
        wundenProZone: {WundZone.brust: 1},
      );
      final e = computeWundEffekte(zustand);
      expect(e.atMalus, -3);
      expect(e.paMalus, -3);
      expect(e.fkMalus, -3);
      expect(e.iniMalus, -2);
      expect(e.gsMalus, -1);
      expect(e.talentProbeMalus, -3);
      expect(e.hinweise, contains('+1W6 SP Extraschaden (Brust)'));
    });

    test('einzelne Armwunde: hohe FK-Abzuege', () {
      final zustand = const WundZustand(
        wundenProZone: {WundZone.rechterArm: 1},
      );
      final e = computeWundEffekte(zustand);
      // Basis: AT -2, PA -2, FK -2
      // Arm:   AT -2, PA -2, FK -4
      expect(e.atMalus, -4);
      expect(e.paMalus, -4);
      expect(e.fkMalus, -6);
    });

    test('einzelne Beinwunde: GS-Extramalus', () {
      final zustand = const WundZustand(
        wundenProZone: {WundZone.linkesBein: 1},
      );
      final e = computeWundEffekte(zustand);
      // Basis: GS -1
      // Bein:  GS -2
      expect(e.gsMalus, -3);
      // Basis: AT -2, PA -2, FK -2
      // Bein:  AT -1, PA -1, FK -2
      expect(e.atMalus, -3);
      expect(e.paMalus, -3);
      expect(e.fkMalus, -4);
    });

    test('kumulierte Effekte: mehrere Zonen', () {
      final zustand = const WundZustand(
        wundenProZone: {
          WundZone.kopf: 1,
          WundZone.brust: 2,
          WundZone.linkerArm: 1,
        },
        kopfIniMalus: 5,
      );
      final e = computeWundEffekte(zustand);
      // Gesamt: 4 Wunden
      // Basis: AT -8, PA -8, FK -8, INI -8, GS -4, Proben -12
      // Kopf(1):  AT -1, PA -1, FK -1, Zauber -3
      // Brust(2): AT -2, PA -2, FK -2
      // Arm(1):   AT -2, PA -2, FK -4
      expect(e.atMalus, -8 - 1 - 2 - 2);
      expect(e.paMalus, -8 - 1 - 2 - 2);
      expect(e.fkMalus, -8 - 1 - 2 - 4);
      expect(e.iniMalus, -8);
      expect(e.kopfIniWuerfelMalus, 5);
      expect(e.gsMalus, -4);
      expect(e.talentProbeMalus, -12);
      expect(e.zauberExtraMalus, -3);
    });

    test('3 Wunden in Zone → kampfunfaehig', () {
      final zustand = const WundZustand(
        wundenProZone: {WundZone.linkerArm: 3},
      );
      final e = computeWundEffekte(zustand);
      expect(e.kampfunfaehig, true);
      expect(e.kampfunfaehigeZonen, [WundZone.linkerArm]);
      expect(
        e.hinweise,
        contains('Linker Arm: nicht mehr verwendbar'),
      );
    });

    test('3 Kopfwunden → Folgeschaden-Hinweis', () {
      final zustand = const WundZustand(
        wundenProZone: {WundZone.kopf: 3},
        kopfIniMalus: 20,
      );
      final e = computeWundEffekte(zustand);
      expect(e.kampfunfaehig, true);
      expect(e.kampfunfaehigeZonen, [WundZone.kopf]);
      expect(
        e.hinweise,
        contains('Kopf: 1 SP/KR Folgeschaden'),
      );
    });

    test('3 Brustwunden → Folgeschaden-Hinweis', () {
      final zustand = const WundZustand(
        wundenProZone: {WundZone.brust: 3},
      );
      final e = computeWundEffekte(zustand);
      expect(e.kampfunfaehig, true);
      expect(
        e.hinweise,
        contains('Brust: 1 SP/KR Folgeschaden'),
      );
    });
  });

  group('WundZustand Mutation', () {
    test('mitWundeHinzu erhoeht Zaehler', () {
      const zustand = WundZustand();
      final aktualisiert = zustand.mitWundeHinzu(WundZone.brust);
      expect(aktualisiert.wundenInZone(WundZone.brust), 1);
    });

    test('mitWundeHinzu begrenzt auf maxWundenProZone', () {
      final zustand = const WundZustand(
        wundenProZone: {WundZone.brust: 3},
      );
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
      final zustand = const WundZustand(
        wundenProZone: {WundZone.brust: 2},
      );
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

  group('computeWundEffekte mit Unterdrueckung', () {
    test('unterdrueckte Wunde verursacht keine Abzuege', () {
      final zustand = const WundZustand(
        wundenProZone: {WundZone.brust: 1},
        unterdrueckteWundenProZone: {WundZone.brust: 1},
      );
      final e = computeWundEffekte(zustand);
      expect(e.atMalus, 0);
      expect(e.paMalus, 0);
      expect(e.fkMalus, 0);
      expect(e.iniMalus, 0);
      expect(e.gsMalus, 0);
      expect(e.talentProbeMalus, 0);
      expect(e.unterdrueckteGesamt, 1);
    });

    test('teilweise unterdrueckt: nur effektive Wunden zaehlen', () {
      final zustand = const WundZustand(
        wundenProZone: {WundZone.linkerArm: 2},
        unterdrueckteWundenProZone: {WundZone.linkerArm: 1},
      );
      final e = computeWundEffekte(zustand);
      // 1 effektive Wunde:
      // Basis: AT -2, PA -2, FK -2, INI -2, GS -1, Proben -3
      // Arm:   AT -2, PA -2, FK -4
      expect(e.atMalus, -4);
      expect(e.paMalus, -4);
      expect(e.fkMalus, -6);
      expect(e.iniMalus, -2);
      expect(e.gsMalus, -1);
      expect(e.talentProbeMalus, -3);
    });

    test('alle Wunden unterdrueckt → keine Mali', () {
      final zustand = const WundZustand(
        wundenProZone: {
          WundZone.kopf: 1,
          WundZone.brust: 2,
        },
        kopfIniMalus: 8,
        unterdrueckteWundenProZone: {
          WundZone.kopf: 1,
          WundZone.brust: 2,
        },
      );
      final e = computeWundEffekte(zustand);
      expect(e.atMalus, 0);
      expect(e.paMalus, 0);
      expect(e.fkMalus, 0);
      expect(e.iniMalus, 0);
      expect(e.kopfIniWuerfelMalus, 0);
      expect(e.gsMalus, 0);
      expect(e.talentProbeMalus, 0);
      expect(e.zauberExtraMalus, 0);
      expect(e.unterdrueckteGesamt, 3);
    });

    test('Kampfunfaehigkeit greift trotz Unterdrueckung', () {
      final zustand = const WundZustand(
        wundenProZone: {WundZone.linkerArm: 3},
        unterdrueckteWundenProZone: {WundZone.linkerArm: 3},
      );
      final e = computeWundEffekte(zustand);
      expect(e.kampfunfaehig, true);
      expect(e.kampfunfaehigeZonen, [WundZone.linkerArm]);
      // Aber keine Abzuege:
      expect(e.atMalus, 0);
      expect(e.paMalus, 0);
    });

    test('kopfIniMalus proportional bei unterdrueckten Kopfwunden', () {
      final zustand = const WundZustand(
        wundenProZone: {WundZone.kopf: 2},
        kopfIniMalus: 10,
        unterdrueckteWundenProZone: {WundZone.kopf: 1},
      );
      final e = computeWundEffekte(zustand);
      // 1 effektive von 2 → ceil(10 * 1 / 2) = 5
      expect(e.kopfIniWuerfelMalus, 5);
    });

    test('Extraschaden-Hinweis basiert auf Gesamtwunden', () {
      final zustand = const WundZustand(
        wundenProZone: {WundZone.brust: 2},
        unterdrueckteWundenProZone: {WundZone.brust: 1},
      );
      final e = computeWundEffekte(zustand);
      expect(e.hinweise, contains('+2W6 SP Extraschaden (Brust)'));
    });

    test('Unterdrueckungs-Hinweis wird angezeigt', () {
      final zustand = const WundZustand(
        wundenProZone: {WundZone.brust: 1},
        unterdrueckteWundenProZone: {WundZone.brust: 1},
      );
      final e = computeWundEffekte(zustand);
      expect(e.hinweise, contains('1 Wunde unterdrückt'));
    });
  });

  group('computeSbUnterdrueckungErschwernis', () {
    test('Einzelwunde: 4 * Gesamtwunden', () {
      expect(
        computeSbUnterdrueckungErschwernis(gesamtWunden: 1),
        4,
      );
      expect(
        computeSbUnterdrueckungErschwernis(gesamtWunden: 3),
        12,
      );
      expect(
        computeSbUnterdrueckungErschwernis(gesamtWunden: 5),
        20,
      );
    });

    test('2 Wunden aus einem Treffer: pauschal 8', () {
      expect(
        computeSbUnterdrueckungErschwernis(gesamtWunden: 2, neueWunden: 2),
        8,
      );
      expect(
        computeSbUnterdrueckungErschwernis(gesamtWunden: 5, neueWunden: 2),
        8,
      );
    });

    test('3 Wunden aus einem Treffer: pauschal 12', () {
      expect(
        computeSbUnterdrueckungErschwernis(gesamtWunden: 3, neueWunden: 3),
        12,
      );
      expect(
        computeSbUnterdrueckungErschwernis(gesamtWunden: 6, neueWunden: 3),
        12,
      );
    });
  });

  group('WundZustand Unterdrueckung', () {
    test('mitUnterdrueckung setzt Zaehler geclampt', () {
      final zustand = const WundZustand(
        wundenProZone: {WundZone.brust: 2},
      );
      final aktualisiert = zustand.mitUnterdrueckung(WundZone.brust, 1);
      expect(aktualisiert.unterdrueckteInZone(WundZone.brust), 1);
      expect(aktualisiert.effektiveWundenInZone(WundZone.brust), 1);
    });

    test('mitUnterdrueckung clampt auf Wundenanzahl', () {
      final zustand = const WundZustand(
        wundenProZone: {WundZone.brust: 1},
      );
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

  group('wundEffekteToStatModifiers', () {
    test('konvertiert Mali korrekt', () {
      final effekte = computeWundEffekte(const WundZustand(
        wundenProZone: {WundZone.kopf: 1},
        kopfIniMalus: 8,
      ));
      final mods = wundEffekteToStatModifiers(effekte);
      expect(mods.at, effekte.atMalus);
      expect(mods.pa, effekte.paMalus);
      expect(mods.fk, effekte.fkMalus);
      expect(mods.iniBase, effekte.iniGesamt);
      expect(mods.gs, effekte.gsMalus);
      // Nicht in StatModifiers abgebildet:
      expect(mods.lep, 0);
      expect(mods.au, 0);
      expect(mods.asp, 0);
    });

    test('keine Wunden → leere StatModifiers', () {
      final mods = wundEffekteToStatModifiers(const WundEffekte());
      expect(mods.at, 0);
      expect(mods.pa, 0);
      expect(mods.fk, 0);
      expect(mods.iniBase, 0);
      expect(mods.gs, 0);
    });
  });
}
