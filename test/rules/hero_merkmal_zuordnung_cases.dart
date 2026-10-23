part of 'hero_merkmal_rules_test.dart';

void _merkmalZuordnung() {
  group('Zuordnung von Alttexten', () {
    final faelle = <(String, bool, String, int?, String)>[
      ('Eisern', true, 'adv_eisern', null, ''),
      ('eisern', true, 'adv_eisern', null, ''),
      ('Hohe Lebenskraft 3', true, 'adv_hohe_lebenskraft', 3, ''),
      ('Hohe Lebenskraft', true, 'adv_hohe_lebenskraft', null, ''),
      ('Schnelle Heilung II', true, 'adv_schnelle_heilung', 2, ''),
      (
        'Herausragende Eigenschaft KK 2',
        true,
        'adv_herausragende_eigenschaft',
        2,
        'KK',
      ),
      (
        'Herausragende Eigenschaft KK',
        true,
        'adv_herausragende_eigenschaft',
        null,
        'KK',
      ),
      (
        'Herausragende Eigenschaft: Gewandtheit: 1',
        true,
        'adv_herausragende_eigenschaft',
        1,
        'GE',
      ),
      (
        'Herausragende Eigenschaft Gewandtheit 1',
        true,
        'adv_herausragende_eigenschaft',
        1,
        'GE',
      ),
      (
        'Herausragende Eigenschaft: GE: 1',
        true,
        'adv_herausragende_eigenschaft',
        1,
        'GE',
      ),
      ('Geweiht Peraine', true, 'adv_geweiht', null, 'Peraine'),
      ('Angst vor Spinnen 5', false, 'dis_angst_vor', 5, 'Spinnen'),
      ('Goldgier 6', false, 'dis_goldgier', 6, ''),
      ('Astraler Block', false, 'dis_astraler_block_zauberer', null, ''),
      (
        'Astraler Block, Viertelzauberer',
        false,
        'dis_astraler_block_viertelzauberer',
        null,
        '',
      ),
    ];
    for (final (text, istVorteil, id, wert, auswahl) in faelle) {
      test('„$text“ → $id', () {
        final eintrag = ordneMerkmalZu(
          text,
          katalog.liste(vorteil: istVorteil),
        );
        expect(eintrag.katalogId, id);
        expect(eintrag.wert, wert);
        expect(eintrag.auswahl, auswahl);
        expect(eintrag.text, text);
        expect(eintrag.zuordnung, HeroMerkmalZuordnung.migration);
      });
    }

    test('Mehrdeutiges bleibt frei und nennt die Kandidaten', () {
      final eintrag = ordneMerkmalZu('Begabung für Schwerter', vorteile);

      expect(eintrag.istKatalogisiert, isFalse);
      expect(eintrag.kandidatenIds.length, greaterThan(1));
      expect(eintrag.brauchtPruefung, isTrue);
    });

    test('eine unbekannte Eigenschaft wird nicht zugeordnet', () {
      final eintrag = ordneMerkmalZu(
        'Herausragende Eigenschaft Schönheit 2',
        vorteile,
      );

      expect(eintrag.istKatalogisiert, isFalse);
      expect(eintrag.kandidatenIds, isEmpty);
    });

    test('Freie Texte und Codes bleiben frei', () {
      for (final text in [
        'LEP+2',
        'Glückspilz der Gilde',
        'Nachtsicht nach Absprache',
      ]) {
        final eintrag = ordneMerkmalZu(text, vorteile);
        expect(eintrag.istKatalogisiert, isFalse, reason: text);
        expect(eintrag.kandidatenIds, isEmpty, reason: text);
        expect(eintrag.zuordnung, HeroMerkmalZuordnung.frei, reason: text);
      }
    });

    test('Komma-Templates werden wieder zusammengefügt', () {
      final eintraege = migriereMerkmale(
        'Adlig, Adliges Erbe, Eisern; Tierempathie, allgemein',
        vorteile,
      );

      expect(eintraege.map((e) => e.katalogId), [
        'adv_adlig_erbe',
        'adv_eisern',
        'adv_tierempathie_allgemein',
      ]);
    });

    test('Migration ist deterministisch und erhält die Fragmente', () {
      const texte = <String>[
        'Zäher Hund, Richtungssinn, Glückspilz der Gilde, LEP+2, '
            'Nachtsicht nach Absprache',
        'Herausragende Eigenschaft KK 2',
        'Adlig, Adliges Erbe, Eisern',
      ];
      for (final text in texte) {
        final einmal = migriereMerkmale(text, vorteile);
        final projektion = projiziereMerkmalText(einmal);

        expect(migriereMerkmale(projektion, vorteile), einmal);
        expect(
          splitHeroTraitText(projektion).toSet(),
          splitHeroTraitText(text).toSet(),
        );
      }
    });
  });

  group('Die Liste führt, Abweichungen werden gemeldet', () {
    const liste = <HeroMerkmal>[
      HeroMerkmal(katalogId: 'adv_eisern', text: 'Eisern'),
      HeroMerkmal(katalogId: 'adv_richtungssinn', text: 'Richtungssinn'),
    ];

    test('gleicher Inhalt mit anderen Trennzeichen ist keine Abweichung', () {
      final abgleich = gleicheMerkmaleAb(
        held(vorteileText: 'Eisern, Richtungssinn', vorteilEintraege: liste),
        katalog: katalog,
      );

      expect(abgleich.hatAbweichung, isFalse);
      expect(abgleich.vorteile, liste);
    });

    test('ein von einer älteren App ergänzter Text wird gemeldet, '
        'aber nicht wirksam', () {
      final hero = held(
        vorteileText: 'Eisern, Richtungssinn, Flink',
        vorteilEintraege: liste,
      );
      final abgleich = gleicheMerkmaleAb(hero, katalog: katalog);

      expect(abgleich.vorteilAbweichung!.hinzugefuegt, ['Flink']);
      expect(abgleich.vorteilAbweichung!.entfernt, isEmpty);
      expect(abgleich.vorteile, liste);
      expect(
        parseModifierTextsForHero(hero, catalog: catalog).hasFlinkFromVorteile,
        isFalse,
      );
      // Auch ohne Katalog rechnet der Parser mit der Liste.
      expect(
        parseModifierTextsForHero(hero, catalog: null).hasFlinkFromVorteile,
        isFalse,
      );
    });

    test('ein entfernter Eintrag wird gemeldet', () {
      final abgleich = gleicheMerkmaleAb(
        held(vorteileText: 'Eisern', vorteilEintraege: liste),
        katalog: katalog,
      );

      expect(abgleich.vorteilAbweichung!.entfernt, ['Richtungssinn']);
    });

    test('Speichern löst eine Abweichung nicht still auf', () {
      final hero = held(vorteileText: 'Eisern, Flink', vorteilEintraege: liste);
      final gespeichert = merkmaleZumSpeichern(hero, katalog: katalog);

      expect(gespeichert.vorteileText, 'Eisern, Flink');
      expect(gespeichert.vorteilEintraege, liste);
    });

    test('Speichern migriert einen Alttext einmalig und ist ein Fixpunkt', () {
      final hero = held(
        vorteileText: 'Eisern, Hohe Lebenskraft 2, LEP+2',
        nachteileText: 'Goldgier 6',
      );
      final einmal = merkmaleZumSpeichern(hero, katalog: katalog);
      final zweimal = merkmaleZumSpeichern(einmal, katalog: katalog);

      expect(einmal.vorteilEintraege.map((e) => e.katalogId), [
        'adv_eisern',
        'adv_hohe_lebenskraft',
        '',
      ]);
      expect(einmal.vorteileText, 'Eisern; Hohe Lebenskraft 2; LEP+2');
      expect(zweimal.vorteilEintraege, einmal.vorteilEintraege);
      expect(zweimal.vorteileText, einmal.vorteileText);
      expect(
        merkmaleZumSpeichern(hero).vorteilEintraege,
        isEmpty,
        reason: 'ohne Katalog wird nicht migriert',
      );
    });

    test('Text übernehmen behält bestehende Zuordnungen', () {
      final ergebnis = uebernimmMerkmalText('Eisern, Flink', const [
        HeroMerkmal(
          katalogId: 'adv_eisern',
          text: 'Eisern',
          zuordnung: HeroMerkmalZuordnung.katalog,
        ),
      ], vorteile);

      expect(ergebnis.first.zuordnung, HeroMerkmalZuordnung.katalog);
      expect(ergebnis.last.katalogId, 'adv_flink');
    });
  });

  group('Hinzufügen im Dialog', () {
    HeroTraitDef def(String id) => katalog.eintrag(id, vorteil: false)!;

    test('gleiche Auswahl desselben Eintrags summiert den Wert', () {
      final angst = def('dis_angst_vor');
      final liste = fuegeMerkmalHinzu(
        const [
          HeroMerkmal(
            katalogId: 'dis_angst_vor',
            text: 'Angst vor Spinnen 2',
            wert: 2,
            auswahl: 'Spinnen',
          ),
        ],
        const HeroMerkmal(
          katalogId: 'dis_angst_vor',
          text: 'Angst vor Spinnen 3',
          wert: 3,
          auswahl: 'Spinnen',
        ),
        def: angst,
      );

      expect(liste.single.wert, 5);
      expect(liste.single.text, 'Angst vor Spinnen 5');
    });

    test('andere Auswahl und freie Einträge werden angehängt, '
        'identische Texte nicht verdoppelt', () {
      final angst = def('dis_angst_vor');
      var liste = fuegeMerkmalHinzu(
        const [],
        const HeroMerkmal(
          katalogId: 'dis_angst_vor',
          text: 'Angst vor Ratten 1',
          wert: 1,
          auswahl: 'Ratten',
        ),
        def: angst,
      );
      liste = fuegeMerkmalHinzu(
        liste,
        const HeroMerkmal(
          katalogId: 'dis_angst_vor',
          text: 'Angst vor Feuer 2',
          wert: 2,
          auswahl: 'Feuer',
        ),
        def: angst,
      );
      liste = fuegeMerkmalHinzu(liste, const HeroMerkmal(text: 'Tick'));
      liste = fuegeMerkmalHinzu(liste, const HeroMerkmal(text: 'Tick'));

      expect(liste.map((e) => e.text), [
        'Angst vor Ratten 1',
        'Angst vor Feuer 2',
        'Tick',
      ]);
    });
  });
}
