import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/combat_special_ability_def.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';
import 'package:dsa_heldenverwaltung/rules/derived/requirement_evaluation_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/special_ability_chain_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/special_ability_variant_rules.dart';

import 'catalog_reference_names.dart';

/// Prueft die strukturierten Voraussetzungen der Kampf-Sonderfertigkeiten.
///
/// Der Kampfkatalog verweist als einziger auf Manoever, Waffenmeisterschaften
/// und abgeleitete Basiswerte. Genau diese Querverweise sind die fehleranfaellige
/// Stelle, weil die betroffenen Namen in vier verschiedenen Dateien stehen.
void main() {
  final eintraege = ladeKatalogDatei('kampf_sonderfertigkeiten.json')
      .map(CombatSpecialAbilityDef.fromJson)
      .toList(growable: false);

  Iterable<SpecialAbilityRequirement> alleBedingungen() sync* {
    for (final def in eintraege) {
      yield* alleBedingungenFlach(def.voraussetzungenStruktur);
    }
  }

  test('der Katalog laesst sich vollstaendig lesen', () {
    expect(eintraege, hasLength(87));
    expect(eintraege.every((def) => def.id.isNotEmpty), isTrue);
    expect(eintraege.every((def) => def.name.isNotEmpty), isTrue);
  });

  test('jeder Eintrag hat strukturierte Voraussetzungen', () {
    final ohne = eintraege
        .where((def) => def.voraussetzungenStruktur.isEmpty)
        .map((def) => def.id);

    expect(ohne, isEmpty);
  });

  test('es gibt keine unbekannte Bedingungsart', () {
    final unbekannt = alleBedingungen()
        .where((bedingung) => bedingung.art == RequirementArt.unbekannt)
        .map((bedingung) => bedingung.text);

    expect(unbekannt, isEmpty);
  });

  test('IDs und Namen sind eindeutig', () {
    final ids = eintraege.map((def) => def.id).toList();
    final namen = eintraege.map((def) => def.name).toList();

    expect(ids.toSet(), hasLength(ids.length));
    expect(namen.toSet(), hasLength(namen.length));
  });

  test('Eigenschaftsbedingungen nennen ein gueltiges Kuerzel', () {
    for (final bedingung in alleBedingungen()) {
      if (bedingung.art != RequirementArt.eigenschaft) {
        continue;
      }
      expect(gueltigeEigenschaften, contains(bedingung.code));
      expect(bedingung.min, isNotNull);
    }
  });

  test('Basiswert-Bedingungen nennen ein gueltiges Kuerzel', () {
    final verwendet = <String>{};
    for (final bedingung in alleBedingungen()) {
      if (bedingung.art != RequirementArt.basiswert) {
        continue;
      }
      expect(gueltigeBasiswerte, contains(bedingung.code));
      expect(bedingung.min, isNotNull);
      verwendet.add(bedingung.code);
    }

    expect(verwendet, gueltigeBasiswerte);
  });

  test('jede Sonderfertigkeits-Referenz zeigt auf einen echten Eintrag', () {
    final bekannt = <String>{
      for (final def in eintraege)
        for (final name in def.alleNamen) normalizeSpecialAbilityName(name),
    };

    for (final bedingung in alleBedingungen()) {
      if (bedingung.art != RequirementArt.sonderfertigkeit) {
        continue;
      }
      expect(
        bekannt.any((name) => besessenStufeFuer(name, bedingung.name) != null),
        isTrue,
        reason: 'Voraussetzung "SF ${bedingung.name}" hat keinen Katalogeintrag',
      );
    }
  });

  test('jede Talent-Referenz zeigt auf ein echtes Talent', () {
    final talente = ladeTalentNamen();

    for (final bedingung in alleBedingungen()) {
      if (bedingung.art != RequirementArt.talent) {
        continue;
      }
      expect(
        talente,
        contains(normalizeSpecialAbilityName(bedingung.name)),
        reason: 'Unbekanntes Talent "${bedingung.name}"',
      );
      expect(bedingung.min, isNotNull);
    }
  });

  test('jede Manoever-Referenz zeigt auf ein echtes Manoever', () {
    final manoever = normalisierteNamen('manoever.json');

    for (final bedingung in alleBedingungen()) {
      if (bedingung.art != RequirementArt.manoever) {
        continue;
      }
      expect(
        manoever,
        contains(normalizeSpecialAbilityName(bedingung.name)),
        reason: 'Unbekanntes Manöver "${bedingung.name}"',
      );
    }
  });

  test('jede Waffenmeister-Referenz nennt eine erreichbare Gattung', () {
    // Waffenmeisterschaften laufen ueber ein Kampftalent. Schilde haben keins
    // — sie werden mit dem Talent der gefuehrten Waffe pariert. Die beiden
    // Regelwerks-Voraussetzungen „Waffenmeister (Schild)“ bleiben trotzdem
    // pruefbar, weil `WaffenmeisterConfig.weaponType` eine freie
    // Gattungsangabe erlaubt.
    const gattungenOhneKampftalent = <String>{'schild'};
    final kampftalente = ladeKampftalentNamen();

    for (final bedingung in alleBedingungen()) {
      if (bedingung.art != RequirementArt.waffenmeister) {
        continue;
      }
      if (bedingung.name.isEmpty) {
        continue; // beliebige Waffenmeisterschaft
      }
      final name = normalizeSpecialAbilityName(bedingung.name);
      expect(
        kampftalente.contains(name) || gattungenOhneKampftalent.contains(name),
        isTrue,
        reason: 'Waffenmeister "${bedingung.name}" hat kein Kampftalent',
      );
    }
  });

  test('jede Vorteils- und Nachteils-Referenz existiert', () {
    final vorteile = normalisierteNamen('vorteile.json');
    final nachteile = normalisierteNamen('nachteile.json');

    for (final bedingung in alleBedingungen()) {
      final name = normalizeSpecialAbilityName(bedingung.name);
      switch (bedingung.art) {
        case RequirementArt.vorteil:
          expect(
            vorteile,
            contains(name),
            reason: 'Unbekannter Vorteil "${bedingung.name}"',
          );
        case RequirementArt.nachteil:
        case RequirementArt.nachteilVerboten:
          expect(
            nachteile,
            contains(name),
            reason: 'Unbekannter Nachteil "${bedingung.name}"',
          );
        default:
          break;
      }
    }
  });

  test('jede Zauber-Referenz zeigt auf einen echten Zauber', () {
    final zauber = normalisierteNamen('magie.json');

    for (final bedingung in alleBedingungen()) {
      if (bedingung.art != RequirementArt.zauber) {
        continue;
      }
      expect(
        zauber,
        contains(normalizeSpecialAbilityName(bedingung.name)),
        reason: 'Unbekannter Zauber "${bedingung.name}"',
      );
    }
  });

  group('Stufenketten', () {
    final ketten = buildSpecialAbilityChains(eintraege);

    test('der Katalog enthaelt die erwarteten Ketten', () {
      expect(ketten.map((kette) => kette.id).toSet(), <String>{
        'ausweichen',
        'beidhaendiger_kampf',
        'parierwaffen',
        'ruestungsgewoehnung',
        'schildkampf',
      });
    });

    test('jede Kette ist lueckenlos ab Stufe 1 durchnummeriert', () {
      for (final kette in ketten) {
        final stufen = kette.stufen
            .map((def) => def.kette!.stufe)
            .toList(growable: false);
        expect(
          stufen,
          List<int>.generate(stufen.length, (index) => index + 1),
          reason: 'Kette ${kette.id} hat eine Luecke oder Dublette',
        );
      }
    });

    test('jede Kette traegt ein Label', () {
      for (final kette in ketten) {
        expect(kette.label, isNotEmpty);
      }
    });

    test('Ruestungsgewoehnung reicht bis zur epischen Stufe IV', () {
      final kette = ketten.firstWhere((k) => k.id == 'ruestungsgewoehnung');

      expect(kette.stufen.map((def) => def.name), <String>[
        'Rüstungsgewöhnung I',
        'Rüstungsgewöhnung II',
        'Rüstungsgewöhnung III',
        'Rüstungsgewöhnung IV',
      ]);
      expect(kette.stufen.last.nurEpisch, isTrue);
    });

    test('jede Stufe verlangt die vorherige', () {
      for (final kette in ketten) {
        for (final stufe in kette.stufen.skip(1)) {
          final vorgaenger = kette.stufen.firstWhere(
            (def) => def.kette!.stufe == stufe.kette!.stufe - 1,
          );
          expect(
            stufe.voraussetzungenStruktur.any(
              (bedingung) =>
                  bedingung.art == RequirementArt.sonderfertigkeit &&
                  besessenStufeFuer(vorgaenger.name, bedingung.name) != null,
            ),
            isTrue,
            reason: '${stufe.id} verlangt ${vorgaenger.name} nicht',
          );
        }
      }
    });

    test('keine Kette verteilt sich ueber mehrere Anzeigegruppen', () {
      // Der Kampfregeln-Tab rendert die Gruppen einzeln. Eine Kette, deren
      // Stufen in verschiedenen Gruppen landen, wuerde dort zerfallen —
      // Ruestungsgewoehnung IV ist episch und darf deshalb nicht aus der
      // allgemeinen Gruppe herausfallen.
      String gruppeVon(CombatSpecialAbilityDef def) {
        if (def.isUnarmedCombatStyle) {
          return 'waffenlos';
        }
        if (def.kampfTyp == 'grossmeister') {
          return 'grossmeister';
        }
        if (!def.nurEpisch || def.kampfTyp == 'allgemein') {
          return 'allgemein';
        }
        return def.kampfTyp;
      }

      for (final kette in ketten) {
        expect(
          kette.stufen.map(gruppeVon).toSet(),
          hasLength(1),
          reason: 'Kette ${kette.id} verteilt sich über mehrere Gruppen',
        );
      }
    });
  });

  group('bewusste Regelwerks-Luecken', () {
    test('Zweihaendiger Kampf III bleibt ein Hinweis', () {
      // Zweihandmeister und die Fortgeschrittene Monsterparade verlangen die
      // SF `Zweihaendiger Kampf III`, die es weder unter den Kampf-SF noch
      // unter den Manoevern gibt. Bis der Eintrag nachgepflegt ist, bleibt die
      // Forderung sichtbarer Regeltext statt einer falschen Absage.
      for (final id in <String>[
        'esf_zweihandmeister',
        'esf_fortgeschrittene_monsterparade',
      ]) {
        final def = eintraege.firstWhere((def) => def.id == id);
        expect(
          alleBedingungenFlach(def.voraussetzungenStruktur).any(
            (bedingung) =>
                bedingung.art == RequirementArt.hinweis &&
                bedingung.text.contains('Zweihändiger Kampf III'),
          ),
          isTrue,
          reason: '$id nennt die Luecke nicht',
        );
      }
    });
  });
}
