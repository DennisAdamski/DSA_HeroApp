import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/wund_zustand.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_anzeige_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_zonen_rules.dart';

// Wunden nach Gesamt- plus Zonensystem (Hausregel „Erweiterung und
// Überarbeitung“ S. 3; WdS S. 58, 108 f., 111; BRW S. 194).
void main() {
  WundEffekte effekte(
    Map<WundZone, int> wunden, {
    Map<WundZone, int> unterdrueckt = const <WundZone, int>{},
    int kopfIniMalus = 0,
    bool linkshaender = false,
    bool halbiert = false,
  }) {
    return computeWundEffekte(
      WundZustand(
        wundenProZone: wunden,
        unterdrueckteWundenProZone: unterdrueckt,
        kopfIniMalus: kopfIniMalus,
      ),
      linkshaender: linkshaender,
      halbierteUnterdrueckung: halbiert,
    );
  }

  // Nur die tatsächlich veränderten Eigenschaften.
  Map<String, dynamic> verluste(WundEffekte e) => <String, dynamic>{
    for (final eintrag in e.eigenschaftsVerluste.toJson().entries)
      if (eintrag.value != 0) eintrag.key: eintrag.value,
  };

  group('eine Wunde je Zone: allgemein plus Zone', () {
    test('keine Wunden → nichts wirkt', () {
      final e = effekte(const {});
      expect(e.hatAbzuege, isFalse);
      expect(e.hinweise, isEmpty);
      expect(e.kampfunfaehig, isFalse);
      expect(wundEffekteToStatModifiers(e).toJson().values, everyElement(0));
    });

    test('Kopf: INI-Basis −4, MU/KL/IN/GE −2, 2W6 nur als Hinweis', () {
      final e = effekte(const {WundZone.kopf: 1}, kopfIniMalus: 8);
      expect(e.atMalus, -2);
      expect(e.paMalus, -2);
      expect(e.fkMalus, -2);
      expect(e.iniBasisMalus, -4);
      expect(e.gsMalus, -1);
      expect(verluste(e), {'mu': -2, 'kl': -2, 'inn': -2, 'ge': -2});
      expect(e.aktuellerIniMalus, 8);
      expect(e.hinweise, contains('Kopf: aktuelle INI −8 (laufender Kampf)'));
      expect(
        wundEffekteToStatModifiers(e).iniBase,
        -4,
        reason: 'der gewürfelte INI-Verlust gilt nur im laufenden Kampf',
      );
    });

    test('Brust und Rücken: AT/PA −3, KO/KK −1, Zusatzschaden', () {
      for (final zone in [WundZone.brust, WundZone.ruecken]) {
        final e = effekte({zone: 1});
        expect(e.atMalus, -3, reason: zone.name);
        expect(e.paMalus, -3, reason: zone.name);
        expect(e.fkMalus, -2, reason: zone.name);
        expect(e.iniBasisMalus, -2, reason: zone.name);
        expect(e.gsMalus, -1, reason: zone.name);
        expect(verluste(e), {'ge': -2, 'ko': -1, 'kk': -1});
      }
      expect(
        effekte(const {WundZone.ruecken: 1}).hinweise,
        contains('+1W6 SP Extraschaden (Rücken)'),
      );
    });

    test('Bauch: zusätzlich INI-Basis und GS je −1', () {
      final e = effekte(const {WundZone.bauch: 1});
      expect(e.atMalus, -3);
      expect(e.paMalus, -3);
      expect(e.iniBasisMalus, -3);
      expect(e.gsMalus, -2);
      expect(verluste(e), {'ge': -2, 'ko': -1, 'kk': -1});
    });

    test('Bein: AT/PA/INI-Basis −4, GS −2, GE −4, FK nur allgemein', () {
      final e = effekte(const {WundZone.rechtesBein: 1});
      expect(e.atMalus, -4);
      expect(e.paMalus, -4);
      expect(e.fkMalus, -2);
      expect(e.iniBasisMalus, -4);
      expect(e.gsMalus, -2);
      expect(verluste(e), {'ge': -4});
    });

    test('Arm: AT/PA −2 nur für diesen Arm, FK nur allgemein', () {
      final rechts = effekte(const {WundZone.rechterArm: 1});
      expect(rechts.atMalus, -2, reason: 'nur der allgemeine Anteil');
      expect(rechts.paMalus, -2);
      expect(
        rechts.fkMalus,
        -2,
        reason: 'Armwunden erhöhen den FK-Abzug nicht',
      );
      expect(rechts.schwertarmAtPaMalus, -2);
      expect(rechts.schildarmAtPaMalus, 0);
      expect(verluste(rechts), {'ff': -2, 'ge': -2, 'kk': -2});
      expect(
        rechts.hinweise,
        contains(
          'Rechter Arm (Schwertarm): KK und FF −2 gelten nur für '
          'Handlungen mit diesem Arm',
        ),
      );

      final links = effekte(const {WundZone.linkerArm: 2});
      expect(links.schwertarmAtPaMalus, 0);
      expect(links.schildarmAtPaMalus, -4);
    });

    test('Linkshänder: der linke Arm ist der Schwertarm', () {
      final e = effekte(const {WundZone.linkerArm: 1}, linkshaender: true);
      expect(e.schwertarmAtPaMalus, -2);
      expect(e.schildarmAtPaMalus, 0);
      expect(e.linkshaender, isTrue);
      expect(e.hinweise.first, startsWith('Linker Arm (Schwertarm):'));
    });

    test('mehrere Zonen addieren sich', () {
      final e = effekte(const {
        WundZone.kopf: 1,
        WundZone.brust: 2,
        WundZone.rechterArm: 1,
      });
      expect(e.atMalus, -10);
      expect(e.paMalus, -10);
      expect(e.fkMalus, -8);
      expect(e.iniBasisMalus, -10);
      expect(e.gsMalus, -4);
      expect(e.schwertarmAtPaMalus, -2);
      expect(verluste(e), {
        'mu': -2,
        'kl': -2,
        'inn': -2,
        'ff': -2,
        'ge': -8,
        'ko': -2,
        'kk': -4,
      });
    });
  });

  group('dritte Wunde', () {
    test('Kopf, Brust, Rücken, Bauch machen kampfunfähig', () {
      for (final zone in [
        WundZone.kopf,
        WundZone.brust,
        WundZone.ruecken,
        WundZone.bauch,
      ]) {
        final e = effekte({zone: 3});
        expect(e.kampfunfaehig, isTrue, reason: zone.name);
        expect(e.zonenMitDritterWunde, [zone]);
      }
      expect(
        effekte(const {WundZone.brust: 3}).hinweise,
        contains(
          'Brust, 3. Wunde: kampfunfähig, bewusstlos für 1W20 KR, '
          '1 LeP/KR Blutverlust bis versorgt',
        ),
      );
    });

    test('Arm und Bein legen nur das Glied lahm', () {
      final arm = effekte(const {WundZone.rechterArm: 3});
      expect(arm.kampfunfaehig, isFalse);
      expect(arm.zonenMitDritterWunde, [WundZone.rechterArm]);
      expect(
        arm.hinweise,
        contains(
          'Rechter Arm (Schwertarm), 3. Wunde: Arm aktionsunfähig, '
          'gehaltene Waffe fällt',
        ),
      );
      final bein = effekte(const {WundZone.linkesBein: 3});
      expect(bein.kampfunfaehig, isFalse);
      expect(
        bein.hinweise,
        contains('Linkes Bein, 3. Wunde: Sturz, keine Teilnahme am Nahkampf'),
      );
    });
  });

  group('Unterdrückung', () {
    test('unterdrückte Wunden wirken nicht, zählen aber als dritte', () {
      final alle = effekte(
        const {WundZone.brust: 3},
        unterdrueckt: const {WundZone.brust: 3},
      );
      expect(alle.hatAbzuege, isFalse);
      expect(alle.kampfunfaehig, isTrue);

      final teilweise = effekte(
        const {WundZone.brust: 2},
        unterdrueckt: const {WundZone.brust: 1},
      );
      expect(teilweise.atMalus, -3);
      expect(teilweise.hinweise, [
        '+2W6 SP Extraschaden (Brust)',
        '1 Wunde unterdrückt',
        'Nach dem Kampf: 1W6 Erschöpfung',
      ]);
    });

    test('epische KO halbiert die Erschöpfung im Hinweis', () {
      final e = effekte(
        const {WundZone.bauch: 1},
        unterdrueckt: const {WundZone.bauch: 1},
        halbiert: true,
      );
      expect(
        e.hinweise,
        contains('Nach dem Kampf: 1W6 Erschöpfung, halbiert (epische KO)'),
      );
    });

    test('der Kopf-INI-Wurf zählt anteilig nur für effektive Kopfwunden', () {
      final e = effekte(
        const {WundZone.kopf: 2},
        unterdrueckt: const {WundZone.kopf: 1},
        kopfIniMalus: 10,
      );
      expect(e.aktuellerIniMalus, 5);
    });

    test('die Schalter bleiben auch ohne Wunden gesetzt', () {
      final e = effekte(const {}, linkshaender: true, halbiert: true);
      expect(e.linkshaender, isTrue);
      expect(e.unterdrueckungHalbiert, isTrue);
    });

    test('SB-Erschwernis zählt alle bisher erlittenen Wunden (WdS S. 83)', () {
      // Beispiel aus WdS S. 111: zwei Brustwunden, dann eine Kopfwunde → +12.
      expect(computeSbUnterdrueckungErschwernis(gesamtWunden: 3), 12);
      // Kampfverlauf: R2 eine Wunde (unterdrückt), R3 eine weitere, R4 zwei
      // aus einem Treffer. Unterdrückte Wunden zählen mit.
      expect(computeSbUnterdrueckungErschwernis(gesamtWunden: 1), 4);
      expect(computeSbUnterdrueckungErschwernis(gesamtWunden: 2), 8);
      expect(
        computeSbUnterdrueckungErschwernis(gesamtWunden: 4, neueWunden: 2),
        8,
        reason: 'mehrere Wunden aus einem Treffer: pauschal +8',
      );
      // Vor Kampfbeginn alle vier Wunden ignorieren: vierfache Anzahl.
      expect(computeSbUnterdrueckungErschwernis(gesamtWunden: 4), 16);
    });

    test('SB-Erschwernis: 4 je Wunde, +8/+12, episch halbiert', () {
      expect(computeSbUnterdrueckungErschwernis(gesamtWunden: 3), 12);
      expect(
        computeSbUnterdrueckungErschwernis(gesamtWunden: 3, halbiert: true),
        6,
      );
      expect(
        computeSbUnterdrueckungErschwernis(
          gesamtWunden: 4,
          neueWunden: 2,
          halbiert: true,
        ),
        4,
      );
      expect(
        computeSbUnterdrueckungErschwernis(
          gesamtWunden: 5,
          neueWunden: 3,
          halbiert: true,
        ),
        6,
      );
      expect(
        sbUnterdrueckungHerleitung(gesamtWunden: 3),
        '4 × 3 Wunden insgesamt = 12',
      );
      expect(
        sbUnterdrueckungHerleitung(gesamtWunden: 1),
        '4 × 1 Wunde insgesamt = 4',
      );
      expect(
        sbUnterdrueckungHerleitung(gesamtWunden: 3, halbiert: true),
        '4 × 3 Wunden insgesamt = 12, halbiert 6',
      );
      expect(
        sbUnterdrueckungHerleitung(gesamtWunden: 2, neueWunden: 2),
        '8 (2 Wunden aus einem Treffer)',
      );
    });
  });

  group('Probenwerte, GS-Grenze und Anzeige', () {
    test('Eigenschaftsverluste gelten auf den Probenwerten', () {
      const basis = Attributes(
        mu: 12,
        kl: 12,
        inn: 12,
        ch: 12,
        ff: 12,
        ge: 12,
        ko: 12,
        kk: 12,
      );
      final probe = wendeWundVerlusteAn(
        basis,
        effekte(const {WundZone.kopf: 1, WundZone.linkerArm: 1}),
      );
      expect(probe.mu, 10);
      expect(probe.kl, 10);
      expect(probe.inn, 10);
      expect(probe.ch, 12);
      expect(probe.ff, 10);
      expect(probe.ge, 8);
      expect(probe.ko, 12);
      expect(probe.kk, 10);
    });

    test('Wunden senken die GS nie unter 1', () {
      expect(begrenzeWundGs(ohneWunden: 8, mitWunden: 5), 5);
      expect(begrenzeWundGs(ohneWunden: 3, mitWunden: -1), 1);
      expect(begrenzeWundGs(ohneWunden: 1, mitWunden: -1), 1);
      expect(
        begrenzeWundGs(ohneWunden: 0, mitWunden: -2),
        0,
        reason: 'eine GS, die schon ohne Wunden unter 1 liegt, bleibt',
      );
      expect(begrenzeWundGs(ohneWunden: 5, mitWunden: 7), 7);
    });

    test('Zusammenfassung nennt Kampfwerte, Arm und Probenwerte', () {
      expect(beschreibeWundAbzuege(effekte(const {WundZone.linkerArm: 1})), [
        'AT −2',
        'PA −2',
        'FK −2',
        'INI-Basis −2',
        'GS −1',
        'Schildarm AT/PA −2',
        'Proben: FF −2, GE −2, KK −2',
      ]);
      expect(beschreibeWundAbzuege(effekte(const {})), isEmpty);
    });

    test('Armrollen und Zonenanzeige', () {
      expect(
        armRolleFuer(WundZone.rechterArm, linkshaender: false),
        ArmRolle.schwertarm,
      );
      expect(
        armRolleFuer(WundZone.rechterArm, linkshaender: true),
        ArmRolle.schildarm,
      );
      expect(armRolleFuer(WundZone.kopf, linkshaender: false), isNull);
      expect(
        armZoneFuer(ArmRolle.schildarm, linkshaender: true),
        WundZone.rechterArm,
      );
      expect(
        wundZonenAnzeige(WundZone.linkerArm, linkshaender: false),
        'Linker Arm (Schildarm)',
      );
      expect(wundZonenAnzeige(WundZone.bauch, linkshaender: true), 'Bauch');
    });
  });
}
