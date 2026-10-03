import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_auftrag.dart';
import 'package:dsa_heldenverwaltung/domain/gefecht_kontext.dart';
import 'package:dsa_heldenverwaltung/domain/hero_state.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_auftrag_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_filter_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_held_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/gefecht_rules.dart';
import 'package:dsa_heldenverwaltung/state/hero_computed_snapshot.dart';

import '../ui2/shell/karto_test_support.dart';

void main() {
  test('Aktive Katalogeinträge mit leerem Typ behalten ihre Kategorien', () {
    final json = jsonDecode(
      File('assets/catalogs/house_rules_v1/manoever.json').readAsStringSync(),
    ) as List;
    final katalog = json
        .map((m) => ManeuverDef.fromJson(m as Map<String, dynamic>))
        .toList();
    for (final id in [
      'man_niederwerfen',
      'man_offensiver_distanzklassenwechsel',
    ]) {
      final m = katalog.singleWhere((m) => m.id == id);
      expect(m.typ, isEmpty);
      expect(gefechtsManoeverkategorien(m), {GefechtsManoeverfilter.angriff});
    }
    expect(
      gefechtsManoeverkategorien(
        const ManeuverDef(
          id: 'man_formations_parade',
          name: 'Formations-Parade',
        ),
      ),
      {GefechtsManoeverfilter.verteidigung},
    );
  });
  final snapshot = buildHeroComputedSnapshot(
    hero: testHero().copyWith(
      combatConfig: const CombatConfig(
        weapons: [MainWeaponSlot(id: 'a', name: 'Schwert', distanceClass: 'N')],
      ),
    ),
    state: const HeroState.empty(),
    catalog: testCatalog,
    epicAdvantagesActive: false,
  );
  GefechtAuftrag auftrag({
    ManeuverDef? m,
    String? dk = 'N',
    int kosten = 1,
    int dauer = 1,
    bool manuell = false,
    int? zielwert,
    List<String> bestaetigt = const [],
    List<String> fehler = const [],
  }) => GefechtAuftrag(
    aktion: Gefechtsaktion.angriff,
    titel: 'Test',
    zuschlag: 0,
    dk: dk,
    dauer: dauer,
    kosten: kosten,
    manoever: m,
    manuell: manuell,
    zielwert: zielwert,
    bestaetigteEntscheidungen: bestaetigt,
    eingabefehler: fehler,
  );
  Gefechtspruefung pruefen(GefechtAuftrag a) => pruefeGefechtAuftrag(
    const Gefechtszustand(iniWurf: 6, dk: 'N'),
    snapshot,
    testCatalog,
    a,
  );

  for (final id in ['man_formations_parade', 'man_seitenwechsel']) {
    test('$id ohne Typ verwendet PA-Zielwert und verbraucht nur PA', () {
      final json = jsonDecode(
        File('assets/catalogs/house_rules_v1/manoever.json').readAsStringSync(),
      ) as List;
      final katalog = json
          .map((m) => ManeuverDef.fromJson(m as Map<String, dynamic>))
          .toList();
      final m = katalog.singleWhere((m) => m.id == id);
      final hero = testHero();
      const k = RulesCatalog(
        version: 'test',
        source: 'test',
        talents: [],
        spells: [],
        weapons: [],
        combatSpecialAbilities: [
          CombatSpecialAbilityDef(
            id: 'ksf_klingentaenzer',
            name: 'Klingentänzer',
          ),
        ],
      );
      final snap = buildHeroComputedSnapshot(
        hero: hero.copyWith(
          attributes: hero.attributes.copyWith(ge: 18),
          combatConfig: const CombatConfig(
            weapons: [
              MainWeaponSlot(id: 'a', name: 'Schwert', distanceClass: 'N'),
            ],
            specialRules: CombatSpecialRules(klingentaenzer: true),
          ),
        ),
        state: const HeroState.empty(),
        catalog: k,
        epicAdvantagesActive: false,
      );
      const s = Gefechtszustand(
        iniWurf: 6,
        dk: 'N',
        kontext: Gefechtskontext(
          angriffsart: Gefechtsangriffsart.nahkampf,
          finte: 3,
          paradeVerboten: false,
        ),
      );
      expect(m.typ, isEmpty);
      expect(gefechtsManoeverkategorien(m), {
        GefechtsManoeverfilter.verteidigung,
      });
      expect(gefechtsManoeveraktion(m), Gefechtsaktion.parade);
      final p = pruefeGefechtAuftrag(s, snap, k, auftrag(m: m));
      final w = gefechtswerteFuer(snap, katalog: k);
      final pa = pruefeGefechtsaktion(s, w, Gefechtsaktion.parade);
      final at = pruefeGefechtsaktion(s, w, Gefechtsaktion.angriff);
      expect(p.aktion, Gefechtsaktion.parade);
      expect(p.ausfuehrbar, isTrue, reason: p.gruende.join(' '));
      expect(p.zielwert, pa.zielwert);
      expect(p.zielwert, isNot(at.zielwert));
      final nachher = verbraucheGefechtsaktion(s, w, p, erfolg: true);
      expect(nachher.paradenVerbraucht, 1);
      expect(nachher.angriffeVerbraucht, 0);
      expect(nachher.regulaereParade, isTrue);
      expect(nachher.regulaereAttacke, isFalse);
      expect(nachher.kontext.finte, isNull);
    });
  }

  test('Fehlende DK bleibt auch nach Kostenänderung konkret fehlend', () {
    const m = ManeuverDef(id: 'a', name: 'Attacke', typ: 'Attacke');
    final p = pruefen(auftrag(m: m, dk: null, kosten: 2));
    expect(p.ausfuehrbar, isFalse);
    expect(
      p.fehlendeAngaben,
      contains('Tatsächliche DK und Waffen-DK festlegen.'),
    );
  });
  test('Passive Sonderfertigkeit erhält keine ausführbare Attacke', () {
    const m = ManeuverDef(id: 'a', name: 'Scharfschütze', typ: '');
    final p = pruefen(auftrag(m: m));
    expect(p.ausfuehrbar, isFalse);
    expect(
      p.sperrgruende,
      contains(
        'Diese Sonderfertigkeit besitzt keine ausführbare Einzelaktion.',
      ),
    );
  });
  test(
    'Gemischte AT/PA sind in beiden Kategorien und Filter wirken gemeinsam',
    () {
      const m = ManeuverDef(
        id: 'a',
        name: 'Gemischt',
        typ: 'Ringen-AT / Ringen-PA',
      );
      expect(gefechtsManoeveraktion(m), Gefechtsaktion.parade);
      for (final k in [
        GefechtsManoeverfilter.angriff,
        GefechtsManoeverfilter.verteidigung,
      ]) {
        expect(
          gefechtsManoeverImFilter(
            m,
            kategorie: k,
            suche: 'gem',
            nurErlernte: true,
            ohneSperre: true,
            erlernt: true,
          ),
          isTrue,
        );
        expect(
          gefechtsManoeverImFilter(
            m,
            kategorie: k,
            nurErlernte: true,
            erlernt: false,
          ),
          isFalse,
        );
        expect(
          gefechtsManoeverImFilter(
            m,
            kategorie: k,
            ohneSperre: true,
            gesperrt: true,
          ),
          isFalse,
        );
      }
      expect(
        gefechtsManoeverkategorien(const ManeuverDef(id: 'b', name: 'Passiv')),
        {GefechtsManoeverfilter.sonstige},
      );
    },
  );
  test(
    'Hinweise sperren nicht und feste Zuschläge werden genau einmal gerechnet',
    () {
      const m = ManeuverDef(
        id: 'a',
        name: 'Attacke',
        typ: 'Attacke',
        erschwernis: '+4',
      );
      final basis = pruefen(auftrag());
      final p = pruefen(auftrag(m: m));
      expect(p.ausfuehrbar, isTrue);
      expect(p.hinweise, isNotEmpty);
      expect(p.zielwert, basis.zielwert! - 4);
    },
  );
  test(
    'Ungültige Zahlen und manuelle Entscheidungen bleiben konkrete Pflichten',
    () {
      final p = pruefen(
        auftrag(
          dauer: 0,
          kosten: -1,
          fehler: ['Weitere Erschwernis muss eine ganze Zahl sein.'],
        ),
      );
      expect(p.ausfuehrbar, isFalse);
      expect(p.fehlendeAngaben.length, 3);
      final manuell = pruefen(auftrag(manuell: true, zielwert: 12));
      expect(manuell.entscheidungen, [
        'Wirkung und Ressourcen dieser Sonderaktion festgelegt.',
      ]);
      final bestaetigt = pruefen(
        auftrag(
          manuell: true,
          zielwert: 12,
          bestaetigt: manuell.entscheidungen,
        ),
      );
      expect(bestaetigt.ausfuehrbar, isTrue);
      expect(pruefen(auftrag(manuell: true)).fehlendeAngaben, isNotEmpty);
    },
  );
  test('Schildsichtbarkeit folgt grundsätzlich nutzbarer Ausrüstung', () {
    expect(gefechtsSchildparadeSichtbar(snapshot), isFalse);
    for (final einhaendig in [true, false]) {
      final schild = buildHeroComputedSnapshot(
        hero: testHero().copyWith(
          combatConfig: CombatConfig(
            weapons: [
              MainWeaponSlot(id: 'a', name: 'Schwert', isOneHanded: einhaendig),
            ],
            offhandEquipment: const [
              OffhandEquipmentEntry(
                id: 's',
                name: 'Schild',
                type: OffhandEquipmentType.shield,
              ),
            ],
            offhandAssignment: const OffhandAssignment(equipmentIndex: 0),
          ),
        ),
        state: const HeroState.empty(),
        catalog: testCatalog,
        epicAdvantagesActive: false,
      );
      expect(gefechtsSchildparadeSichtbar(schild), einhaendig);
    }
  });
}
