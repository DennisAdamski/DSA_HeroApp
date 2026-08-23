import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attribute_codes.dart';
import 'package:dsa_heldenverwaltung/rules/derived/magic_acquisition_rules.dart';

/// Talentgruppen der Kategorie Kampf und Koerper.
const List<String> kTraitChoiceCombatBodyTalentGroups = <String>[
  'Kampftalent',
  'Körperliche Talente',
];

/// Bekannte Werte fuer `HeroTraitDef.choiceSource`.
///
/// Wird von `test/catalog/trait_choice_catalog_test.dart` gegen den echten
/// Katalog geprueft: ein Tippfehler faellt sonst erst im Betrieb auf, und dort
/// nur als leeres Auswahlfeld.
const Set<String> kKnownTraitChoiceSources = <String>{
  'eigenschaften',
  'talente',
  'talente_handwerk',
  'talente_kampf_koerper',
  'talente_sonstige',
  'talentgruppen',
  'talentgruppen_kampf_koerper',
  'talentgruppen_sonstige',
  'zauber',
  'rituale',
  'merkmale',
  'schlechte_eigenschaften',
  'sprachen',
  'schriften',
};

/// Loest die Auswahlmoeglichkeiten eines Vor-/Nachteils auf.
///
/// Die festen `choices` des Katalogeintrags stehen vorne und behalten ihre
/// Reihenfolge; die ueber `choiceSource` referenzierte Katalogliste folgt
/// alphabetisch sortiert. Doppelte Eintraege werden entfernt.
List<String> resolveTraitChoices(HeroTraitDef trait, RulesCatalog? catalog) {
  final result = <String>[];
  final seen = <String>{};

  void add(String value) {
    final name = value.trim();
    if (name.isEmpty) {
      return;
    }
    final key = name.toLowerCase();
    if (seen.add(key)) {
      result.add(name);
    }
  }

  for (final choice in trait.choices) {
    add(choice);
  }

  final sourced = _resolveChoiceSource(trait.choiceSource, catalog);
  for (final choice in sourced) {
    add(choice);
  }

  return List<String>.unmodifiable(result);
}

List<String> _resolveChoiceSource(String source, RulesCatalog? catalog) {
  if (source.isEmpty) {
    return const <String>[];
  }

  if (source == 'eigenschaften') {
    return AttributeCode.values.map(attributeCodeKey).toList(growable: false);
  }
  if (source == 'merkmale') {
    return _sorted(<String>[
      ...kMerkmaleKlassifikationI,
      ...kMerkmaleKlassifikationII,
      ...kMerkmaleKlassifikationIII,
    ]);
  }

  if (catalog == null) {
    return const <String>[];
  }

  switch (source) {
    case 'talente':
      return _sorted(catalog.talents.map((talent) => talent.name));
    case 'talente_handwerk':
      return _sorted(
        catalog.talents
            .where((talent) => _isGroup(talent.group, 'Handwerkliche Talente'))
            .map((talent) => talent.name),
      );
    case 'talente_kampf_koerper':
      return _sorted(
        catalog.talents
            .where((talent) => _isCombatBodyGroup(talent.group))
            .map((talent) => talent.name),
      );
    case 'talente_sonstige':
      return _sorted(
        catalog.talents
            .where((talent) => !_isCombatBodyGroup(talent.group))
            .map((talent) => talent.name),
      );
    case 'talentgruppen':
      return _sorted(catalog.talents.map((talent) => talent.group));
    case 'talentgruppen_kampf_koerper':
      return _sorted(
        catalog.talents.map((talent) => talent.group).where(_isCombatBodyGroup),
      );
    case 'talentgruppen_sonstige':
      return _sorted(
        catalog.talents
            .map((talent) => talent.group)
            .where((group) => !_isCombatBodyGroup(group)),
      );
    case 'zauber':
      return _sorted(catalog.spells.map((spell) => spell.name));
    case 'rituale':
      // Einzelrituale stecken in den Variantengruppen der 17 Ritualgruppen der
      // Kategorie `Traditionsrituale`, nicht in einem eigenen Katalog.
      return _sorted(<String>[
        for (final ability in catalog.magicSpecialAbilities)
          if (_isGroup(ability.kategorie, 'Traditionsrituale')) ...<String>[
            ...ability.varianten,
            for (final gruppe in ability.variantenGruppen) ...gruppe.varianten,
          ],
      ]);
    case 'schlechte_eigenschaften':
      // Der Marker `SE` kennzeichnet im Nachteilkatalog genau die Schlechten
      // Eigenschaften. Eintraege mit Platzhalter im Namen (`Angst vor [...]`)
      // bleiben draussen — die brauchen ihre eigene Detailangabe.
      return _sorted(
        catalog.disadvantages
            .where(
              (trait) =>
                  trait.markers.contains('SE') && !trait.name.contains('['),
            )
            .map((trait) => trait.name),
      );
    case 'sprachen':
      return _sorted(catalog.sprachen.map((sprache) => sprache.name));
    case 'schriften':
      return _sorted(catalog.schriften.map((schrift) => schrift.name));
    default:
      return const <String>[];
  }
}

bool _isCombatBodyGroup(String group) {
  return kTraitChoiceCombatBodyTalentGroups.any(
    (known) => _isGroup(group, known),
  );
}

bool _isGroup(String value, String expected) {
  return value.trim().toLowerCase() == expected.toLowerCase();
}

List<String> _sorted(Iterable<String> values) {
  final names = values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();
  names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return names;
}
