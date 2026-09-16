import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_requirement.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_options.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_skill_tree.dart';

void main() {
  test('UND und ODER bleiben getrennte Verknüpfungen mit allen Vorstufen', () {
    const catalog = RulesCatalog(
      version: 'test',
      source: 'test',
      talents: [],
      spells: [],
      weapons: [],
      generalSpecialAbilities: [
        SpecialAbilityDef(id: 'a', name: 'Erste', kosten: '10 AP'),
        SpecialAbilityDef(id: 'b', name: 'Zweite', kosten: '10 AP'),
        SpecialAbilityDef(
          id: 'c',
          name: 'Ziel',
          kosten: '20 AP',
          voraussetzungenStruktur: [
            SpecialAbilityRequirement(
              art: RequirementArt.oderGruppe,
              bedingungen: [
                SpecialAbilityRequirement(
                  art: RequirementArt.sonderfertigkeit,
                  name: 'Erste',
                ),
                SpecialAbilityRequirement(
                  art: RequirementArt.undGruppe,
                  bedingungen: [
                    SpecialAbilityRequirement(
                      art: RequirementArt.sonderfertigkeit,
                      name: 'Zweite',
                    ),
                    SpecialAbilityRequirement(
                      art: RequirementArt.eigenschaft,
                      code: 'MU',
                      min: 15,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    const hero = HeroSheet(
      id: 'hero',
      name: 'Held',
      level: 1,
      attributes: Attributes(
        mu: 12,
        kl: 12,
        inn: 12,
        ch: 12,
        ff: 12,
        ge: 12,
        ko: 12,
        kk: 12,
      ),
      apAvailable: 50,
    );
    final options = buildAdvancementOptions(hero: hero, catalog: catalog);
    final graph = buildAdvancementSkillTree(
      options: options,
      plannedTargets: {},
      availableAp: hero.apAvailable,
    );
    expect(graph.nodes.values.where((n) => n.label == 'ODER'), hasLength(1));
    expect(graph.nodes.values.where((n) => n.label == 'UND'), hasLength(1));
    expect(graph.nodes['generalAbility:c']!.status, SkillTreeStatus.blocked);
    final result = graph.components(query: 'Ziel', category: 'Allgemein');
    expect(
      result.single,
      containsAll(['generalAbility:a', 'generalAbility:b', 'generalAbility:c']),
    );
  });

  test('Zyklen bleiben darstellbar und geplante Zustände haben Vorrang', () {
    const catalog = RulesCatalog(
      version: 'test',
      source: 'test',
      talents: [],
      spells: [],
      weapons: [],
      generalSpecialAbilities: [
        SpecialAbilityDef(
          id: 'a',
          name: 'Erste',
          kosten: '10 AP',
          voraussetzungenStruktur: [
            SpecialAbilityRequirement(
              art: RequirementArt.sonderfertigkeit,
              name: 'Zweite',
            ),
          ],
        ),
        SpecialAbilityDef(
          id: 'b',
          name: 'Zweite',
          kosten: '10 AP',
          voraussetzungenStruktur: [
            SpecialAbilityRequirement(
              art: RequirementArt.sonderfertigkeit,
              name: 'Erste',
            ),
          ],
        ),
      ],
    );
    const hero = HeroSheet(
      id: 'hero',
      name: 'Held',
      level: 1,
      attributes: Attributes(
        mu: 12,
        kl: 12,
        inn: 12,
        ch: 12,
        ff: 12,
        ge: 12,
        ko: 12,
        kk: 12,
      ),
    );
    final graph = buildAdvancementSkillTree(
      options: buildAdvancementOptions(hero: hero, catalog: catalog),
      plannedTargets: {'generalAbility:a'},
      availableAp: 0,
    );
    final ids = graph.components().single;
    expect(graph.levels(ids).values.every((v) => v < 5), isTrue);
    expect(graph.nodes['generalAbility:a']!.status, SkillTreeStatus.planned);
  });
}
