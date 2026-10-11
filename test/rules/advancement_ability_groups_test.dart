import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/attributes.dart';
import 'package:dsa_heldenverwaltung/domain/hero_advancement_entry.dart';
import 'package:dsa_heldenverwaltung/domain/hero_sheet.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_ability_groups.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_options.dart';
import 'package:dsa_heldenverwaltung/rules/derived/advancement_skill_tree.dart';

import '../test_support/real_catalog.dart';

const _hero = HeroSheet(
  id: 'gruppen',
  name: 'Held',
  level: 1,
  apAvailable: 5000,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RulesCatalog catalog;
  late List<AdvancementOption> faehigkeiten;

  setUpAll(() async {
    catalog = (await ladeEchtenRegelkatalog()).catalog;
    faehigkeiten = buildAdvancementOptions(
      hero: _hero,
      catalog: catalog,
    ).where((option) => !option.isValueAdvancement).toList();
  });

  AdvancementOption finde(String name) =>
      faehigkeiten.firstWhere((o) => o.label == name);

  test('Jede Fähigkeit liegt in einer Gruppe ihres eigenen Bereichs', () {
    expect(faehigkeiten, isNotEmpty);
    for (final option in faehigkeiten) {
      final bereich = switch (option.kind) {
        AdvancementKind.combatAbility ||
        AdvancementKind.maneuver => FaehigkeitenBereich.kampf,
        AdvancementKind.magicAbility => FaehigkeitenBereich.magie,
        AdvancementKind.karmalAbility => FaehigkeitenBereich.karma,
        _ => FaehigkeitenBereich.allgemein,
      };
      expect(
        faehigkeitenGruppeFuer(option).bereich,
        bereich,
        reason: option.label,
      );
    }
  });

  test('Jede Gruppe enthält Katalogeinträge, kein Zuordnungsname ist tot', () {
    final belegt = {for (final o in faehigkeiten) faehigkeitenGruppeFuer(o)};
    for (final gruppe in FaehigkeitenGruppe.values) {
      expect(belegt, contains(gruppe), reason: gruppe.name);
    }
  });

  test('Kampf-Fähigkeiten landen in ihren fachlichen Gruppen', () {
    final erwartet = {
      'Aufmerksamkeit': FaehigkeitenGruppe.kampfGrundlagen,
      'Kampfreflexe': FaehigkeitenGruppe.kampfGrundlagen,
      'Ausweichen I': FaehigkeitenGruppe.kampfKetten,
      'Rüstungsgewöhnung II': FaehigkeitenGruppe.kampfKetten,
      'Ausfall': FaehigkeitenGruppe.kampfWaffenmanoever,
      'Finte': FaehigkeitenGruppe.kampfWaffenmanoever,
      'Tritt': FaehigkeitenGruppe.kampfWaffenlosManoever,
      'Gladiatorenstil': FaehigkeitenGruppe.kampfStile,
      'Waffenmeister': FaehigkeitenGruppe.kampfMeister,
      'Waffenspezialisierung': FaehigkeitenGruppe.kampfMeister,
      'Reiterkampf': FaehigkeitenGruppe.kampfSpezial,
    };
    for (final eintrag in erwartet.entries) {
      expect(
        faehigkeitenGruppeFuer(finde(eintrag.key)),
        eintrag.value,
        reason: eintrag.key,
      );
    }
  });

  test('Epische waffenlose Kampfstile gehören zu den Kampfstilen', () {
    final epische = faehigkeiten.where((o) {
      final ability = o.ability;
      return ability is CombatSpecialAbilityDef &&
          ability.kategorie == 'Waffenloser Kampfstil';
    }).toList();
    expect(epische, isNotEmpty);
    for (final option in epische) {
      expect(
        faehigkeitenGruppeFuer(option),
        FaehigkeitenGruppe.kampfStile,
        reason: option.label,
      );
    }
  });

  test('Waffen-Großmeister liegen bei den Waffenmeistern', () {
    final meister = faehigkeiten.where((o) {
      final ability = o.ability;
      return ability is CombatSpecialAbilityDef &&
          ability.kampfTyp == 'grossmeister';
    }).toList();
    expect(meister, isNotEmpty);
    expect(meister.map(faehigkeitenGruppeFuer).toSet(), {
      FaehigkeitenGruppe.kampfMeister,
    });
  });

  test('Gruppierung verliert keinen Knoten und bildet Zweige je Gruppe', () {
    final graph = buildAdvancementSkillTree(
      options: faehigkeiten,
      plannedTargets: const {},
      availableAp: 5000,
    );
    final gruppen = gruppiereFaehigkeiten(graph: graph);
    final echte = graph.nodes.values.where((n) => n.option != null).length;
    expect(gruppen.values.fold<int>(0, (s, g) => s + g.anzahl), echte);

    // Jeder Knoten eines Zweigs gehört zur Gruppe des Zweigs.
    for (final eintrag in gruppen.entries) {
      for (final zweig in eintrag.value.zweige) {
        for (final id in zweig) {
          final option = graph.nodes[id]!.option;
          if (option == null) continue;
          expect(
            faehigkeitenGruppeFuer(option),
            eintrag.key,
            reason: graph.nodes[id]!.label,
          );
        }
      }
    }

    // Finte → Ausfall bildet einen Zweig in genau einer Gruppe.
    final finte = 'maneuver:${finde('Finte').targetId}';
    final ausfall = 'maneuver:${finde('Ausfall').targetId}';
    final treffer = [
      for (final eintrag in gruppen.entries)
        for (final zweig in eintrag.value.zweige)
          if (zweig.contains(finte) || zweig.contains(ausfall)) zweig,
    ];
    expect(treffer, hasLength(1));
    expect(treffer.single, containsAll([finte, ausfall]));

    // Einzelne sind alphabetisch sortiert.
    for (final inhalt in gruppen.values) {
      final namen = [
        for (final id in inhalt.einzelne) graph.nodes[id]!.label.toLowerCase(),
      ];
      expect(namen, [...namen]..sort());
    }
  });

  test('Ausweichen und Rüstungsgewöhnung stehen beide bei den Ketten', () {
    final graph = buildAdvancementSkillTree(
      options: faehigkeiten,
      plannedTargets: const {},
      availableAp: 5000,
    );
    final ketten = gruppiereFaehigkeiten(
      graph: graph,
    )[FaehigkeitenGruppe.kampfKetten]!;
    final namen = {
      for (final zweig in ketten.zweige)
        for (final id in zweig) graph.nodes[id]!.label,
    };
    expect(
      namen,
      containsAll(['Ausweichen I', 'Ausweichen II', 'Ausweichen III']),
    );
    expect(namen, containsAll(['Rüstungsgewöhnung I', 'Rüstungsgewöhnung IV']));
    expect(namen, containsAll(['Schildkampf I', 'Parierwaffen I']));
    // Die Ausweichen-Stufen hängen untereinander zusammen.
    final ausweichen = ketten.zweige.firstWhere(
      (z) => z.any((id) => graph.nodes[id]!.label == 'Ausweichen I'),
    );
    expect(
      ausweichen.map((id) => graph.nodes[id]!.label),
      containsAll(['Ausweichen II', 'Ausweichen III']),
    );
  });

  test('Suche, Bereich und „Nur erlernbar“ schränken die Gruppen ein', () {
    final graph = buildAdvancementSkillTree(
      options: faehigkeiten,
      plannedTargets: const {},
      availableAp: 5000,
    );
    final suche = gruppiereFaehigkeiten(graph: graph, query: 'tritt');
    expect(suche.keys, contains(FaehigkeitenGruppe.kampfWaffenlosManoever));
    expect(suche.keys, isNot(contains(FaehigkeitenGruppe.magieTraditionen)));

    final magie = gruppiereFaehigkeiten(
      graph: graph,
      bereich: FaehigkeitenBereich.magie,
    );
    expect(
      magie.keys.every((g) => g.bereich == FaehigkeitenBereich.magie),
      true,
    );
    expect(magie, isNotEmpty);

    final alle = gruppiereFaehigkeiten(graph: graph);
    final erlernbar = gruppiereFaehigkeiten(graph: graph, nurErlernbar: true);
    final summeAlle = alle.values.fold<int>(0, (s, g) => s + g.anzahl);
    final summeErlernbar = erlernbar.values.fold<int>(
      0,
      (s, g) => s + g.anzahl,
    );
    expect(summeErlernbar, lessThan(summeAlle));
  });

  test('Verknüpfungsknoten ohne Voraussetzung in der Gruppe entfallen', () {
    final waffen = faehigkeiten.firstWhere(
      (o) =>
          faehigkeitenGruppeFuer(o) == FaehigkeitenGruppe.kampfWaffenmanoever,
    );
    final waffenlos = faehigkeiten.firstWhere(
      (o) =>
          faehigkeitenGruppeFuer(o) ==
          FaehigkeitenGruppe.kampfWaffenlosManoever,
    );
    SkillTreeNode node(AdvancementOption option) => SkillTreeNode(
      id: '${option.kind.name}:${option.targetId}',
      label: option.label,
      category: 'Kampf',
      status: SkillTreeStatus.available,
      option: option,
    );
    final ziel = node(waffen);
    final fremd = node(waffenlos);
    const oder = SkillTreeNode(
      id: 'oder',
      label: 'ODER',
      category: 'Kampf',
      status: SkillTreeStatus.available,
    );
    final graph = AdvancementSkillTree(
      {ziel.id: ziel, fremd.id: fremd, oder.id: oder},
      [(from: fremd.id, to: oder.id), (from: oder.id, to: ziel.id)],
    );
    final gruppen = gruppiereFaehigkeiten(graph: graph);
    // Die Voraussetzung liegt in einer anderen Gruppe: das Ziel steht allein.
    expect(gruppen[FaehigkeitenGruppe.kampfWaffenmanoever]!.einzelne, [
      ziel.id,
    ]);
    expect(gruppen[FaehigkeitenGruppe.kampfWaffenmanoever]!.zweige, isEmpty);
    expect(gruppen[FaehigkeitenGruppe.kampfWaffenlosManoever]!.einzelne, [
      fremd.id,
    ]);
  });
}
