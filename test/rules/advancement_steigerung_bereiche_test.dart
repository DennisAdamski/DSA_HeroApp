import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config/waffenmeister_config.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_merkmal.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_merkmalskenntnis_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_trait_options.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_waffenmeister_options.dart';
import 'package:dsa_heldenverwaltung/rules/derived/karma_gottheit_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/special_ability_visibility_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/trait_advancement_rules.dart';

import '../test_support/real_catalog.dart';

const _attributes = Attributes(
  mu: 14,
  kl: 14,
  inn: 14,
  ch: 12,
  ff: 13,
  ge: 16,
  ko: 14,
  kk: 16,
);

const _hero = HeroSheet(
  id: 'bereiche',
  name: 'Held',
  level: 1,
  attributes: _attributes,
  apTotal: 20000,
  apAvailable: 20000,
);

HeroAdvancementEntry _eintrag(
  AdvancementKind kind,
  String targetId,
  Map<String, String> options, {
  required int apCost,
  String id = 'e1',
}) => HeroAdvancementEntry(
  id: id,
  sessionId: 's',
  createdAt: DateTime.utc(2026, 10, 11),
  kind: kind,
  targetId: targetId,
  label: targetId,
  apCost: apCost,
  options: options,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RulesCatalog catalog;

  setUpAll(() async {
    catalog = (await ladeEchtenRegelkatalog()).catalog;
  });

  HeroTraitDef vorteil(String id) =>
      catalog.advantages.firstWhere((def) => def.id == id);
  HeroTraitDef nachteil(String id) =>
      catalog.disadvantages.firstWhere((def) => def.id == id);

  AdvancementReplay replay(HeroSheet hero, List<HeroAdvancementEntry> e) =>
      replayAdvancements(base: hero, entries: e, catalog: catalog);

  group('GP-Tarife aus dem Katalog', () {
    test('feste, gestufte und punktweise Kosten', () {
      expect(merkmalGpTarif(vorteil('adv_eisern'))!.gp(), 7);
      final regeneration = merkmalGpTarif(vorteil('adv_astrale_regeneration'))!;
      expect(regeneration.gp(wert: 2), 8);
      expect(regeneration.wertAbhaengig, isTrue);
      final hoehenangst = merkmalGpTarif(nachteil('dis_hoehenangst'))!;
      expect(hoehenangst.gp(wert: 6), 9);
      expect(merkmalGpTarif(nachteil('dis_kurzatmig'))!.gp(wert: 4), 2);
    });

    test('Auswahl- und GP-Einheiten bestimmen den Wert', () {
      final arm = merkmalGpTarif(nachteil('dis_einarmig_gelaehmter_arm'))!;
      expect(arm.gp(auswahl: 'Einarmig'), 15);
      expect(arm.gp(auswahl: 'Gelähmter Arm'), 7);
      final merkmal = merkmalGpTarif(nachteil('dis_unfaehigkeit_merkmal'))!;
      expect(merkmal.gp(auswahl: 'Heilung'), 2);
      expect(merkmal.gp(auswahl: 'Temporal'), 4);
      expect(merkmalGpTarif(vorteil('adv_verbindungen'))!.gp(wert: 5), 5);
      expect(merkmalGpTarif(nachteil('dis_angst_vor')), isNull);
    });
  });

  group('Vorteile nachträglich erwerben (WdS S. 170)', () {
    test('nur die freigegebenen Vorteile erscheinen, mit 50 × GP', () {
      final optionen = buildAdvancementOptions(
        hero: _hero,
        catalog: catalog,
      ).where((o) => o.kind == AdvancementKind.advantage).toList();
      expect(
        optionen.map((o) => o.targetId).toSet(),
        kNachtraeglichErwerbbareVorteile.where(
          (id) => catalog.advantages.any((def) => def.id == id),
        ),
      );
      final eisern = optionen.firstWhere((o) => o.targetId == 'adv_eisern');
      expect(eisern.apCost, 350);
      expect(eisern.unavailableReason, isNull);
    });

    test('Erwerb schreibt Liste und Projektion, doppelt ist gesperrt', () {
      final ergebnis = replay(_hero, [
        _eintrag(AdvancementKind.advantage, 'adv_eisern', {
          kMerkmalOptionAuswahl: '',
        }, apCost: 350),
      ]);
      expect(ergebnis.errors, isEmpty);
      expect(ergebnis.hero.vorteilEintraege.single.katalogId, 'adv_eisern');
      expect(ergebnis.hero.vorteileText, 'Eisern');
      expect(ergebnis.hero.apAvailable, _hero.apAvailable - 350);
      final erneut = resolveAdvancementOption(
        hero: ergebnis.hero,
        catalog: catalog,
        kind: AdvancementKind.advantage,
        targetId: 'adv_eisern',
      );
      expect(erneut!.unavailableReason, 'Bereits vorhanden');
    });

    test('gestufte Vorteile kosten nur die GP-Differenz', () {
      final held = _hero.copyWith(
        vorteilEintraege: const [
          HeroMerkmal(
            katalogId: 'adv_astrale_regeneration',
            text: 'Astrale Regeneration 1',
            wert: 1,
          ),
        ],
        vorteileText: 'Astrale Regeneration 1',
        representationen: const ['Mag'],
        persistentMods: _hero.persistentMods,
      );
      final option = resolveAdvancementOption(
        hero: held,
        catalog: catalog,
        kind: AdvancementKind.advantage,
        targetId: 'adv_astrale_regeneration',
        options: const {kMerkmalOptionWert: '2'},
      )!;
      // 50 × (8 − 4) GP; ohne Magiebefähigung bleibt der Vorteil gesperrt.
      expect(option.apCost, 200);
    });

    test('epische Helden erwerben keine Vorteile mehr', () {
      final option = resolveAdvancementOption(
        hero: _hero.copyWith(isEpisch: true),
        catalog: catalog,
        kind: AdvancementKind.advantage,
        targetId: 'adv_eisern',
      )!;
      expect(option.unavailableReason, contains('Epische Stufen'));
    });
  });

  group('Nachteile abbauen (WdS S. 170)', () {
    const goldgier = HeroMerkmal(
      katalogId: 'dis_goldgier',
      text: 'Goldgier 6',
      wert: 6,
    );
    final held = _hero.copyWith(
      nachteilEintraege: const [
        goldgier,
        HeroMerkmal(katalogId: 'dis_albino', text: 'Albino'),
        HeroMerkmal(katalogId: 'dis_gesucht', text: 'Gesucht 1', wert: 1),
      ],
      nachteileText: 'Goldgier 6; Albino; Gesucht 1',
    );

    AdvancementOption abbau(String id, Map<String, String> options) =>
        resolveAdvancementOption(
          hero: held,
          catalog: catalog,
          kind: AdvancementKind.disadvantage,
          targetId: id,
          options: options,
        )!;

    test('Schlechte Eigenschaften sinken je Punkt mit 50 × bzw. 75 × GP', () {
      expect(
        abbau('dis_goldgier', {
          kMerkmalOptionEintrag: 'Goldgier 6',
          kMerkmalOptionZiel: '4',
        }).apCost,
        100,
      );
      expect(
        abbau('dis_goldgier', {
          kMerkmalOptionEintrag: 'Goldgier 6',
          kMerkmalOptionZiel: '4',
          kMerkmalOptionLernweg: SchlechteEigenschaftLernweg.selbststudium.name,
        }).apCost,
        150,
      );
    });

    test('übrige Nachteile kosten 100 × GP, gesellschaftliche nie AP', () {
      expect(
        abbau('dis_albino', {
          kMerkmalOptionEintrag: 'Albino',
          kMerkmalOptionZiel: '0',
        }).apCost,
        700,
      );
      expect(
        abbau('dis_gesucht', {
          kMerkmalOptionEintrag: 'Gesucht 1',
        }).unavailableReason,
        contains('Gesellschaftliche'),
      );
    });

    test('Abbau senkt oder entfernt den Eintrag samt Projektion', () {
      final ergebnis = replay(held, [
        _eintrag(AdvancementKind.disadvantage, 'dis_goldgier', {
          kMerkmalOptionEintrag: 'Goldgier 6',
          kMerkmalOptionZiel: '4',
          kMerkmalOptionLernweg: 'spezielleErfahrung',
        }, apCost: 100),
        _eintrag(
          AdvancementKind.disadvantage,
          'dis_albino',
          {kMerkmalOptionEintrag: 'Albino', kMerkmalOptionZiel: '0'},
          apCost: 700,
          id: 'e2',
        ),
      ]);
      expect(ergebnis.errors, isEmpty);
      expect(ergebnis.hero.nachteilEintraege.map((e) => e.text), [
        'Goldgier 4',
        'Gesucht 1',
      ]);
      expect(ergebnis.hero.nachteileText, 'Goldgier 4; Gesucht 1');
    });

    test('Episch verlangt der Abbau einen Meisterentscheid', () {
      final episch = held.copyWith(isEpisch: true);
      final ohne = replay(episch, [
        _eintrag(AdvancementKind.disadvantage, 'dis_albino', {
          kMerkmalOptionEintrag: 'Albino',
          kMerkmalOptionZiel: '0',
        }, apCost: 700),
      ]);
      expect(ohne.errors.values.single, contains('Meisterentscheid'));
      final mit = replay(episch, [
        _eintrag(AdvancementKind.disadvantage, 'dis_albino', {
          kMerkmalOptionEintrag: 'Albino',
          kMerkmalOptionZiel: '0',
          'meisterentscheid': 'true',
        }, apCost: 700),
      ]);
      expect(mit.errors, isEmpty);
    });
  });

  group('Merkmalskenntnisse (WdH S. 289)', () {
    final magier = _hero.copyWith(representationen: const ['Mag']);

    test('je Merkmal eine Option mit Klassifikationskosten', () {
      final optionen = buildAdvancementOptions(
        hero: magier,
        catalog: catalog,
      ).where((o) => o.isMerkmalskenntnis).toList();
      expect(optionen, hasLength(kAlleMerkmale.length));
      final heilung = optionen.firstWhere(
        (o) => o.options[kMerkmalskenntnisOptionMerkmal] == 'Heilung',
      );
      expect(heilung.apCost, 100);
      expect(heilung.unavailableReason, isNull);
    });

    test('das zweite Merkmal verlangt Leiteigenschaft 13', () {
      expect(merkmalskenntnisLeiteigenschaft(1), isNull);
      expect(merkmalskenntnisLeiteigenschaft(2), 13);
      expect(merkmalskenntnisLeiteigenschaft(3), 15);
      expect(merkmalskenntnisLeiteigenschaft(5), 17);
    });

    test('Erwerb ergänzt das Feld und sperrt die Wiederholung', () {
      final options = {
        'action': kMerkmalskenntnisAktion,
        kMerkmalskenntnisOptionMerkmal: 'Heilung',
      };
      final ergebnis = replay(magier, [
        _eintrag(
          AdvancementKind.magicAbility,
          kMerkmalskenntnisSfId,
          options,
          apCost: 100,
        ),
      ]);
      expect(ergebnis.errors, isEmpty);
      expect(ergebnis.hero.merkmalskenntnisse, ['Heilung']);
      final doppelt = replay(ergebnis.hero, [
        _eintrag(
          AdvancementKind.magicAbility,
          kMerkmalskenntnisSfId,
          options,
          apCost: 100,
          id: 'e2',
        ),
      ]);
      expect(doppelt.errors.values.single, 'Bereits erworben');
    });
  });

  group('Waffenmeister am Kampftalent (WdS S. 192)', () {
    final krieger = _hero.copyWith(
      talents: const {
        'tal_schwerter': HeroTalentEntry(
          talentValue: 18,
          combatSpecializations: ['Langschwert'],
        ),
      },
    );
    const config = WaffenmeisterConfig(
      talentId: 'tal_schwerter',
      weaponType: 'Langschwert',
      requiredAttribute1: 'GE',
      requiredAttribute1Value: 16,
      requiredAttribute2: 'KK',
      requiredAttribute2Value: 16,
    );

    test('Voraussetzungen werden geprüft, die AP-Schwelle bleibt offen', () {
      final option = resolveWaffenmeister(
        AdvancementContext(hero: krieger, catalog: catalog),
        'tal_schwerter',
        {
          'action': kWaffenmeisterAktion,
          kWaffenmeisterOptionKonfiguration: schreibeWaffenmeisterKonfiguration(
            config,
          ),
        },
      )!;
      expect(option.apCost, 400);
      expect(option.unavailableReason, isNull);
      final offen = option.requirements.where((r) => r.istOffen).toList();
      expect(offen.single.sollText, contains('2500 AP'));
    });

    test(
      'Übernahme trägt die Waffenmeisterschaft mit Meisterentscheid ein',
      () {
        final ergebnis = replay(krieger, [
          _eintrag(AdvancementKind.talent, 'tal_schwerter', {
            'action': kWaffenmeisterAktion,
            kWaffenmeisterOptionKonfiguration:
                schreibeWaffenmeisterKonfiguration(config),
            'meisterentscheid': 'true',
          }, apCost: 400),
        ]);
        expect(ergebnis.errors, isEmpty);
        final wm = ergebnis.hero.combatConfig.waffenmeisterschaften.single;
        expect(wm.weaponType, 'Langschwert');
        expect(ergebnis.hero.apAvailable, krieger.apAvailable - 400);
      },
    );

    test('der Waffen-Großmeister gehört zum Talent', () {
      expect(
        grossmeisterFuerTalent(catalog, 'tal_schwerter')?.id,
        'esf_grossmeister_schwerter',
      );
    });
  });

  group('Passung zu Tradition und Gottheit', () {
    test('fremde Traditionsrituale werden ausgeblendet', () {
      final magier = _hero.copyWith(representationen: const ['Mag']);
      final optionen = buildAdvancementOptions(hero: magier, catalog: catalog);
      bool passtNicht(String id) =>
          passtNichtZumHelden(optionen.firstWhere((o) => o.targetId == id));
      expect(passtNicht('magsf_stabzauber'), isFalse);
      expect(passtNicht('magsf_hexenfluesche'), isTrue);
      expect(passtNicht('magsf_elfenlieder'), isTrue);
      expect(passtNicht('magsf_kugelzauber'), isFalse);
    });

    test('Pfade der Erleuchteten folgen der Gottheit', () {
      expect(gottheitPasst('Praios', ['Praios']), isTrue);
      expect(gottheitPasst('Praios', ['Rondra']), isFalse);
      expect(gottheitPasst('Rondra', [kZwoelfgoetterSammelname]), isTrue);
      expect(gottheitPasst('Rastullah', [kZwoelfgoetterSammelname]), isFalse);
      final geweihter = _hero.copyWith(gottheit: 'Praios');
      final optionen = buildAdvancementOptions(
        hero: geweihter,
        catalog: catalog,
      );
      bool passtNicht(String id) =>
          passtNichtZumHelden(optionen.firstWhere((o) => o.targetId == id));
      expect(passtNicht('epfad_praios'), isFalse);
      expect(passtNicht('epfad_rondra'), isTrue);
      // Ohne Gottheit bleibt es ein Hinweis und nichts wird ausgeblendet.
      final ohne = buildAdvancementOptions(hero: _hero, catalog: catalog);
      expect(
        passtNichtZumHelden(
          ohne.firstWhere((o) => o.targetId == 'epfad_rondra'),
        ),
        isFalse,
      );
    });

    test('die Gottheit wird nur bei Belegung geschrieben', () {
      expect(_hero.toJson().containsKey('gottheit'), isFalse);
      final json = _hero.copyWith(gottheit: 'Phex').toJson();
      expect(json['gottheit'], 'Phex');
      expect(HeroSheet.fromJson(json).gottheit, 'Phex');
    });
  });
}
