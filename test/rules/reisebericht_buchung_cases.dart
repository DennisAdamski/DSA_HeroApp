part of 'reisebericht_rules_test.dart';

void _reiseberichtBuchung() {
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
}
