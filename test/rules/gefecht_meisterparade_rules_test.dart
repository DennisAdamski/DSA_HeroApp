import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_auftrag_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_ablauf_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_meisterparade_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_kampfmittel_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_laden_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import '../ui2/shell/karto_test_support.dart';
import 'gefecht_laden_rules_test.dart' as fk;

/// Kleinster ausführbarer Katalogeintrag; reale Lern- und Waffenprüfung bleibt aktiv.
const meisterparade = ManeuverDef(
  id: 'man_meisterparade',
  name: 'Meisterparade',
  typ: 'Abwehraktion',
  erschwernis: 'Abwehr +Ansage',
  mussSeparatErlerntWerden: true,
);

/// Grund-PA 18, TaW 16, ohne die aktuelle gegnerische Finte.
HeroComputedSnapshot mpSnapshot({
  String talent = 'tal_schwerter',
  bool gelernt = true,
  int be = 0,
  int rg = 0,
  bool schild = false,
  bool sk2 = true,
  bool fehlenderTaw = false,
}) => buildHeroComputedSnapshot(
  hero: testHero().copyWith(
    talents: fehlenderTaw
        ? {}
        : {talent: const HeroTalentEntry(talentValue: 16)},
    combatConfig: CombatConfig(
      weapons: [
        MainWeaponSlot(
          id: 'a',
          name: 'Schwert',
          talentId: talent,
          distanceClass: 'N',
          wmPa: 10,
          wmAt: 3,
        ),
      ],
      armor: ArmorConfig(
        globalArmorTrainingLevel: rg,
        pieces: [
          ArmorPiece(
            id: 'r',
            name: 'Rüstung',
            isActive: true,
            be: be,
            rg1Active: rg == 1,
          ),
        ],
      ),
      offhandEquipment: schild
          ? [
              const OffhandEquipmentEntry(
                id: 's',
                name: 'Schild',
                type: OffhandEquipmentType.shield,
              ),
            ]
          : [],
      offhandAssignment: schild
          ? const OffhandAssignment(equipmentIndex: 0)
          : const OffhandAssignment(),
      specialRules: CombatSpecialRules(
        activeManeuvers: gelernt ? ['man_meisterparade'] : [],
        schildkampfII: sk2,
      ),
    ),
  ),
  state: const HeroState.empty(),
  catalog: testCatalog,
  epicAdvantagesActive: false,
);

/// Angriffskontext ist konkret; die freie Zusatzerschwernis bleibt unabhängig.
GefechtAuftrag mpAuftrag({
  int ansage = 3,
  int extra = 0,
  int finte = 0,
  int? schildgrenze,
}) => GefechtAuftrag(
  aktion: Gefechtsaktion.parade,
  titel: 'Meisterparade',
  zuschlag: extra,
  dk: 'N',
  dauer: 1,
  kosten: 1,
  manoever: meisterparade,
  meisterparadeAnsage: ansage,
  schildAnsagegrenze: schildgrenze,
  kontext: Gefechtskontext(
    angriffsart: Gefechtsangriffsart.nahkampf,
    finte: finte,
    situationsZuschlag: 0,
    schildWmWirksam: true,
  ),
);

void main() {
  const s = Gefechtszustand(iniWurf: 6, dk: 'N');
  test('Eigene Ansage, gegnerische Finte und Extra zählen jeweils einmal', () {
    final snap = mpSnapshot();
    final p = pruefeGefechtAuftrag(
      s,
      snap,
      testCatalog,
      mpAuftrag(ansage: 4, finte: 2, extra: 1),
    );
    expect(p.ausfuehrbar, true);
    expect(p.zielwert, 11);
    expect(p.meisterparadeAnsage, 4);
    expect(
      p.modifikatoren
          .where((m) => m.name == 'Meisterparade-Ansage')
          .single
          .wert,
      4,
    );
  });
  test('Ansagegrenze nutzt PA vor Finte und TaW statt erleichtertem Ziel', () {
    final snap = mpSnapshot();
    expect(
      pruefeGefechtAuftrag(
        s,
        snap,
        testCatalog,
        mpAuftrag(ansage: 16, finte: 5),
      ).ausfuehrbar,
      true,
    );
    for (final n in [-1, 17]) {
      expect(
        pruefeGefechtAuftrag(
          s.copyWith(meisterparadeBonus: 20),
          snap,
          testCatalog,
          mpAuftrag(ansage: n),
        ).ausfuehrbar,
        false,
      );
    }
    expect(
      pruefeGefechtAuftrag(
        s,
        mpSnapshot(fehlenderTaw: true),
        testCatalog,
        mpAuftrag(),
      ).fehlendeAngaben.join(' '),
      contains('TaW'),
    );
  });
  test(
    'Lernstand, verbotene Waffen und effektive Rüstungs-BE bleiben verbindlich',
    () {
      for (final snap in [
        mpSnapshot(gelernt: false),
        mpSnapshot(talent: 'tal_kettenwaffen'),
        mpSnapshot(talent: 'tal_zweihandflegel'),
        mpSnapshot(be: 5),
      ]) {
        expect(
          pruefeGefechtAuftrag(s, snap, testCatalog, mpAuftrag()).ausfuehrbar,
          false,
        );
      }
      expect(
        pruefeGefechtAuftrag(
          s,
          mpSnapshot(be: 5, rg: 1),
          testCatalog,
          mpAuftrag(ansage: 1),
        ).ausfuehrbar,
        true,
      );
    },
  );
  test(
    'Schild verlangt SK II und eigene manuelle Grenze statt Hauptwaffen-TaW',
    () {
      final snap = mpSnapshot(schild: true);
      expect(
        pruefeGefechtAuftrag(
          s,
          snap,
          testCatalog,
          mpAuftrag(),
        ).fehlendeAngaben.join(' '),
        contains('Schild-Ansagegrenze'),
      );
      for (final n in [-1, 2]) {
        expect(
          pruefeGefechtAuftrag(
            s,
            snap,
            testCatalog,
            mpAuftrag(schildgrenze: n),
          ).ausfuehrbar,
          false,
        );
      }
      expect(
        pruefeGefechtAuftrag(
          s,
          snap,
          testCatalog,
          mpAuftrag(schildgrenze: 3),
        ).ausfuehrbar,
        true,
      );
      expect(
        pruefeGefechtAuftrag(
          s,
          snap,
          testCatalog,
          mpAuftrag(ansage: 0),
        ).ausfuehrbar,
        true,
      );
      expect(
        pruefeGefechtAuftrag(
          s,
          mpSnapshot(schild: true, sk2: false),
          testCatalog,
          mpAuftrag(schildgrenze: 3),
        ).ausfuehrbar,
        false,
      );
      expect(
        pruefeGefechtAuftrag(
          s,
          snap,
          testCatalog,
          mpAuftrag(ansage: 30, schildgrenze: 30),
        ).ausfuehrbar,
        false,
      );
    },
  );
  test('Ansage ohne Meisterparade ist gesperrt', () {
    const a = GefechtAuftrag(
      aktion: Gefechtsaktion.angriff,
      titel: 'AT',
      zuschlag: 0,
      dk: 'N',
      dauer: 1,
      kosten: 1,
      meisterparadeAnsage: 1,
    );
    expect(
      pruefeGefechtAuftrag(s, mpSnapshot(), testCatalog, a).ausfuehrbar,
      false,
    );
  });
  test('Schild-Meisterparade bleibt trotz Kettenwaffen-Hauptwaffe mit SK II möglich', () {
    final snap = mpSnapshot(schild: true, talent: 'tal_kettenwaffen');
    final p = pruefeGefechtAuftrag(
      s,
      snap,
      testCatalog,
      mpAuftrag(schildgrenze: 3),
    );
    expect(p.ausfuehrbar, true);
    expect(p.kampfmittel!.art, GefechtsKampfmittelArt.schild);
  });
  test(
    'Negative PA und bekanntes Paradeverbot werden nicht vom Bonus aufgehoben',
    () {
      final basis = mpSnapshot();
      final snap = buildHeroComputedSnapshot(
        hero: basis.hero.copyWith(
          combatConfig: basis.hero.combatConfig.copyWith(
            weapons: [
              basis.hero.combatConfig.selectedWeapon.copyWith(wmPa: -30),
            ],
          ),
        ),
        state: basis.state,
        catalog: testCatalog,
        epicAdvantagesActive: false,
      );
      final p = pruefeGefechtAuftrag(
        s.copyWith(meisterparadeBonus: 40),
        snap,
        testCatalog,
        mpAuftrag(),
      );
      expect(p.ausfuehrbar, false);
      expect(p.fehlendeAngaben.join(' '), contains('PA'));
      final verboten = GefechtAuftrag(
        aktion: Gefechtsaktion.parade,
        titel: 'MP',
        zuschlag: 0,
        dk: 'N',
        dauer: 1,
        kosten: 1,
        manoever: meisterparade,
        meisterparadeAnsage: 3,
        kontext: const Gefechtskontext(
          angriffsart: Gefechtsangriffsart.nahkampf,
          finte: 0,
          paradeVerboten: true,
        ),
      );
      expect(
        pruefeGefechtAuftrag(
          s.copyWith(meisterparadeBonus: 40),
          basis,
          testCatalog,
          verboten,
        ).ausfuehrbar,
        false,
      );
    },
  );
  test('Gegenhalten erhält Bonus auf AT-basierte Abwehr genau einmal', () {
    final snap = mpSnapshot();
    const m = ManeuverDef(
      id: 'man_gegenhalten',
      name: 'Gegenhalten',
      typ: 'Abwehraktion',
      erschwernis: '+4',
    );
    const a = GefechtAuftrag(
      aktion: Gefechtsaktion.parade,
      titel: 'Gegenhalten',
      zuschlag: 0,
      dk: 'N',
      dauer: 1,
      kosten: 1,
      manoever: m,
      kontext: Gefechtskontext(
        angriffsart: Gefechtsangriffsart.nahkampf,
        finte: 0,
        situationsZuschlag: 0,
      ),
    );
    final p = pruefeGefechtAuftrag(
      s.copyWith(meisterparadeBonus: 3),
      snap,
      testCatalog,
      a,
    );
    expect(p.zielwert, 10);
    expect(gefechtRequestFuerAuftrag(a, p)!.targets.single.value, 10);
    expect(p.verbrauchterMeisterparadeBonus, 3);
  });
  test('Nur bestätigter manueller Angriff/Abwehr verbraucht Bonus, keine Hilfsaktion', () {
    final snap = mpSnapshot();
    for (final art in [
      null,
      Gefechtsaktion.handlung,
      Gefechtsaktion.angriff,
      Gefechtsaktion.parade,
    ]) {
      final a = GefechtAuftrag(
        aktion: Gefechtsaktion.handlung,
        titel: 'Manuell',
        zuschlag: 0,
        dk: 'N',
        dauer: 1,
        kosten: 1,
        manuell: true,
        zielwert: 12,
        manuelleKampfaktion: art,
        bestaetigteEntscheidungen: const [
          'Wirkung und Ressourcen dieser Sonderaktion festgelegt.',
        ],
      );
      final p = pruefeGefechtAuftrag(
        s.copyWith(meisterparadeBonus: 4),
        snap,
        testCatalog,
        a,
      );
      final nutzt =
          art == Gefechtsaktion.angriff || art == Gefechtsaktion.parade;
      expect(p.ausfuehrbar, true);
      expect(p.zielwert, nutzt ? 16 : 12);
      final gebucht = verbraucheGefechtsaktion(
        s.copyWith(meisterparadeBonus: 4),
        gefechtswerteFuer(snap),
        p,
        erfolg: false,
      );
      expect(gebucht.meisterparadeBonus, nutzt ? 0 : 4);
    }
  });
  test('Erfolgsbonus verändert keine Gegnerfinte oder TP-Wirkung', () {
    final snap = mpSnapshot();
    final a = mpAuftrag(ansage: 3);
    final p = pruefeGefechtAuftrag(
      s.copyWith(meisterparadeBonus: 4),
      snap,
      testCatalog,
      a,
    );
    expect(
      p.modifikatoren.where((m) => m.name == 'Meisterparade-Bonus').single.wert,
      -4,
    );
    expect(a.finte, 0);
    expect(a.wuchtschlag, 0);
  });
  test('Parierwaffen-Meisterparade erhält Linkhandpflicht und konkretes Kombinationsprofil', () {
    final basis = mpSnapshot();
    for (final linkhand in [false, true]) {
      final snap = buildHeroComputedSnapshot(
        hero: basis.hero.copyWith(
          combatConfig: basis.hero.combatConfig.copyWith(
            offhandEquipment: const [
              OffhandEquipmentEntry(id: 'pw', name: 'Linkhanddolch', paMod: 2),
            ],
            offhandAssignment: const OffhandAssignment(equipmentIndex: 0),
            specialRules: basis.hero.combatConfig.specialRules.copyWith(
              linkhandActive: linkhand,
            ),
          ),
        ),
        state: basis.state,
        catalog: testCatalog,
        epicAdvantagesActive: false,
      );
      const a = GefechtAuftrag(
        aktion: Gefechtsaktion.parade,
        titel: 'MP',
        zuschlag: 0,
        dk: 'N',
        dauer: 1,
        kosten: 1,
        meisterparadeAnsage: 2,
        manoever: meisterparade,
        kampfmittel: GefechtsKampfmittelwahl(
          GefechtsKampfmittelArt.parierwaffe,
          'pw',
        ),
        kontext: Gefechtskontext(
          angriffsart: Gefechtsangriffsart.nahkampf,
          finte: 0,
          situationsZuschlag: 0,
        ),
      );
      final p = pruefeGefechtAuftrag(s, snap, testCatalog, a);
      expect(p.ausfuehrbar, linkhand);
      if (linkhand) {
        expect(
          p.zielwert,
          gefechtsKampfmittelFuer(snap, a.kampfmittel)!.pa! - 2,
        );
      }
    }
  });
  test('Bezahltes Laden und Zielen erhält Bonus, erst der frische Schuss verbraucht ihn', () {
    final snap = fk.ladeSnapshot();
    var zustand = beginneGefechtsLaden(
      s.copyWith(meisterparadeBonus: 4),
      snap,
      fk.mittel,
      anfangGeladen: false,
    );
    while ((zustand.handlung?.verbleibend ?? 0) > 0) {
      zustand = bezahleGefechtsVorbereitung(
        naechsteGefechtsrunde(zustand),
        snap,
      );
    }
    expect(zustand.meisterparadeBonus, 4);
    zustand = naechsteGefechtsrunde(zustand);
    zustand = beginneGefechtsZielen(zustand, snap, testCatalog, fk.zielauftrag);
    while (zustand.handlung!.verbleibend > 0) {
      zustand = bezahleGefechtsVorbereitung(
        naechsteGefechtsrunde(zustand),
        snap,
      );
    }
    expect(zustand.meisterparadeBonus, 4);
    zustand = naechsteGefechtsrunde(zustand);
    final ohneBonus = pruefeGefechtsZielschuss(
      zustand.copyWith(meisterparadeBonus: 0),
      snap,
      testCatalog,
    );
    final p = pruefeGefechtsZielschuss(zustand, snap, testCatalog);
    expect(p.ausfuehrbar, true);
    expect(p.zielwert, ohneBonus.zielwert! + 4);
    expect(
      gefechtRequestFuerAuftrag(
        gefechtsAktuellerZielauftrag(zustand),
        p,
      )!.targets.single.value,
      p.zielwert,
    );
    final gebucht = verbraucheGefechtsaktion(
      zustand.copyWith(ohneHandlung: true),
      gefechtswerteFuer(snap),
      p,
      erfolg: true,
    );
    expect(gebucht.meisterparadeBonus, 0);
  });
  test(
    'Fehlmanöver nennt ganze Ansage, Dauer und Klingentänzer-Halbierung',
    () {
      final snap = mpSnapshot();
      expect(
        gefechtsMeisterparadeFehlschlag(mpAuftrag(ansage: 3), snap),
        contains('Folgemalus +3'),
      );
      final kt = buildHeroComputedSnapshot(
        hero: snap.hero.copyWith(
          combatConfig: snap.hero.combatConfig.copyWith(
            specialRules: snap.hero.combatConfig.specialRules.copyWith(
              klingentaenzer: true,
            ),
          ),
        ),
        state: snap.state,
        catalog: testCatalog,
        epicAdvantagesActive: false,
      );
      expect(
        gefechtsMeisterparadeFehlschlag(mpAuftrag(ansage: 3), kt),
        contains('Folgemalus +2'),
      );
    },
  );
  test('Bekannt entfallener Schild-WM reduziert PA-Ansagegrenze, gegnerische Finte nicht', () {
    final basis = mpSnapshot(schild: true);
    final snap = buildHeroComputedSnapshot(
      hero: basis.hero.copyWith(
        combatConfig: basis.hero.combatConfig.copyWith(
          offhandEquipment: const [
            OffhandEquipmentEntry(
              id: 's',
              name: 'Schild',
              type: OffhandEquipmentType.shield,
              paMod: 4,
            ),
          ],
        ),
      ),
      state: basis.state,
      catalog: testCatalog,
      epicAdvantagesActive: false,
    );
    for (final wirksam in [false, true]) {
      final a = GefechtAuftrag(
        aktion: Gefechtsaktion.schildparade,
        titel: 'MP',
        zuschlag: 0,
        dk: 'N',
        dauer: 1,
        kosten: 1,
        manoever: meisterparade,
        meisterparadeAnsage: 14,
        schildAnsagegrenze: 17,
        kontext: Gefechtskontext(
          angriffsart: Gefechtsangriffsart.nahkampf,
          finte: 2,
          situationsZuschlag: 0,
          schildWmWirksam: wirksam,
        ),
      );
      final p = pruefeGefechtAuftrag(s, snap, testCatalog, a);
      expect(
        p.ausfuehrbar,
        wirksam,
        reason:
            'PA ${snap.combatPreviewStats.shieldPa}, mods ${p.modifikatoren.map((m) => '${m.name} ${m.wert}').join(', ')}',
      );
    }
  });
  test('Bonus gilt nächste AT, PA, gezieltes Ausweichen und DK, niemals freie Aktion', () {
    final snap = mpSnapshot();
    for (final aktion in [
      Gefechtsaktion.angriff,
      Gefechtsaktion.parade,
      Gefechtsaktion.gezieltesAusweichen,
      Gefechtsaktion.freiesAusweichen,
      Gefechtsaktion.freieAktion,
    ]) {
      final a = GefechtAuftrag(
        aktion: aktion,
        titel: 'Aktion',
        zuschlag: 0,
        dk: 'N',
        dauer: 1,
        kosten: 1,
        kontext: const Gefechtskontext(
          angriffsart: Gefechtsangriffsart.nahkampf,
          finte: 0,
          platzZumAusweichen: true,
          gegnerzahl: 1,
          situationsZuschlag: 0,
        ),
      );
      final vorher = pruefeGefechtAuftrag(s, snap, testCatalog, a);
      final p = pruefeGefechtAuftrag(
        s.copyWith(meisterparadeBonus: 4),
        snap,
        testCatalog,
        a,
      );
      final nutzt =
          aktion != Gefechtsaktion.freiesAusweichen &&
          aktion != Gefechtsaktion.freieAktion;
      expect(p.verbrauchterMeisterparadeBonus, nutzt ? 4 : 0);
      if (vorher.zielwert != null) {
        expect(p.zielwert, vorher.zielwert! + (nutzt ? 4 : 0));
      }
      if (p.zielwert != null) {
        expect(
          gefechtRequestFuerAuftrag(a, p)!.targets.single.value,
          p.zielwert,
        );
      }
    }
    const dk = GefechtAuftrag(
      aktion: Gefechtsaktion.angriff,
      titel: 'DK',
      zuschlag: 0,
      dk: 'N',
      dauer: 1,
      kosten: 1,
      distanzSchritte: 1,
    );
    expect(
      pruefeGefechtAuftrag(
        s.copyWith(meisterparadeBonus: 4),
        snap,
        testCatalog,
        dk,
      ).zielwert,
      11,
    );
  });
  test('Erfolg ersetzt verbrauchten Bonus; Misslingen erzeugt nichts, Runde erhält ihn', () {
    final snap = mpSnapshot();
    final alt = s.copyWith(meisterparadeBonus: 4);
    final p = pruefeGefechtAuftrag(alt, snap, testCatalog, mpAuftrag());
    for (final erfolg in [true, false]) {
      final result = verbraucheGefechtsaktion(
        alt,
        gefechtswerteFuer(snap),
        p,
        erfolg: erfolg,
      );
      expect(result.meisterparadeBonus, erfolg ? 3 : 0);
      expect(naechsteGefechtsrunde(result).meisterparadeBonus, erfolg ? 3 : 0);
    }
  });
}
