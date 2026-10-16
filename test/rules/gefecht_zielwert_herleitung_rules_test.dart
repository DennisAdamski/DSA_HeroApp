import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_auftrag_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_kampfmittel_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_zielwert_herleitung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/herleitung.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import '../ui2/shell/karto_test_support.dart';

const _bogen = MainWeaponSlot(
  id: 'bogen',
  name: 'Kurzbogen',
  combatType: WeaponCombatType.ranged,
  rangedProfile: RangedWeaponProfile(
    selectedProjectileIndex: 0,
    projectiles: [RangedProjectile(id: 'pfeil', name: 'Pfeil', count: 5)],
    distanceBands: [
      RangedDistanceBand(label: '5'),
      RangedDistanceBand(label: '10'),
      RangedDistanceBand(label: '20'),
      RangedDistanceBand(label: '40'),
      RangedDistanceBand(label: '80'),
    ],
  ),
);

Herleitung _h(String name, List<int> betraege) => Herleitung(
  bezeichnung: name,
  schritte: [
    for (var i = 0; i < betraege.length; i++)
      HerleitungsSchritt(
        bezeichnung: '$name $i',
        betrag: betraege[i],
        art: i == 0 ? HerleitungsArt.grundwert : HerleitungsArt.modifikator,
      ),
  ],
);

final _nahkampf = Gefechtswerte(
  iniBasis: 14,
  at: 14,
  pa: 12,
  ausweichen: 9,
  be: 3,
  schildPa: 15,
  schildWm: 2,
  ausweichen1: true,
  waffenDk: 'N',
  atHerleitung: _h('AT', [10, 4]),
  paHerleitung: _h('PA', [9, 3]),
  schildPaHerleitung: _h('Schild-PA', [10, 5]),
  ausweichenHerleitung: _h('Ausweichen', [12, -3]),
);

final _fernkampf = Gefechtswerte(
  iniBasis: 14,
  at: 13,
  pa: 0,
  ausweichen: 9,
  fernkampf: true,
  waffe: _bogen,
  waffenDk: 'F',
  atHerleitung: _h('FK', [9, 4]),
);

/// Zustände, die jeweils eine andere Erschwernis auslösen.
Map<String, Gefechtszustand> _zustaende(Gefechtszustand Function(String) dk) {
  final basis = dk('N');
  return {
    'Nahkampf': basis,
    'Handgemenge': dk('H'),
    'Stangenwaffen': dk('S'),
    'Piken': dk('P'),
    'Bewegt': basis.copyWith(bewegt: true),
    'Drei Gegner': basis.copyWith(gegner: 3),
    'Zweite AT': basis.copyWith(
      umwandlung: Gefechtsumwandlung.zweiteAttacke,
      angriffeVerbraucht: 1,
      umgewandelteAktionOffen: true,
    ),
    'Zweite PA': basis.copyWith(
      umwandlung: Gefechtsumwandlung.zweiteParade,
      paradenVerbraucht: 1,
      umgewandelteAktionOffen: true,
    ),
    'Finte, Schild-WM weg': basis.copyWith(
      kontext: const Gefechtskontext(
        angriffsart: Gefechtsangriffsart.nahkampf,
        finte: 2,
        platzZumAusweichen: true,
        schildWmWirksam: false,
        weitereRegelnGeprueft: true,
      ),
    ),
    'Fernkampf mit Getümmel': basis.copyWith(
      kontext: const Gefechtskontext(
        angriffsart: Gefechtsangriffsart.nahkampf,
        finte: 0,
        platzZumAusweichen: true,
        entfernung: 12,
        geladen: true,
        situationsZuschlag: 2,
        getuemmel: true,
      ),
    ),
    'Hohe INI': basis.copyWith(iniWurf: 40),
  };
}

Gefechtszustand _mitDk(String dk) => beginneGefecht(12, dk: dk);

void _pruefeInvarianten(Gefechtspruefung p, String grund) {
  expect(
    p.modifikatoren.fold<int>(0, (s, m) => s + m.wert),
    p.erschwernis,
    reason: '$grund: Anteile ergeben die Erschwernis',
  );
  final erschwernis = herleiteGefechtsErschwernis(p);
  if (p.modifikatoren.isEmpty) {
    expect(p.erschwernis, 0, reason: grund);
    expect(erschwernis, isNull, reason: grund);
  } else {
    expect(erschwernis, isNotNull, reason: grund);
    expect(erschwernis!.wert, p.erschwernis, reason: grund);
  }
  final ziel = herleiteGefechtsZielwert(p);
  if (p.zielHerleitung == null || p.zielwert == null) {
    expect(ziel, isNull, reason: grund);
    return;
  }
  expect(ziel, isNotNull, reason: '$grund: Zielwert lässt sich herleiten');
  expect(ziel!.wert, p.zielwert, reason: grund);
  expect(
    p.zielHerleitung!.wert - p.erschwernis,
    p.zielwert,
    reason: '$grund: Grundwert minus Erschwernis',
  );
}

void main() {
  group('Jede Gefechtsaktion: Summe der Schritte = Zielwert und Erschwernis', () {
    for (final entry in _zustaende(_mitDk).entries) {
      for (final (name, w) in [
        ('Nahkampf', _nahkampf),
        ('Fernkampf', _fernkampf),
      ]) {
        for (final aktion in Gefechtsaktion.values) {
          for (final manuell in <int?>[null, 9]) {
            for (final zuschlag in [0, 3]) {
              test(
                '${entry.key} · $name · $aktion · manuell $manuell · +$zuschlag',
                () {
                  final p = pruefeGefechtsaktion(
                    entry.value,
                    w,
                    aktion,
                    zuschlag: zuschlag,
                    manuellerZielwert: manuell,
                    abwehrAufAttacke: false,
                  );
                  _pruefeInvarianten(p, '${entry.key} $name $aktion');
                  final nahkampfAktion = {
                    Gefechtsaktion.angriff,
                    Gefechtsaktion.parade,
                    Gefechtsaktion.schildparade,
                    Gefechtsaktion.freiesAusweichen,
                    Gefechtsaktion.gezieltesAusweichen,
                  }.contains(aktion);
                  if (nahkampfAktion && p.zielwert != null) {
                    expect(p.zielHerleitung, isNotNull);
                  }
                },
              );
            }
          }
        }
      }
    }

    test('Gegenhalten (Abwehr auf die eigene AT) zeigt AT ohne INI-Bonus', () {
      final s = beginneGefecht(40, dk: 'N');
      final p = pruefeGefechtsaktion(
        s,
        _nahkampf,
        Gefechtsaktion.parade,
        abwehrAufAttacke: true,
      );
      _pruefeInvarianten(p, 'Gegenhalten');
      expect(
        p.zielHerleitung!.schritte.map((e) => e.bezeichnung),
        isNot(contains('INI-Bonus (Sitzung)')),
      );
      expect(p.zielHerleitung!.wert, _nahkampf.at);
    });
  });

  group('Benannte Erschwernisse', () {
    Map<String, int> anteile(Gefechtspruefung p) => {
      for (final m in p.modifikatoren) m.name: m.wert,
    };

    test('Bewegen +4 für Kampfaktionen, nicht fürs freie Ausweichen', () {
      final s = _mitDk('N').copyWith(bewegt: true);
      expect(
        anteile(pruefeGefechtsaktion(s, _nahkampf, Gefechtsaktion.angriff)),
        containsPair(kGefechtsNachBewegen, 4),
      );
      expect(
        anteile(
          pruefeGefechtsaktion(s, _nahkampf, Gefechtsaktion.freiesAusweichen),
        ),
        isNot(contains(kGefechtsNachBewegen)),
      );
    });

    test('Gezieltes Ausweichen je Distanzklasse H 8 / N 4 / S 2', () {
      for (final (dk, wert) in [('H', 8), ('N', 4), ('S', 2)]) {
        final p = pruefeGefechtsaktion(
          _mitDk(dk),
          _nahkampf,
          Gefechtsaktion.gezieltesAusweichen,
        );
        expect(anteile(p), containsPair(kGefechtsGezieltesAusweichen, wert));
        _pruefeInvarianten(p, 'DK $dk');
      }
    });

    test('Distanzwechsel, Gegner und Umwandlung stehen einzeln da', () {
      final wechsel = pruefeGefechtsaktion(
        _mitDk('N'),
        _nahkampf,
        Gefechtsaktion.angriff,
        distanzSchritte: 2,
      );
      expect(anteile(wechsel), containsPair(kGefechtsDistanzwechsel, 8));
      final gegner = pruefeGefechtsaktion(
        _mitDk('N').copyWith(gegner: 3),
        _nahkampf,
        Gefechtsaktion.freiesAusweichen,
      );
      expect(anteile(gegner), containsPair(kGefechtsWeitereGegner, 4));
      final zweiteAt = pruefeGefechtsaktion(
        _zustaende(_mitDk)['Zweite AT']!,
        _nahkampf,
        Gefechtsaktion.angriff,
      );
      expect(anteile(zweiteAt), containsPair(kGefechtsZweiteAttacke, 4));
      final zweitePa = pruefeGefechtsaktion(
        _zustaende(_mitDk)['Zweite PA']!,
        _nahkampf,
        Gefechtsaktion.parade,
      );
      expect(anteile(zweitePa), containsPair(kGefechtsZweiteParade, 4));
    });

    test('Schild-WM-Abzug und Fernkampf-Zuschläge', () {
      final schild = pruefeGefechtsaktion(
        _zustaende(_mitDk)['Finte, Schild-WM weg']!,
        _nahkampf,
        Gefechtsaktion.schildparade,
      );
      expect(anteile(schild), containsPair('Schild-WM entfällt', 2));
      expect(anteile(schild), containsPair('Gegnerische Finte', 2));
      final fk = pruefeGefechtsaktion(
        _zustaende(_mitDk)['Fernkampf mit Getümmel']!,
        _fernkampf,
        Gefechtsaktion.angriff,
      );
      expect(anteile(fk), containsPair('Entfernung', 4));
      expect(anteile(fk), containsPair('Zielsituation', 2));
      expect(anteile(fk).keys, contains('Kampfgetümmel'));
      _pruefeInvarianten(fk, 'Fernkampf');
    });

    test('Erschwernis-Herleitung nennt den Rechenweg bekannter Anteile', () {
      final p = pruefeGefechtsaktion(
        _mitDk('H'),
        _nahkampf,
        Gefechtsaktion.gezieltesAusweichen,
      );
      final schritt = herleiteGefechtsErschwernis(p)!.schritte
          .singleWhere((s) => s.bezeichnung == kGefechtsGezieltesAusweichen);
      expect(schritt.formel, 'H +8, N +4, S +2');
    });

    test('Zielwert: Grundwert, INI-Bonus der Sitzung, dann Erschwernis', () {
      final s = beginneGefecht(40, dk: 'N').copyWith(bewegt: true);
      final bonus = gefechtsIniBonus(s, _nahkampf);
      expect(bonus, greaterThan(0));
      final p = pruefeGefechtsaktion(s, _nahkampf, Gefechtsaktion.parade);
      final h = herleiteGefechtsZielwert(p)!;
      expect(h.schritte.map((e) => e.bezeichnung).toList(), [
        'PA 0',
        'PA 1',
        'INI-Bonus (Sitzung)',
        'Erschwernis',
      ]);
      expect(h.schritte.first.betrag, 9);
      expect(h.schritte[2].betrag, bonus);
      expect(h.wert, _nahkampf.pa + bonus - p.erschwernis);
    });
  });

  group('Dialogpfad mit echtem Helden', () {
    HeroComputedSnapshot snapshot() => buildHeroComputedSnapshot(
      hero: testHero().copyWith(
        combatConfig: const CombatConfig(
          weapons: [
            MainWeaponSlot(id: 'main', name: 'Schwert', distanceClass: 'N'),
          ],
        ),
      ),
      state: const HeroState.empty(),
      catalog: testCatalog,
      epicAdvantagesActive: false,
    );

    GefechtAuftrag auftrag(
      Gefechtsaktion aktion, {
      int zuschlag = 0,
      int finte = 0,
      int wuchtschlag = 0,
      int? zielwert,
    }) => GefechtAuftrag(
      aktion: aktion,
      titel: 'Test',
      zuschlag: zuschlag,
      dk: 'N',
      dauer: 1,
      kosten: 1,
      finte: finte,
      wuchtschlag: wuchtschlag,
      zielwert: zielwert,
      kontext: const Gefechtskontext(
        angriffsart: Gefechtsangriffsart.nahkampf,
        finte: 1,
        platzZumAusweichen: true,
        weitereRegelnGeprueft: true,
      ),
    );

    test('Ansagen und Zuschlag ergänzen benannte Schritte', () {
      final snap = snapshot();
      for (final aktion in [
        Gefechtsaktion.angriff,
        Gefechtsaktion.parade,
        Gefechtsaktion.freiesAusweichen,
        Gefechtsaktion.gezieltesAusweichen,
      ]) {
        final p = pruefeGefechtAuftrag(
          const Gefechtszustand(iniWurf: 30, dk: 'N', bewegt: true),
          snap,
          testCatalog,
          auftrag(aktion, zuschlag: 2, finte: 1, wuchtschlag: 1),
        );
        _pruefeInvarianten(p, '$aktion');
      }
      final angriff = pruefeGefechtAuftrag(
        const Gefechtszustand(iniWurf: 30, dk: 'N'),
        snap,
        testCatalog,
        auftrag(Gefechtsaktion.angriff, zuschlag: 2, finte: 1, wuchtschlag: 1),
      );
      final namen = herleiteGefechtsErschwernis(angriff)!.schritte
          .map((e) => e.bezeichnung);
      expect(
        namen,
        containsAll(['Weitere Erschwernis', 'Finte', 'Wuchtschlag']),
      );
      expect(herleiteGefechtsZielwert(angriff)!.wert, angriff.zielwert);
    });

    test('Manöver benennen Zuschlag, Schildführung und Waffenmeister', () {
      final snap = snapshot();
      final p = pruefeGefechtsmanoever(
        const Gefechtszustand(iniWurf: 12, dk: 'N'),
        snap,
        testCatalog,
        ManeuverDef(
          id: 'man_ausfall',
          name: 'Ausfall',
          typ: 'Angriff',
          erschwernis: 'Angriff +2',
        ),
        zuschlag: 1,
      );
      _pruefeInvarianten(p, 'Ausfall');
      expect(
        {for (final m in p.modifikatoren) m.name: m.wert},
        allOf(
          containsPair('Manöverzuschlag', 2),
          containsPair('Weitere Erschwernis', 1),
        ),
      );
    });

    test('Manuelle Handlung zeigt nur den bestätigten Grundzielwert', () {
      final p = pruefeGefechtAuftrag(
        const Gefechtszustand(iniWurf: 12, dk: 'N'),
        snapshot(),
        testCatalog,
        GefechtAuftrag(
          aktion: Gefechtsaktion.handlung,
          titel: 'Manuell',
          zuschlag: 2,
          dk: 'N',
          dauer: 1,
          kosten: 1,
          manuell: true,
          zielwert: 11,
        ),
      );
      _pruefeInvarianten(p, 'Manuell');
      expect(herleiteGefechtsZielwert(p)!.wert, 9);
    });

    test('Alle Kampfmittel der Profile liefern konsistente Herleitungen', () {
      final snap = snapshot();
      for (final profil in gefechtsKampfmittelprofile(snap)) {
        final w = gefechtswerteFuer(
          snap,
          katalog: testCatalog,
          kampfmittel: profil.wahl,
        );
        for (final aktion in Gefechtsaktion.values) {
          _pruefeInvarianten(
            pruefeGefechtsaktion(beginneGefecht(12, dk: 'N'), w, aktion),
            '${profil.name} $aktion',
          );
        }
      }
    });
  });
}
