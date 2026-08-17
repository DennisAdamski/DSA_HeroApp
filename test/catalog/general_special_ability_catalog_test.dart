import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_heldenverwaltung/catalog/special_ability_def.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';
import 'package:dsa_heldenverwaltung/rules/derived/requirement_evaluation_rules.dart';
import 'package:dsa_heldenverwaltung/rules/derived/special_ability_variant_rules.dart';

import 'catalog_reference_names.dart';

/// Prueft die strukturierten Voraussetzungen der allgemeinen
/// Sonderfertigkeiten — dieselben Zusicherungen wie beim magischen Katalog.
void main() {
  final eintraege = ladeKatalogDatei('allgemeine_sonderfertigkeiten.json')
      .map(SpecialAbilityDef.fromJson)
      .toList(growable: false);

  Iterable<SpecialAbilityRequirement> alleBedingungen() sync* {
    for (final def in eintraege) {
      yield* alleBedingungenFlach(def.voraussetzungenStruktur);
    }
  }

  test('der Katalog laesst sich vollstaendig lesen', () {
    expect(eintraege, hasLength(26));
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

  test('jede Vorteils-Referenz zeigt auf einen echten Vorteil', () {
    final vorteile = normalisierteNamen('vorteile.json');

    for (final bedingung in alleBedingungen()) {
      if (bedingung.art != RequirementArt.vorteil) {
        continue;
      }
      expect(
        vorteile,
        contains(normalizeSpecialAbilityName(bedingung.name)),
        reason: 'Unbekannter Vorteil "${bedingung.name}"',
      );
    }
  });

  test('Sumus Kind senkt die KO-Schwelle mit Resistenz gegen Krankheiten', () {
    final def = eintraege.firstWhere((def) => def.id == 'easf_sumus_kind');
    final gruppe = def.voraussetzungenStruktur.firstWhere(
      (bedingung) => bedingung.art == RequirementArt.oderGruppe,
    );

    // Zweig 1: KO 20 allein. Zweig 2: KO 18 zusammen mit dem Vorteil.
    expect(gruppe.bedingungen, hasLength(2));
    expect(gruppe.bedingungen.first.code, 'KO');
    expect(gruppe.bedingungen.first.min, 20);
    expect(gruppe.bedingungen.last.art, RequirementArt.undGruppe);
    expect(gruppe.bedingungen.last.bedingungen.first.min, 18);
  });

  test('Geist Ueberwaeltigen laesst Ueberreden und Ueberzeugen zu', () {
    final def = eintraege.firstWhere(
      (def) => def.id == 'easf_geist_ueberwaeltigen',
    );
    final gruppe = def.voraussetzungenStruktur.firstWhere(
      (bedingung) => bedingung.art == RequirementArt.oderGruppe,
    );

    expect(
      gruppe.bedingungen.map((bedingung) => bedingung.name),
      <String>['Überreden', 'Überzeugen'],
    );
  });
}
