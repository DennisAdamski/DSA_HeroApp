part of 'reisebericht_rules_test.dart';

void _reiseberichtVollstaendigkeit() {
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
}
