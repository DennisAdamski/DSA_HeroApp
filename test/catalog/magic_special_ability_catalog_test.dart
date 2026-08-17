import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/special_ability_def.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';
import 'package:dsa_heldenverwaltung/rules/derived/requirement_evaluation_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/special_ability_chain_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/special_ability_variant_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/tradition_rules.dart';

/// Prueft die gepflegten Strukturdaten im Katalog der magischen
/// Sonderfertigkeiten: Jede Bedingung muss einer bekannten Art entsprechen und
/// auf etwas verweisen, das es tatsaechlich gibt. Ohne diesen Test faellt ein
/// Tippfehler in der JSON-Datei erst im laufenden Betrieb auf — und dort nur
/// als stillschweigend nicht erfuellte Voraussetzung.
void main() {
  final datei = File(
    'assets/catalogs/house_rules_v1/magische_sonderfertigkeiten.json',
  );
  final eintraege = (jsonDecode(datei.readAsStringSync()) as List)
      .cast<Map<String, dynamic>>()
      .map(SpecialAbilityDef.fromJson)
      .toList(growable: false);

  Iterable<SpecialAbilityRequirement> alleBedingungen() sync* {
    for (final def in eintraege) {
      yield* _flach(def.voraussetzungenStruktur);
    }
  }

  test('der Katalog laesst sich vollstaendig lesen', () {
    expect(eintraege, isNotEmpty);
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

  test('jede Sonderfertigkeits-Referenz zeigt auf einen echten Eintrag', () {
    final bekannt = <String>{
      for (final def in eintraege)
        for (final name in def.alleNamen) normalizeSpecialAbilityName(name),
    };

    for (final bedingung in alleBedingungen()) {
      if (bedingung.art != RequirementArt.sonderfertigkeit) {
        continue;
      }
      final trifft = bekannt.any(
        (name) => besessenStufeFuer(name, bedingung.name) != null,
      );
      expect(
        trifft,
        isTrue,
        reason:
            'Voraussetzung "SF ${bedingung.name}" hat keinen Katalogeintrag',
      );
    }
  });

  test('jede Traditions-Referenz ist eine bekannte Tradition', () {
    for (final bedingung in alleBedingungen()) {
      if (bedingung.art != RequirementArt.tradition) {
        continue;
      }
      for (final name in bedingung.alleNamen) {
        expect(
          traditionByName(name),
          isNotNull,
          reason: 'Unbekannte Tradition "$name"',
        );
      }
    }
  });

  test('Eigenschaftsbedingungen nennen ein gueltiges Kuerzel', () {
    const gueltig = <String>{'MU', 'KL', 'IN', 'CH', 'FF', 'GE', 'KO', 'KK'};

    for (final bedingung in alleBedingungen()) {
      if (bedingung.art != RequirementArt.eigenschaft) {
        continue;
      }
      expect(gueltig, contains(bedingung.code));
      expect(bedingung.min, isNotNull);
    }
  });

  group('Stufenketten', () {
    final ketten = buildSpecialAbilityChains(eintraege);

    test('der Katalog enthaelt die erwarteten Ketten', () {
      expect(
        ketten.map((kette) => kette.id).toSet(),
        containsAll(<String>[
          'eiserner_wille',
          'daemonenbindung',
          'spontane_regeneration',
          'regeneration',
          'aurapanzer',
        ]),
      );
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

    test('Eiserner Wille ist in zwei Stufen aufgeteilt', () {
      final kette = ketten.firstWhere((k) => k.id == 'eiserner_wille');

      expect(kette.stufen.map((def) => def.name), <String>[
        'Eiserner Wille I',
        'Eiserner Wille II',
      ]);
      expect(kette.stufen.first.kosten, '200 AP');
      expect(kette.stufen.last.kosten, '300 AP');
    });

    test('der alte Sammelname bleibt als Alias erhalten', () {
      final stufeEins = eintraege.firstWhere(
        (def) => def.id == 'magsf_eiserner_wille_i',
      );

      expect(
        istEintragErworben(stufeEins, const <String>['Eiserner Wille I / II']),
        isTrue,
      );
    });

    test('Spontane Regeneration steigert die KO-Schwelle je Stufe', () {
      final kette = ketten.firstWhere((k) => k.id == 'spontane_regeneration');
      final schwellen = kette.stufen.map((def) {
        return def.voraussetzungenStruktur
            .firstWhere(
              (bedingung) =>
                  bedingung.art == RequirementArt.eigenschaft &&
                  bedingung.code == 'KO',
            )
            .min;
      });

      expect(schwellen, <int>[16, 17, 18, 19, 20]);
    });
  });

  group('Kenntnisse mit eigenem Heldenfeld', () {
    test('sind als reine Information markiert', () {
      final markiert = eintraege
          .where((def) => def.nurInformation)
          .map((def) => def.id)
          .toSet();

      expect(markiert, <String>{
        'magsf_repraesentation',
        'magsf_ritualkenntnis_tradition',
        'magsf_merkmalskenntnis_einzelnes_merkmal',
        'magsf_zauberspezialisierung',
      });
    });
  });

  group('Traditionsrituale', () {
    test('sind alle an eine Tradition gebunden', () {
      final rituale = eintraege.where(
        (def) => def.kategorie == 'Traditionsrituale',
      );
      expect(rituale, isNotEmpty);

      // Elfenlieder haengen laut Regelwerk am Vorteil Zweistimmiger Gesang,
      // nicht an einer Ritualkenntnis; Kugelzauber, Odûn-Gaben und Ottagaldr
      // nennen ausschliesslich Einzelfallregeln.
      const ohneTradition = <String>{
        'magsf_elfenlieder',
        'magsf_kugelzauber',
        'magsf_oduen_gaben',
        'magsf_ottagaldr',
      };

      for (final def in rituale) {
        if (ohneTradition.contains(def.id)) {
          continue;
        }
        expect(
          def.voraussetzungenStruktur.any(
            (bedingung) => bedingung.art == RequirementArt.tradition,
          ),
          isTrue,
          reason: '${def.id} nennt keine Tradition',
        );
      }
    });
  });
}

Iterable<SpecialAbilityRequirement> _flach(
  Iterable<SpecialAbilityRequirement> bedingungen,
) sync* {
  for (final bedingung in bedingungen) {
    yield bedingung;
    yield* _flach(bedingung.bedingungen);
  }
}
