part of 'hero_merkmal_rules_test.dart';

void _merkmalBearbeitung() {
  group('Gezielt ändern und Abweichung lösen (Merkmalsblatt)', () {
    test('die erste Änderung eines Bestandshelden speichert alles '
        'strukturiert', () {
      final hero = held(vorteileText: 'Eisern, LEP+2');

      final geaendert = aendereMerkmale(
        hero,
        vorteil: true,
        katalog: katalog,
        aenderung: (liste) => fuegeMerkmalHinzu(
          liste,
          const HeroMerkmal(katalogId: 'adv_flink', text: 'Flink'),
        ),
      );

      expect(geaendert.vorteilEintraege.map((e) => e.katalogId), [
        'adv_eisern',
        '',
        'adv_flink',
      ]);
      expect(geaendert.vorteileText, 'Eisern; LEP+2; Flink');
      expect(geaendert.nachteilEintraege, isEmpty);
    });

    test('unbekannte Felder der Einträge bleiben erhalten', () {
      final hero = held(
        vorteileText: 'Eisern',
        vorteilEintraege: const [
          HeroMerkmal(
            katalogId: 'adv_eisern',
            text: 'Eisern',
            unbekannteFelder: <String, Object?>{'zukunft': 1},
          ),
        ],
      );

      final geaendert = aendereMerkmale(
        hero,
        vorteil: true,
        katalog: katalog,
        aenderung: (liste) => [
          ...liste,
          const HeroMerkmal(text: 'Tick', zuordnung: HeroMerkmalZuordnung.frei),
        ],
      );

      expect(geaendert.vorteilEintraege.first.unbekannteFelder, {'zukunft': 1});
    });

    test('eine offene Abweichung wird nicht nebenbei aufgelöst', () {
      final hero = held(
        vorteileText: 'Eisern, Flink',
        vorteilEintraege: const [
          HeroMerkmal(katalogId: 'adv_eisern', text: 'Eisern'),
        ],
      );

      expect(
        () => aendereMerkmale(
          hero,
          vorteil: true,
          katalog: katalog,
          aenderung: (liste) => liste,
        ),
        throwsStateError,
      );
      // Die andere Art ist davon nicht betroffen.
      expect(
        aendereMerkmale(
          hero,
          vorteil: false,
          katalog: katalog,
          aenderung: (liste) => [
            ...liste,
            const HeroMerkmal(
              katalogId: 'dis_goldgier',
              text: 'Goldgier 3',
              wert: 3,
            ),
          ],
        ).nachteileText,
        'Goldgier 3',
      );
    });

    test('Abweichung: Text übernehmen oder Liste behalten', () {
      final hero = held(
        vorteileText: 'Eisern, Flink',
        vorteilEintraege: const [
          HeroMerkmal(
            katalogId: 'adv_eisern',
            text: 'Eisern',
            zuordnung: HeroMerkmalZuordnung.katalog,
          ),
        ],
      );

      final text = loeseMerkmalAbweichung(
        hero,
        vorteil: true,
        katalog: katalog,
        textUebernehmen: true,
      );
      expect(text.vorteilEintraege.map((e) => e.katalogId), [
        'adv_eisern',
        'adv_flink',
      ]);
      expect(text.vorteileText, 'Eisern; Flink');

      final liste = loeseMerkmalAbweichung(
        hero,
        vorteil: true,
        katalog: katalog,
        textUebernehmen: false,
      );
      expect(liste.vorteilEintraege, hero.vorteilEintraege);
      expect(liste.vorteileText, 'Eisern');
      expect(gleicheMerkmaleAb(liste).hatAbweichung, isFalse);
    });
  });

  group('Anzeige der Merkmalskarten', () {
    MerkmalAnzeige zeige(HeroMerkmal eintrag, {bool vorteil = true}) =>
        beschreibeMerkmal(eintrag, katalog, vorteil: vorteil);

    test('Katalogname, Detail und Wirkung', () {
      final lk = zeige(
        const HeroMerkmal(
          katalogId: 'adv_hohe_lebenskraft',
          text: 'Hohe Lebenskraft 8',
          wert: 8,
        ),
      );
      expect(lk.art, 'Vorteil');
      expect(lk.name, 'Hohe Lebenskraft');
      expect(lk.detail, 'Stufe 8');
      expect(lk.wirkungen, ['LeP +6'], reason: 'wie die Rechnung gekappt');
      expect(lk.herkunft, MerkmalHerkunft.katalog);

      final he = zeige(
        const HeroMerkmal(
          katalogId: 'adv_herausragende_eigenschaft',
          text: 'Herausragende Eigenschaft KK 2',
          wert: 2,
          auswahl: 'KK',
        ),
      );
      expect(he.detail, 'Stufe 2 · Auswahl: KK');
      expect(he.wirkungen, ['KK +2 (auch Startwert)']);

      expect(
        zeige(
          const HeroMerkmal(
            katalogId: 'dis_kurzatmig',
            text: 'Kurzatmig 2',
            wert: 2,
          ),
          vorteil: false,
        ).wirkungen,
        ['AuP −2'],
      );
      expect(
        zeige(const HeroMerkmal(katalogId: 'adv_eisern', text: 'Eisern'))
            .wirkungen,
        ['Wundschwellen +2'],
      );
      expect(
        zeige(const HeroMerkmal(katalogId: 'adv_richtungssinn', text: 'R'))
            .wirkungen,
        isEmpty,
      );
      expect(
        zeige(
          const HeroMerkmal(katalogId: 'adv_linkshaender', text: 'Linkshänder'),
        ).wirkungen,
        ['Schwertarm links (Wunden)'],
      );
    });

    test('Wirkungstext und Rechnung stimmen für jeden Basiswert überein', () {
      for (final def in [...vorteile, ...nachteile]) {
        final istVorteil = def.traitType == 'advantage';
        for (final wirkung in def.wirkungen) {
          if (wirkung.art != HeroTraitEffectArt.basiswert) continue;
          for (var wert = 1; wert <= (wirkung.max ?? 6) + 1; wert++) {
            final eintrag = HeroMerkmal(
              katalogId: def.id,
              text: merkmalTextFuer(def, wert: wert),
              wert: wert,
            );
            final hero = istVorteil
                ? held(vorteileText: eintrag.text, vorteilEintraege: [eintrag])
                : held(
                    nachteileText: eintrag.text,
                    nachteilEintraege: [eintrag],
                  );
            final stats = parseModifierTextsForHero(
              hero,
              catalog: catalog,
            ).statMods.toJson();
            final betrag = stats.values.whereType<int>().firstWhere(
              (v) => v != 0,
            );
            final text = zeige(eintrag, vorteil: istVorteil).wirkungen.single;
            final zahl = betrag < 0 ? '−${-betrag}' : '+$betrag';
            expect(text, endsWith(zahl), reason: '${def.id} $wert');
          }
        }
      }
    });

    test('frei, mehrdeutig und unbekannt', () {
      expect(
        zeige(const HeroMerkmal(text: 'LEP+2')).herkunft,
        MerkmalHerkunft.frei,
      );
      expect(
        zeige(
          const HeroMerkmal(
            text: 'Begabung für Schwerter',
            kandidatenIds: ['a', 'b'],
          ),
        ).herkunft,
        MerkmalHerkunft.pruefen,
      );
      final weg = zeige(
        const HeroMerkmal(katalogId: 'adv_entfernt', text: 'Altlast'),
      );
      expect(weg.herkunft, MerkmalHerkunft.unbekannt);
      expect(weg.name, 'Altlast');
      expect(weg.herkunftText, 'Nicht im Katalog');
    });
  });
}
