import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/catalog/special_ability_entry.dart';
import 'package:dsa_heldenverwaltung/state/settings_providers.dart';
import 'package:dsa_heldenverwaltung/ui/screens/shared/protected_content_helpers.dart';

/// Ergänzt Erwerbsoptionen um lesbare Katalogdetails aller Fähigkeitenarten.
class AdvancementAbilityDetails extends ConsumerWidget {
  /// Verwendet den Sitzungskatalog zur Auflösung von Talent- und Manövernamen.
  const AdvancementAbilityDetails({
    super.key,
    required this.ability,
    required this.catalog,
  });

  /// Fachlicher Eintrag, dessen verfügbare Angaben angezeigt werden.
  final SpecialAbilityEntry ability;

  /// Referenzkatalog der laufenden Steigerungssitzung.
  final RulesCatalog catalog;

  /// Zeigt nur vorhandene Angaben und beachtet die Katalogfreischaltung.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fields = _detailFields(ability, catalog);
    final password = ref.watch(catalogContentPasswordProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final field in fields)
          if (field.$2.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(field.$1, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(
                    resolveProtectedValue(
                          raw: field.$2,
                          unlocked: password?.isNotEmpty == true,
                          password: password,
                        ) ??
                        lockedContentHint,
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

// Die Typadapter teilen Beschriftungen, ohne die schmale Regel-API zu erweitern.
List<(String, String)> _detailFields(
  SpecialAbilityEntry ability,
  RulesCatalog catalog,
) {
  final data = switch (ability) {
    SpecialAbilityDef value => value.toJson(),
    CombatSpecialAbilityDef value => value.toJson(),
    ManeuverDef value => value.toJson(),
    _ => <String, dynamic>{},
  };
  const labels = {
    'beschreibung': 'Beschreibung',
    'erklarung': 'Erklärung',
    'erklarung_lang': 'Ausführlicher Regeltext',
    'voraussetzungen': 'Voraussetzungen laut Regelwerk',
    'kosten': 'Kosten laut Regelwerk',
    'verbreitung': 'Verbreitung',
    'gruppe': 'Gruppe',
    'kategorie': 'Kategorie',
    'stil_typ': 'Stiltyp',
    'kampfTyp': 'Kampfart',
    'erschwernis': 'Erschwernis',
    'quelle': 'Quelle',
    'seite': 'Seite',
  };
  final fields = <(String, String)>[
    for (final entry in labels.entries)
      if (data[entry.key] case final String value) (entry.value, value),
    if (ability.nurEpisch) ('Verfügbarkeit', 'Nur für epische Helden'),
    if (data['hausregel'] == true) ('Herkunft', 'Hausregel'),
    if (ability.kette case final chain?)
      ('Stufenkette', 'Stufe ${chain.stufe}'),
  ];
  RuleMeta? meta;
  switch (ability) {
    case SpecialAbilityDef value:
      meta = value.ruleMeta;
      if (value.aliasNamen.isNotEmpty) {
        fields.add(('Weitere Namen', value.aliasNamen.join(', ')));
      }
      if (value.mehrfachwaehlbar) {
        fields.add(('Erwerb', 'Mehrfach wählbar'));
        fields.add(('Auswahl', value.variantenLabel));
        fields.add(('Varianten', value.varianten.join('\n')));
        for (final group in value.variantenGruppen) {
          fields.add((
            '${group.label} · ${group.ap} AP',
            group.varianten.join('\n'),
          ));
        }
        fields.add((
          'Freie Variante',
          value.variantenFreitext ? 'Erlaubt' : 'Nicht erlaubt',
        ));
      }
      if (value.apErstwerb != null) {
        fields.add(('Erstwerb', '${value.apErstwerb} AP'));
      }
      if (value.apFolgeerwerb != null) {
        fields.add(('Folgeerwerb', '${value.apFolgeerwerb} AP'));
      }
      if (value.nurInformation) {
        fields.add((
          'Hinweis',
          'Wird an anderer Stelle im Heldenbogen gepflegt.',
        ));
      }
    case CombatSpecialAbilityDef value:
      meta = value.ruleMeta;
      fields.add(('Weitere Namen', value.aliasNamen.join(', ')));
      final maneuverNames = {
        for (final maneuver in catalog.maneuvers) maneuver.id: maneuver.name,
      };
      final unlocked = value.aktiviertManoeverIds.map(
        (id) => maneuverNames[id] ?? id,
      );
      fields.add(('Freigeschaltete Manöver', unlocked.join('\n')));
      for (final bonus in value.kampfwertBoni) {
        final talent = _talentName(bonus.giltFuerTalent, catalog);
        fields.add((
          'Kampfwert-Boni · $talent',
          'AT: ${bonus.atBonus} · PA: ${bonus.paBonus} · INI: ${bonus.iniMod}',
        ));
      }
    case ManeuverDef value:
      meta = value.ruleMeta;
      final talents = value.nurFuerTalente.map(
        (id) => _talentName(id, catalog),
      );
      fields.add(('Passende Talente', talents.join(', ')));
      fields.add(('Talentart', value.giltFuerTalentTyp));
      if (value.mussSeparatErlerntWerden) {
        fields.add((
          'Erwerb',
          'Für jedes passende Kampftalent separat erlernen',
        ));
      }
  }
  if (meta != null) {
    if (meta.epic case final epic?) {
      fields.add((
        'Epische Freischaltung',
        'Ab Stufe ${epic.eligibleFromLevel}',
      ));
      if (epic.requiresOptIn) {
        fields.add(('Epische Regeln', 'Freischaltung erforderlich'));
      }
    }
    for (final citation in meta.citations) {
      fields.add((
        'Quellenbeleg',
        '${citation.source} ${citation.locator}'.trim(),
      ));
      fields.add(('Quellenauszug', citation.excerpt));
    }
  }
  return fields;
}

// Katalogreferenzen sollen als bekannte Namen statt als interne IDs erscheinen.
String _talentName(String id, RulesCatalog catalog) {
  for (final talent in catalog.talents) {
    if (talent.id == id) return talent.name;
  }
  return switch (id) {
    'beide' => 'Raufen und Ringen',
    'wahl' => 'Talent nach Wahl',
    _ => id,
  };
}
