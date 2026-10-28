part of 'hero_merkmal_rules_test.dart';

void _merkmalWirkung() {
  group('Wirkung über die Katalog-ID', () {
    test('keine Doppelanwendung von Katalog- und Textweg', () {
      final hero = merkmaleZumSpeichern(
        held(vorteileText: 'Hohe Lebenskraft 3, LEP+2, Eisern'),
        katalog: katalog,
      );

      final parsed = parseModifierTextsForHero(hero, catalog: catalog);
      expect(parsed.statMods.lep, 5);
      expect(werteMerkmaleAus(hero, catalog: catalog).freieVorteile, 'LEP+2');
    });

    test('„Gewandtheit“ mit Doppelpunkten wirkt auf beiden Wegen', () {
      const text = 'Herausragende Eigenschaft: Gewandtheit: 1';
      final textweg = parseModifierTextsForHero(
        held(vorteileText: text),
        catalog: null,
      );
      final gespeichert = merkmaleZumSpeichern(
        held(vorteileText: text),
        katalog: katalog,
      );
      final katalogweg = parseModifierTextsForHero(
        gespeichert,
        catalog: catalog,
      );

      expect(textweg.attributeMods.ge, 1);
      expect(textweg.startAttributeMods.ge, 1);
      expect(
        gespeichert.vorteilEintraege.single.katalogId,
        'adv_herausragende_eigenschaft',
      );
      expect(katalogweg.attributeMods.ge, 1);
      expect(katalogweg.startAttributeMods.ge, 1);
      expect(
        merkmaleZumSpeichern(gespeichert, katalog: katalog).toJson(),
        gespeichert.toJson(),
      );
    });

    test('ein umbenannter Katalogeintrag wirkt unverändert', () {
      HeroTraitDef umbenannt(HeroTraitDef def) {
        if (def.id != 'adv_hohe_lebenskraft') {
          return def;
        }
        return HeroTraitDef.fromJson(<String, dynamic>{
          ...def.toJson(),
          'name': 'Robuste Konstitution',
          'selectionTemplate': 'Robuste Konstitution {value}',
        });
      }

      final neuerKatalog = RulesCatalog(
        version: 'house_rules_v1',
        source: 'test',
        talents: const [],
        spells: const [],
        weapons: const [],
        advantages: vorteile.map(umbenannt).toList(),
        disadvantages: nachteile,
      );
      // Nach dem Umbenennen neu bearbeitet: Der Text trägt den neuen Namen,
      // den der alte Namensparser nicht kennt.
      final hero = held(
        vorteileText: 'Robuste Konstitution 3',
        vorteilEintraege: const [
          HeroMerkmal(
            katalogId: 'adv_hohe_lebenskraft',
            text: 'Robuste Konstitution 3',
            wert: 3,
          ),
        ],
      );

      expect(
        parseModifierTextsForHero(hero, catalog: neuerKatalog).statMods.lep,
        3,
      );
      // Die Voraussetzungsprüfung kennt den neuen und den alten Namen.
      final kontext = buildHeroRequirementContext(hero, catalog: neuerKatalog);
      expect(kontext.vorteile, contains('Robuste Konstitution 3'));
      expect(
        parseModifierTextsForHero(hero, catalog: null).statMods.lep,
        0,
        reason: 'ohne Katalog kennt der Namensparser den Eintrag nicht',
      );
    });

    test('Steigerungs-Replay und Option rechnen nach einer Umbenennung '
        'gleich', () {
      HeroTraitDef umbenannt(HeroTraitDef def) {
        if (def.id != 'adv_herausragende_eigenschaft') {
          return def;
        }
        return HeroTraitDef.fromJson(<String, dynamic>{
          ...def.toJson(),
          'name': 'Überragende Eigenschaft',
          'selectionTemplate': 'Überragende Eigenschaft {choice} {value}',
        });
      }

      final neuerKatalog = RulesCatalog(
        version: 'house_rules_v1',
        source: 'test',
        talents: const [],
        spells: const [],
        weapons: const [],
        advantages: vorteile.map(umbenannt).toList(),
        disadvantages: nachteile,
      );
      final hero = held(
        vorteileText: 'Überragende Eigenschaft KK 2',
        vorteilEintraege: const [
          HeroMerkmal(
            katalogId: 'adv_herausragende_eigenschaft',
            text: 'Überragende Eigenschaft KK 2',
            wert: 2,
            auswahl: 'KK',
          ),
        ],
      );
      // Die Option plant auf Effektivebene: Rohwert 12 plus Vorteil 2.
      final start = parseStartAttributeModifiers(hero, catalog: neuerKatalog);
      expect(start.kk, 2);

      final gesteigert = applyAdvancementAttributeValue(
        hero,
        AttributeCode.kk,
        15,
        catalog: neuerKatalog,
      );
      expect(gesteigert.attributes.kk, 13);
      expect(
        computeEffectiveAttributes(gesteigert, catalog: neuerKatalog).kk,
        15,
      );
      // Gegenprobe: Der Namensweg kennt den neuen Namen nicht und schriebe
      // den Vorteil in den Rohwert.
      expect(
        applyAdvancementAttributeValue(
          hero,
          AttributeCode.kk,
          15,
          catalog: null,
        ).attributes.kk,
        15,
      );
    });

    test('eine unbekannte Katalog-ID wirkt über ihren Text', () {
      final hero = held(
        vorteileText: 'Hohe Lebenskraft 2',
        vorteilEintraege: const [
          HeroMerkmal(katalogId: 'adv_entfernt', text: 'Hohe Lebenskraft 2'),
        ],
      );

      expect(parseModifierTextsForHero(hero, catalog: catalog).statMods.lep, 2);
    });
  });

  group('Äquivalenz: Katalog-ID und Textweg rechnen gleich', () {
    // Bewusste Ausnahme: `lernspalte` (Begabung/Unfähigkeit) wirkt nur über
    // die Katalog-ID. Der Textweg kannte nie Lernspalten; freie oder
    // mehrdeutige Begabungstexte wirken erst nach der Zuordnung
    // (`test/rules/hero_begabung_rules_test.dart`).
    bool wirktUeberText(HeroTraitDef def) => def.wirkungen.any(
      (wirkung) => wirkung.art != HeroTraitEffectArt.lernspalte,
    );
    final wirkende = <(HeroTraitDef, bool)>[
      for (final def in vorteile)
        if (wirktUeberText(def)) (def, true),
      for (final def in nachteile)
        if (wirktUeberText(def)) (def, false),
    ];

    for (final (def, istVorteil) in wirkende) {
      test(def.id, () {
        final template = def.selectionTemplate;
        final auswahlen = template.contains('{choice}')
            ? <String>[for (final code in AttributeCode.values) code.name]
            : <String>[''];
        final hatWert = template.contains('{value}');
        final grenze = def.maxValue ?? 6;
        final werte = hatWert
            ? <int?>[for (var w = 1; w <= grenze + 1; w++) w]
            : <int?>[null];
        final rast = def.wirkungen.any((w) => w.art == HeroTraitEffectArt.rast);

        for (final auswahl in auswahlen) {
          for (final wert in werte) {
            if (rast && wert != null && wert > 3) {
              continue; // Der Namensweg kennt nur I–III bzw. 1–3.
            }
            final text = merkmalTextFuer(def, auswahl: auswahl, wert: wert);
            final eintrag = HeroMerkmal(
              katalogId: def.id,
              text: text,
              wert: wert,
              auswahl: auswahl,
            );
            final alt = istVorteil
                ? held(vorteileText: text)
                : held(nachteileText: text);
            final neu = istVorteil
                ? held(vorteileText: text, vorteilEintraege: [eintrag])
                : held(nachteileText: text, nachteilEintraege: [eintrag]);
            final grund = '$text (${def.id})';

            final a = parseModifierTextsForHero(alt, catalog: null);
            final b = parseModifierTextsForHero(neu, catalog: catalog);
            expect(
              b.attributeMods.toJson(),
              a.attributeMods.toJson(),
              reason: grund,
            );
            expect(
              b.startAttributeMods.toJson(),
              a.startAttributeMods.toJson(),
              reason: grund,
            );
            expect(b.statMods.toJson(), a.statMods.toJson(), reason: grund);
            expect(b.hasFlinkFromVorteile, a.hasFlinkFromVorteile);
            expect(b.hasBehaebigFromNachteile, a.hasBehaebigFromNachteile);
            expect(
              b.hasLinkshaenderFromVorteile,
              a.hasLinkshaenderFromVorteile,
              reason: grund,
            );

            final restA = collectRestAbilities(alt, catalog: null);
            final restB = collectRestAbilities(neu, catalog: catalog);
            expect(
              restB.fastHealingLevel,
              restA.fastHealingLevel,
              reason: grund,
            );
            expect(
              restB.astralRegenerationLevel,
              restA.astralRegenerationLevel,
              reason: grund,
            );
            expect(restB.hasPoorRegeneration, restA.hasPoorRegeneration);
            expect(restB.hasAstralBlock, restA.hasAstralBlock, reason: grund);

            final merkmale = werteMerkmaleAus(neu, catalog: catalog);
            final wundA = computeWundschwellenStufen(
              ko: 12,
              vorteileText: alt.vorteileText,
              nachteileText: alt.nachteileText,
            );
            final wundB = computeWundschwellenStufen(
              ko: 12,
              vorteileText: merkmale.freieVorteile,
              nachteileText: merkmale.freieNachteile,
              merkmalBonus: merkmale.wirkungen.wundschwelleBonus,
            );
            expect(wundB.ko, wundA.ko, reason: grund);

            expect(
              computeHeroResourceActivation(
                neu,
                catalog: catalog,
              ).magic.autoEnabled,
              computeHeroResourceActivation(
                alt,
                catalog: null,
              ).magic.autoEnabled,
              reason: grund,
            );
          }
        }
      });
    }
  });
}
