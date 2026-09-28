import 'package:dsa_heldenverwaltung/catalog/hero_trait_def.dart';
import 'package:dsa_heldenverwaltung/catalog/hero_trait_effect.dart';
import 'package:dsa_heldenverwaltung/catalog/hero_trait_text.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_merkmal.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_wirkung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_merkmal_zuordnung_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/hero_requirement_context.dart';
import 'package:dsa_heldenverwaltung/rules/derived/modifier_parser.dart';
import 'package:dsa_heldenverwaltung/rules/derived/resource_activation_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/rest_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/wund_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../catalog/catalog_reference_names.dart';

/// Strukturierte Vor- und Nachteile (ARCH-02): Zuordnung der Alttexte,
/// Abweichungen durch aeltere App-Versionen und Wirkung ueber die Katalog-ID.
void main() {
  final vorteile = ladeKatalogDatei('vorteile.json')
      .map(HeroTraitDef.fromJson)
      .toList(growable: false);
  final nachteile = ladeKatalogDatei('nachteile.json')
      .map(HeroTraitDef.fromJson)
      .toList(growable: false);
  final catalog = RulesCatalog(
    version: 'house_rules_v1',
    source: 'test',
    talents: const [],
    spells: const [],
    weapons: const [],
    advantages: vorteile,
    disadvantages: nachteile,
  );
  final katalog = MerkmalKatalog.von(catalog);

  HeroSheet held({
    String vorteileText = '',
    String nachteileText = '',
    List<HeroMerkmal> vorteilEintraege = const <HeroMerkmal>[],
    List<HeroMerkmal> nachteilEintraege = const <HeroMerkmal>[],
  }) {
    return HeroSheet(
      id: 'h',
      name: 'Test',
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
      vorteileText: vorteileText,
      nachteileText: nachteileText,
      vorteilEintraege: vorteilEintraege,
      nachteilEintraege: nachteilEintraege,
    );
  }

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
      expect(parseModifierTextsForHero(hero).hasFlinkFromVorteile, isFalse);
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
      final hero = held(
        vorteileText: 'Hohe Lebenskraft 3',
        vorteilEintraege: const [
          HeroMerkmal(
            katalogId: 'adv_hohe_lebenskraft',
            text: 'Hohe Lebenskraft 3',
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
      expect(kontext.vorteile, contains('Hohe Lebenskraft 3'));
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
    final wirkende = <(HeroTraitDef, bool)>[
      for (final def in vorteile)
        if (def.wirkungen.isNotEmpty) (def, true),
      for (final def in nachteile)
        if (def.wirkungen.isNotEmpty) (def, false),
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

            final a = parseModifierTextsForHero(alt);
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

            final restA = collectRestAbilities(alt);
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
              computeHeroResourceActivation(alt).magic.autoEnabled,
              reason: grund,
            );
          }
        }
      });
    }
  });
}
