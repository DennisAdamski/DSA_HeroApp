import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/reisebericht_def.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_reisebericht.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/domain/hero_talent_entry.dart';
import 'package:dsa_heldenverwaltung/rules/derived/reisebericht_rules.dart';

void main() {
  group('isReiseberichtEntryComplete', () {
    test('checkpoint ist complete wenn ID in checkedIds', () {
      const def = ReiseberichtDef(
        id: 'rb_test',
        name: 'Test',
        kategorie: 'kampferfahrungen',
        typ: 'checkpoint',
        ap: 10,
      );
      const empty = HeroReisebericht();
      const checked = HeroReisebericht(checkedIds: {'rb_test'});

      expect(isReiseberichtEntryComplete(def, empty, [def]), isFalse);
      expect(isReiseberichtEntryComplete(def, checked, [def]), isTrue);
    });

    test('multi_requirement braucht alle Anforderungen', () {
      const def = ReiseberichtDef(
        id: 'rb_multi',
        name: 'Multi',
        kategorie: 'koerperliche_erprobungen',
        typ: 'multi_requirement',
        anforderungen: [
          ReiseberichtAnforderungDef(id: 'rb_m_a', name: 'A', ap: 10),
          ReiseberichtAnforderungDef(id: 'rb_m_b', name: 'B', ap: 10),
        ],
      );
      const partial = HeroReisebericht(checkedIds: {'rb_m_a'});
      const full = HeroReisebericht(checkedIds: {'rb_m_a', 'rb_m_b'});

      expect(isReiseberichtEntryComplete(def, partial, [def]), isFalse);
      expect(isReiseberichtEntryComplete(def, full, [def]), isTrue);
    });

    test('collection_fixed zaehlt feste Eintraege', () {
      const def = ReiseberichtDef(
        id: 'rb_coll',
        name: 'Sammlung',
        kategorie: 'gesellschaftliche_erfahrungen',
        typ: 'collection_fixed',
        festeEintraege: [
          ReiseberichtFesteintragDef(id: 'rb_c_1', name: 'Eins'),
          ReiseberichtFesteintragDef(id: 'rb_c_2', name: 'Zwei'),
          ReiseberichtFesteintragDef(id: 'rb_c_3', name: 'Drei'),
        ],
      );
      const partial = HeroReisebericht(checkedIds: {'rb_c_1', 'rb_c_2'});
      const full = HeroReisebericht(checkedIds: {'rb_c_1', 'rb_c_2', 'rb_c_3'});

      expect(countFixedCollectionChecked(def, partial), 2);
      expect(countFixedCollectionChecked(def, full), 3);
      expect(isReiseberichtEntryComplete(def, partial, [def]), isFalse);
      expect(isReiseberichtEntryComplete(def, full, [def]), isTrue);
    });

    test('collection_fixed Schwelle wird erkannt', () {
      const def = ReiseberichtDef(
        id: 'rb_schwelle',
        name: 'Schwelle',
        kategorie: 'gesellschaftliche_erfahrungen',
        typ: 'collection_fixed',
        schwelle: 2,
        festeEintraege: [
          ReiseberichtFesteintragDef(id: 'rb_s_1', name: 'Eins'),
          ReiseberichtFesteintragDef(id: 'rb_s_2', name: 'Zwei'),
          ReiseberichtFesteintragDef(id: 'rb_s_3', name: 'Drei'),
        ],
      );
      const below = HeroReisebericht(checkedIds: {'rb_s_1'});
      const met = HeroReisebericht(checkedIds: {'rb_s_1', 'rb_s_2'});

      expect(isFixedCollectionThresholdMet(def, below), isFalse);
      expect(isFixedCollectionThresholdMet(def, met), isTrue);
    });

    test('grouped_progression prueft Stufen-ID', () {
      const def = ReiseberichtDef(
        id: 'rb_g1',
        name: 'Stufe 1',
        kategorie: 'kampferfahrungen',
        typ: 'grouped_progression',
        gruppeId: 'grp_x',
        stufe: 1,
        ap: 10,
      );
      const empty = HeroReisebericht();
      const checked = HeroReisebericht(checkedIds: {'rb_g1'});

      expect(isReiseberichtEntryComplete(def, empty, [def]), isFalse);
      expect(isReiseberichtEntryComplete(def, checked, [def]), isTrue);
    });

    test('grouped_progression_bonus erfordert alle Stufen', () {
      const s1 = ReiseberichtDef(
        id: 'rb_g1',
        name: 'Stufe 1',
        kategorie: 'k',
        typ: 'grouped_progression',
        gruppeId: 'grp_x',
        stufe: 1,
        ap: 10,
      );
      const s2 = ReiseberichtDef(
        id: 'rb_g2',
        name: 'Stufe 2',
        kategorie: 'k',
        typ: 'grouped_progression',
        gruppeId: 'grp_x',
        stufe: 2,
        ap: 20,
      );
      const bonus = ReiseberichtDef(
        id: 'rb_gb',
        name: 'Gruppenbonus',
        kategorie: 'k',
        typ: 'grouped_progression_bonus',
        gruppeId: 'grp_x',
      );
      final allDefs = [s1, s2, bonus];
      const partial = HeroReisebericht(checkedIds: {'rb_g1'});
      const full = HeroReisebericht(checkedIds: {'rb_g1', 'rb_g2'});

      expect(isReiseberichtEntryComplete(bonus, partial, allDefs), isFalse);
      expect(isReiseberichtEntryComplete(bonus, full, allDefs), isTrue);
    });

    test('meta ist complete wenn alle Nicht-Meta der Kategorie fertig', () {
      const entry1 = ReiseberichtDef(
        id: 'rb_e1',
        name: 'E1',
        kategorie: 'kampferfahrungen',
        typ: 'checkpoint',
        ap: 10,
      );
      const entry2 = ReiseberichtDef(
        id: 'rb_e2',
        name: 'E2',
        kategorie: 'kampferfahrungen',
        typ: 'checkpoint',
        ap: 20,
      );
      const meta = ReiseberichtDef(
        id: 'rb_meta',
        name: 'Meta',
        kategorie: 'kampferfahrungen',
        typ: 'meta',
      );
      final allDefs = [entry1, entry2, meta];
      const partial = HeroReisebericht(checkedIds: {'rb_e1'});
      const full = HeroReisebericht(checkedIds: {'rb_e1', 'rb_e2'});

      expect(isReiseberichtEntryComplete(meta, partial, allDefs), isFalse);
      expect(isReiseberichtEntryComplete(meta, full, allDefs), isTrue);
    });
  });

  group('computePendingRewards', () {
    test('checkpoint vergiebt AP und SE', () {
      const def = ReiseberichtDef(
        id: 'rb_cp',
        name: 'Checkpoint',
        kategorie: 'k',
        typ: 'checkpoint',
        ap: 30,
        se: [ReiseberichtSeDef(ziel: 'talent', name: 'Kriegskunst')],
      );
      const state = HeroReisebericht(checkedIds: {'rb_cp'});

      final rewards = computePendingRewards(catalog: [def], state: state);

      expect(rewards.ap, 30);
      expect(rewards.seRewards.length, 1);
      expect(rewards.seRewards.first.talentName, 'Kriegskunst');
      expect(rewards.newAppliedIds, contains('rb_cp'));
    });

    test('bereits applied IDs werden nicht erneut vergeben', () {
      const def = ReiseberichtDef(
        id: 'rb_cp',
        name: 'Checkpoint',
        kategorie: 'k',
        typ: 'checkpoint',
        ap: 30,
      );
      const state = HeroReisebericht(
        checkedIds: {'rb_cp'},
        appliedRewardIds: {'rb_cp'},
      );

      final rewards = computePendingRewards(catalog: [def], state: state);

      expect(rewards.ap, 0);
      expect(rewards.newAppliedIds, isEmpty);
    });

    test('multi_requirement summiert Anforderungs-AP', () {
      const def = ReiseberichtDef(
        id: 'rb_m',
        name: 'Multi',
        kategorie: 'k',
        typ: 'multi_requirement',
        anforderungen: [
          ReiseberichtAnforderungDef(id: 'rb_m_a', name: 'A', ap: 15),
          ReiseberichtAnforderungDef(id: 'rb_m_b', name: 'B', ap: 25),
        ],
      );
      const state = HeroReisebericht(checkedIds: {'rb_m_a', 'rb_m_b'});

      final rewards = computePendingRewards(catalog: [def], state: state);

      expect(rewards.ap, 40);
      expect(rewards.newAppliedIds, containsAll(['rb_m_a', 'rb_m_b']));
    });

    test('collection_fixed AP pro Eintrag und Schwellen-Belohnung', () {
      const def = ReiseberichtDef(
        id: 'rb_cf',
        name: 'Collection',
        kategorie: 'k',
        typ: 'collection_fixed',
        apProEintrag: 10,
        schwelle: 2,
        schwelleBelohnung: ReiseberichtBonusDef(
          ap: 50,
          talentBoni: [
            ReiseberichtTalentBonusDef(talentName: 'Gassenwissen', wert: 1),
          ],
        ),
        festeEintraege: [
          ReiseberichtFesteintragDef(id: 'rb_cf_1', name: 'Eins'),
          ReiseberichtFesteintragDef(id: 'rb_cf_2', name: 'Zwei'),
          ReiseberichtFesteintragDef(id: 'rb_cf_3', name: 'Drei'),
        ],
      );
      const state = HeroReisebericht(checkedIds: {'rb_cf_1', 'rb_cf_2'});

      final rewards = computePendingRewards(catalog: [def], state: state);

      // 2 Eintraege × 10 AP + 50 AP Schwelle
      expect(rewards.ap, 70);
      expect(rewards.talentBoni.length, 1);
      expect(rewards.talentBoni.first.talentName, 'Gassenwissen');
      expect(rewards.talentBoni.first.wert, 1);
    });

    test('collection_open AP pro Item und SE-Intervall', () {
      const def = ReiseberichtDef(
        id: 'rb_co',
        name: 'Open',
        kategorie: 'k',
        typ: 'collection_open',
        apProEintrag: 20,
        seIntervall: 3,
        se: [ReiseberichtSeDef(ziel: 'talent', name: 'Koerperbeherrschung')],
      );
      const state = HeroReisebericht(
        openEntries: {
          'rb_co': [
            ReiseberichtOpenItem(name: 'Eins'),
            ReiseberichtOpenItem(name: 'Zwei'),
            ReiseberichtOpenItem(name: 'Drei'),
          ],
        },
      );

      final rewards = computePendingRewards(catalog: [def], state: state);

      // 3 Items × 20 AP
      expect(rewards.ap, 60);
      // 3 Items / Intervall 3 = 1 SE
      expect(rewards.seRewards.length, 1);
      expect(rewards.seRewards.first.talentName, 'Koerperbeherrschung');
    });

    test('collection_open mit Klassifikation nutzt Item-AP', () {
      const def = ReiseberichtDef(
        id: 'rb_co_k',
        name: 'Open K',
        kategorie: 'k',
        typ: 'collection_open',
        apProEintrag: 10,
        klassifikationen: [
          ReiseberichtKlassifikationDef(id: 'normal', name: 'Normal', ap: 10),
          ReiseberichtKlassifikationDef(
            id: 'exotisch',
            name: 'Exotisch',
            ap: 20,
          ),
        ],
      );
      const state = HeroReisebericht(
        openEntries: {
          'rb_co_k': [
            ReiseberichtOpenItem(name: 'A', klassifikation: 'normal', ap: 10),
            ReiseberichtOpenItem(name: 'B', klassifikation: 'exotisch', ap: 20),
          ],
        },
      );

      final rewards = computePendingRewards(catalog: [def], state: state);

      // Item-AP: 10 + 20 = 30
      expect(rewards.ap, 30);
    });

    test('wahl-SE nutzt wahlSeZuordnungen', () {
      const def = ReiseberichtDef(
        id: 'rb_wahl',
        name: 'Wahl',
        kategorie: 'k',
        typ: 'checkpoint',
        ap: 30,
        se: [
          ReiseberichtSeDef(
            ziel: 'wahl',
            name: 'Passende SE',
            optionen: ['Reiten', 'Fliegen'],
          ),
        ],
      );
      const state = HeroReisebericht(
        checkedIds: {'rb_wahl'},
        wahlSeZuordnungen: {'rb_wahl': 'Reiten'},
      );

      final rewards = computePendingRewards(catalog: [def], state: state);

      expect(rewards.seRewards.length, 1);
      expect(rewards.seRewards.first.talentName, 'Reiten');
    });

    test('meta vergibt Eigenschaftsbonus', () {
      const entry = ReiseberichtDef(
        id: 'rb_e',
        name: 'E',
        kategorie: 'kampferfahrungen',
        typ: 'checkpoint',
        ap: 10,
      );
      const meta = ReiseberichtDef(
        id: 'rb_meta',
        name: 'Veteran',
        kategorie: 'kampferfahrungen',
        typ: 'meta',
        eigenschaftsBonus: [
          ReiseberichtEigenschaftsBonusDef(eigenschaft: 'mu', wert: 1),
        ],
      );
      // Alle Nicht-Meta der Kategorie muessen complete sein
      const state = HeroReisebericht(checkedIds: {'rb_e'});

      final rewards = computePendingRewards(
        catalog: [entry, meta],
        state: state,
      );

      expect(rewards.eigenschaftsBoni.length, 1);
      expect(rewards.eigenschaftsBoni.first.eigenschaft, 'mu');
      expect(rewards.eigenschaftsBoni.first.wert, 1);
    });
  });

  group('applyReiseberichtRewards', () {
    test('erhoht apTotal und appliedRewardIds', () {
      final hero = HeroSheet(
        id: 'h1',
        name: 'Testor',
        level: 1,
        apTotal: 100,
        attributes: const Attributes(
          mu: 12,
          kl: 12,
          inn: 12,
          ch: 12,
          ff: 12,
          ge: 12,
          ko: 12,
          kk: 12,
        ),
      );
      const rewards = ReiseberichtRewards(ap: 30, newAppliedIds: {'rb_1'});
      const updatedState = HeroReisebericht(checkedIds: {'rb_1'});

      final result = applyReiseberichtRewards(
        hero: hero,
        rewards: rewards,
        updatedState: updatedState,
      );

      expect(result.apTotal, 130);
      expect(result.reisebericht.appliedRewardIds, contains('rb_1'));
    });

    test('wendet SE auf Talente an', () {
      final hero = HeroSheet(
        id: 'h1',
        name: 'Testor',
        level: 1,
        attributes: const Attributes(
          mu: 12,
          kl: 12,
          inn: 12,
          ch: 12,
          ff: 12,
          ge: 12,
          ko: 12,
          kk: 12,
        ),
        talents: const {'Kriegskunst': HeroTalentEntry(talentValue: 5)},
      );
      const rewards = ReiseberichtRewards(
        seRewards: [
          ReiseberichtSeReward(sourceId: 'rb_1', talentName: 'Kriegskunst'),
        ],
        newAppliedIds: {'rb_1'},
      );

      final result = applyReiseberichtRewards(
        hero: hero,
        rewards: rewards,
        updatedState: const HeroReisebericht(checkedIds: {'rb_1'}),
      );

      expect(result.talents['Kriegskunst']!.specialExperiences, 1);
    });

    test('wendet Talent-Modifier an', () {
      final hero = HeroSheet(
        id: 'h1',
        name: 'Testor',
        level: 1,
        attributes: const Attributes(
          mu: 12,
          kl: 12,
          inn: 12,
          ch: 12,
          ff: 12,
          ge: 12,
          ko: 12,
          kk: 12,
        ),
        talents: const {'Gassenwissen': HeroTalentEntry(talentValue: 3)},
      );
      const rewards = ReiseberichtRewards(
        talentBoni: [
          ReiseberichtTalentBonus(
            sourceId: 'rb_schwelle',
            talentName: 'Gassenwissen',
            wert: 1,
            beschreibung: 'Reisebericht: Stadtkenner',
          ),
        ],
        newAppliedIds: {'rb_schwelle'},
      );

      final result = applyReiseberichtRewards(
        hero: hero,
        rewards: rewards,
        updatedState: const HeroReisebericht(),
      );

      expect(result.talents['Gassenwissen']!.talentModifiers.length, 1);
      expect(result.talents['Gassenwissen']!.talentModifiers.first.modifier, 1);
      expect(
        result.talents['Gassenwissen']!.talentModifiers.first.description,
        'Reisebericht: Stadtkenner',
      );
    });

    test('wendet Eigenschaftsbonus an', () {
      final hero = HeroSheet(
        id: 'h1',
        name: 'Testor',
        level: 1,
        attributes: const Attributes(
          mu: 12,
          kl: 12,
          inn: 12,
          ch: 12,
          ff: 12,
          ge: 12,
          ko: 12,
          kk: 12,
        ),
      );
      const rewards = ReiseberichtRewards(
        eigenschaftsBoni: [
          ReiseberichtEigenschaftsBonus(
            sourceId: 'rb_meta',
            eigenschaft: 'mu',
            wert: 1,
          ),
        ],
        newAppliedIds: {'rb_meta'},
      );

      final result = applyReiseberichtRewards(
        hero: hero,
        rewards: rewards,
        updatedState: const HeroReisebericht(),
      );

      expect(result.attributes.mu, 13);
    });
  });

  group('revokeReiseberichtRewards', () {
    test('zieht AP und SE zurueck', () {
      final hero = HeroSheet(
        id: 'h1',
        name: 'Testor',
        level: 1,
        apTotal: 130,
        attributes: const Attributes(
          mu: 13,
          kl: 12,
          inn: 12,
          ch: 12,
          ff: 12,
          ge: 12,
          ko: 12,
          kk: 12,
        ),
        talents: const {
          'Kriegskunst': HeroTalentEntry(talentValue: 5, specialExperiences: 1),
        },
      );
      const rewards = ReiseberichtRewards(
        ap: 30,
        seRewards: [
          ReiseberichtSeReward(sourceId: 'rb_1', talentName: 'Kriegskunst'),
        ],
        eigenschaftsBoni: [
          ReiseberichtEigenschaftsBonus(
            sourceId: 'rb_meta',
            eigenschaft: 'mu',
            wert: 1,
          ),
        ],
        newAppliedIds: {'rb_1', 'rb_meta'},
      );
      const updatedState = HeroReisebericht(
        appliedRewardIds: {'rb_1', 'rb_meta'},
      );

      final result = revokeReiseberichtRewards(
        hero: hero,
        rewards: rewards,
        updatedState: updatedState,
      );

      expect(result.apTotal, 100);
      expect(result.talents['Kriegskunst']!.specialExperiences, 0);
      expect(result.attributes.mu, 12);
      expect(result.reisebericht.appliedRewardIds, isEmpty);
    });

    test('apTotal wird nicht negativ', () {
      final hero = HeroSheet(
        id: 'h1',
        name: 'Testor',
        level: 1,
        apTotal: 10,
        attributes: const Attributes(
          mu: 12,
          kl: 12,
          inn: 12,
          ch: 12,
          ff: 12,
          ge: 12,
          ko: 12,
          kk: 12,
        ),
      );
      const rewards = ReiseberichtRewards(ap: 50, newAppliedIds: {'rb_x'});

      final result = revokeReiseberichtRewards(
        hero: hero,
        rewards: rewards,
        updatedState: const HeroReisebericht(appliedRewardIds: {'rb_x'}),
      );

      expect(result.apTotal, 0);
    });
  });

  // Enthaken nimmt zurück (Buchungsabgleich): Gebucht wird, was im Entwurf
  // erfüllt und noch nicht angewendet ist; zurückgenommen, was gebucht war
  // und im Entwurf nicht mehr erfüllt ist, samt abhängiger Belohnungen.
  group('berechneReiseberichtBuchung', () {
    const kriegskunst = ReiseberichtSeDef(ziel: 'talent', name: 'Kriegskunst');
    const checkpoint = ReiseberichtDef(
      id: 'rb_cp',
      name: 'CP',
      kategorie: 'k1',
      typ: 'checkpoint',
      ap: 30,
      se: [kriegskunst],
    );
    const sammlung = ReiseberichtDef(
      id: 'rb_fix',
      name: 'Fix',
      kategorie: 'k1',
      typ: 'collection_fixed',
      apProEintrag: 5,
      schwelle: 2,
      festeEintraege: [
        ReiseberichtFesteintragDef(id: 'f1', name: 'Eins'),
        ReiseberichtFesteintragDef(id: 'f2', name: 'Zwei'),
        ReiseberichtFesteintragDef(id: 'f3', name: 'Drei'),
      ],
      schwelleBelohnung: ReiseberichtBonusDef(
        ap: 20,
        se: [kriegskunst],
        talentBoni: [
          ReiseberichtTalentBonusDef(talentName: 'Kriegskunst', wert: 1),
        ],
      ),
    );
    const mehrfach = ReiseberichtDef(
      id: 'rb_multi',
      name: 'Multi',
      kategorie: 'k1',
      typ: 'multi_requirement',
      anforderungen: [
        ReiseberichtAnforderungDef(id: 'm1', name: 'M1', ap: 10),
        ReiseberichtAnforderungDef(id: 'm2', name: 'M2', ap: 15),
      ],
    );
    const stufe1 = ReiseberichtDef(
      id: 'g1',
      name: 'G1',
      kategorie: 'k1',
      typ: 'grouped_progression',
      gruppeId: 'g',
      ap: 10,
    );
    const stufe2 = ReiseberichtDef(
      id: 'g2',
      name: 'G2',
      kategorie: 'k1',
      typ: 'grouped_progression',
      gruppeId: 'g',
      ap: 20,
    );
    const gruppenbonus = ReiseberichtDef(
      id: 'gb',
      name: 'Gruppe',
      kategorie: 'k1',
      typ: 'grouped_progression_bonus',
      gruppeId: 'g',
      se: [kriegskunst],
    );
    const zweiteKategorie = ReiseberichtDef(
      id: 'rb_k2',
      name: 'K2',
      kategorie: 'k2',
      typ: 'checkpoint',
      ap: 30,
    );
    const meta = ReiseberichtDef(
      id: 'rb_meta',
      name: 'Meta',
      kategorie: 'k2',
      typ: 'meta',
      ap: 50,
      eigenschaftsBonus: [
        ReiseberichtEigenschaftsBonusDef(eigenschaft: 'mu', wert: 1),
      ],
    );
    const offen = ReiseberichtDef(
      id: 'rb_open',
      name: 'Offen',
      kategorie: 'k3',
      typ: 'collection_open',
      apProEintrag: 5,
    );
    const katalog = <ReiseberichtDef>[
      checkpoint,
      sammlung,
      mehrfach,
      stufe1,
      stufe2,
      gruppenbonus,
      zweiteKategorie,
      meta,
      offen,
    ];

    ReiseberichtBuchung abgleich(
      HeroReisebericht gebucht,
      HeroReisebericht entwurf,
    ) {
      return berechneReiseberichtBuchung(
        catalog: katalog,
        gebucht: gebucht,
        entwurf: entwurf,
      );
    }

    test('Enthaken eines gebuchten Checkpoints nimmt AP und SE zurück', () {
      const gebucht = HeroReisebericht(
        checkedIds: {'rb_cp'},
        appliedRewardIds: {'rb_cp'},
      );

      final buchung = abgleich(gebucht, const HeroReisebericht());

      expect(buchung.zurueck.ap, 30);
      expect(buchung.zurueck.seRewards.single.talentName, 'Kriegskunst');
      expect(buchung.zurueck.newAppliedIds, {'rb_cp'});
      expect(buchung.neu.newAppliedIds, isEmpty);
    });

    test('ein noch nicht gebuchter Haken wird nur entfernt', () {
      const gebucht = HeroReisebericht(checkedIds: {'rb_cp'});

      expect(abgleich(gebucht, const HeroReisebericht()).istLeer, isTrue);
    });

    test('eine unterschrittene Schwelle nimmt ihre Belohnung mit zurück', () {
      const gebucht = HeroReisebericht(
        checkedIds: {'f1', 'f2'},
        appliedRewardIds: {'f1', 'f2', 'rb_fix_schwelle'},
      );

      final buchung = abgleich(gebucht, gebucht.copyWith(checkedIds: {'f1'}));

      expect(buchung.zurueck.newAppliedIds, {'f2', 'rb_fix_schwelle'});
      expect(buchung.zurueck.ap, 25);
      expect(buchung.zurueck.seRewards, hasLength(1));
      expect(
        buchung.zurueck.talentBoni.single.beschreibung,
        'Reisebericht: Fix',
      );
    });

    test('Teilanforderung und Gruppenbonus werden zurückgenommen', () {
      const gebucht = HeroReisebericht(
        checkedIds: {'m1', 'm2', 'g1', 'g2'},
        appliedRewardIds: {'m1', 'm2', 'g1', 'g2', 'gb'},
      );

      final buchung = abgleich(
        gebucht,
        gebucht.copyWith(checkedIds: {'m2', 'g1'}),
      );

      expect(buchung.zurueck.newAppliedIds, {'m1', 'g2', 'gb'});
      expect(buchung.zurueck.ap, 30);
      expect(buchung.zurueck.seRewards, hasLength(1));
    });

    test('ein Meta-Bonus fällt samt Eigenschaftsbonus mit', () {
      const gebucht = HeroReisebericht(
        checkedIds: {'rb_k2'},
        appliedRewardIds: {'rb_k2', 'rb_meta'},
      );

      final buchung = abgleich(gebucht, const HeroReisebericht());

      expect(buchung.zurueck.newAppliedIds, {'rb_k2', 'rb_meta'});
      expect(buchung.zurueck.ap, 80);
      expect(buchung.zurueck.eigenschaftsBoni.single.eigenschaft, 'mu');
    });

    test('ein gelöschter offener Eintrag bucht die Positionen um', () {
      const gebucht = HeroReisebericht(
        openEntries: {
          'rb_open': [
            ReiseberichtOpenItem(name: 'A', ap: 10),
            ReiseberichtOpenItem(name: 'B', ap: 20),
            ReiseberichtOpenItem(name: 'C', ap: 30),
          ],
        },
        appliedRewardIds: {
          'rb_open_item_0',
          'rb_open_item_1',
          'rb_open_item_2',
        },
      );
      final entwurf = gebucht.copyWith(
        openEntries: {
          'rb_open': const [
            ReiseberichtOpenItem(name: 'B', ap: 20),
            ReiseberichtOpenItem(name: 'C', ap: 30),
          ],
        },
      );

      final buchung = abgleich(gebucht, entwurf);

      // Netto fällt genau der gelöschte Eintrag A weg.
      expect(buchung.zurueck.ap - buchung.neu.ap, 10);
      expect(
        buchung.zurueck.newAppliedIds.difference(buchung.neu.newAppliedIds),
        {'rb_open_item_2'},
      );
    });

    test('früher nicht Zurückgenommenes bleibt unangetastet', () {
      // Gebucht, aber schon vorher nicht mehr abgehakt (ältere Version).
      const gebucht = HeroReisebericht(appliedRewardIds: {'rb_cp'});

      expect(abgleich(gebucht, gebucht).istLeer, isTrue);
    });

    test('Erneutes Abhaken im selben Entwurf hebt die Rücknahme auf', () {
      const gebucht = HeroReisebericht(
        checkedIds: {'rb_cp'},
        appliedRewardIds: {'rb_cp'},
      );

      expect(abgleich(gebucht, gebucht).istLeer, isTrue);
    });

    test('reiseberichtBuchungsaenderung zeigt nur die zusätzliche Wirkung', () {
      const gebucht = HeroReisebericht(
        checkedIds: {'rb_cp', 'f1', 'f2'},
        appliedRewardIds: {'rb_cp', 'f1', 'f2', 'rb_fix_schwelle'},
      );
      final vorher = gebucht.copyWith(checkedIds: {'f1', 'f2'});
      final nachher = gebucht.copyWith(checkedIds: {'f1'});

      final aenderung = reiseberichtBuchungsaenderung(
        catalog: katalog,
        gebucht: gebucht,
        vorher: vorher,
        nachher: nachher,
      );

      expect(aenderung.zurueck.newAppliedIds, {'f2', 'rb_fix_schwelle'});
      expect(aenderung.neu.newAppliedIds, isEmpty);
    });

    test('bucheReisebericht nimmt am Helden zurück und bucht neu', () {
      final hero = HeroSheet(
        id: 'h1',
        name: 'Testor',
        level: 1,
        apTotal: 200,
        attributes: const Attributes(
          mu: 13,
          kl: 12,
          inn: 12,
          ch: 12,
          ff: 12,
          ge: 12,
          ko: 12,
          kk: 12,
        ),
        talents: {
          'Kriegskunst': HeroTalentEntry(
            talentValue: 5,
            specialExperiences: 1,
            talentModifiers: [
              HeroTalentModifier(modifier: 1, description: 'Reisebericht: Fix'),
            ],
          ),
        },
        reisebericht: const HeroReisebericht(
          checkedIds: {'f1', 'f2'},
          appliedRewardIds: {'f1', 'f2', 'rb_fix_schwelle', 'fremd'},
        ),
      );
      final gebucht = hero.reisebericht;
      // f2 enthakt, rb_cp neu abgehakt.
      final entwurf = gebucht.copyWith(checkedIds: {'f1', 'rb_cp'});

      final ergebnis = bucheReisebericht(
        hero: hero,
        buchung: abgleich(gebucht, entwurf),
        gebucht: gebucht,
        entwurf: entwurf,
      );

      final kriegskunst = ergebnis.talents['Kriegskunst']!;
      expect(ergebnis.apTotal, 200 - 25 + 30);
      // Eine SE der Schwelle zurück, eine des Checkpoints dazu.
      expect(kriegskunst.specialExperiences, 1);
      expect(kriegskunst.talentModifiers, isEmpty);
      expect(ergebnis.reisebericht.checkedIds, {'f1', 'rb_cp'});
      expect(ergebnis.reisebericht.appliedRewardIds, {'f1', 'rb_cp', 'fremd'});
    });
  });

  group('reiseberichtKategorien', () {
    test('hat 6 Kategorien', () {
      expect(reiseberichtKategorien.length, 6);
    });

    test('enthalt alle erwarteten Schluessel', () {
      expect(reiseberichtKategorien, contains('kampferfahrungen'));
      expect(reiseberichtKategorien, contains('koerperliche_erprobungen'));
      expect(reiseberichtKategorien, contains('gesellschaftliche_erfahrungen'));
      expect(reiseberichtKategorien, contains('naturerfahrungen'));
      expect(reiseberichtKategorien, contains('spirituelle_erfahrungen'));
      expect(reiseberichtKategorien, contains('magische_erfahrungen'));
    });
  });
}
