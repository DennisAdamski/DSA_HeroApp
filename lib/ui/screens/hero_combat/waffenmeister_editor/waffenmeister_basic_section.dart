import 'package:flutter/material.dart';

import 'package:dsa_heldenverwaltung/catalog/rules_catalog.dart';
import 'package:dsa_heldenverwaltung/domain/combat_config.dart';
import 'package:dsa_heldenverwaltung/ui/screens/hero_combat/weapon_editor/weapon_editor_section_card.dart';

/// Erlaubte Eigenschaftskuerzel fuer die Waffenmeister-Anforderungen.
const _attributeOptions = ['MU', 'IN', 'FF', 'GE', 'KK'];

/// Stammdaten-Sektion des Waffenmeister-Editors.
///
/// Zeigt Talent-Auswahl, Waffenart, Stil, Lehrmeister und
/// Eigenschafts-Anforderungen.
class WaffenmeisterBasicSection extends StatelessWidget {
  const WaffenmeisterBasicSection({
    super.key,
    required this.draft,
    required this.combatTalents,
    required this.catalog,
    required this.styleNameController,
    required this.masterNameController,
    required this.attr1ValueController,
    required this.attr2ValueController,
    required this.onChanged,
  });

  final WaffenmeisterConfig draft;
  final List<TalentDef> combatTalents;
  final RulesCatalog catalog;
  final TextEditingController styleNameController;
  final TextEditingController masterNameController;
  final TextEditingController attr1ValueController;
  final TextEditingController attr2ValueController;
  final ValueChanged<WaffenmeisterConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    // Waffenarten aus dem Katalog fuer das gewaehlte Talent ermitteln
    final weaponTypes = _weaponTypesForTalent(draft.talentId);

    return WeaponEditorSectionCard(
      title: 'Stammdaten',
      subtitle: 'Kampftalent, Waffenart und Eigenschafts-Anforderungen.',
      child: Column(
        children: [
          // Kampftalent
          DropdownButtonFormField<String>(
            initialValue: draft.talentId.isNotEmpty ? draft.talentId : null,
            decoration: const InputDecoration(
              labelText: 'Kampftalent',
              border: OutlineInputBorder(),
            ),
            items: combatTalents.map((talent) {
              return DropdownMenuItem(
                value: talent.id,
                child: Text('${talent.name} (${talent.steigerung})'),
              );
            }).toList(growable: false),
            onChanged: (value) {
              final newTypes = _weaponTypesForTalent(value ?? '');
              onChanged(draft.copyWith(
                talentId: value ?? '',
                weaponType: newTypes.contains(draft.weaponType)
                    ? draft.weaponType
                    : '',
              ));
            },
          ),
          const SizedBox(height: 12),

          // Waffenart
          if (weaponTypes.isEmpty)
            DropdownButtonFormField<String>(
              initialValue: draft.weaponType.isNotEmpty ? draft.weaponType : null,
              decoration: const InputDecoration(
                labelText: 'Waffenart (Freitext)',
                border: OutlineInputBorder(),
              ),
              items: const [],
              onChanged: null,
            )
          else
            Autocomplete<String>(
              initialValue: TextEditingValue(text: draft.weaponType),
              optionsBuilder: (textEditingValue) {
                final query = textEditingValue.text.toLowerCase();
                if (query.isEmpty) return weaponTypes;
                return weaponTypes.where(
                  (type) => type.toLowerCase().contains(query),
                );
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Waffenart',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    onChanged(draft.copyWith(weaponType: value));
                  },
                  onSubmitted: (_) => onSubmitted(),
                );
              },
              onSelected: (value) {
                onChanged(draft.copyWith(weaponType: value));
              },
            ),
          const SizedBox(height: 12),

          // Zusaetzliche Waffen
          TextField(
            decoration: const InputDecoration(
              labelText: 'Zusätzliche Waffen (kommagetrennt, max. 2)',
              border: OutlineInputBorder(),
              helperText: 'Kostet 2 automatische Punkte falls belegt.',
            ),
            controller: TextEditingController(
              text: draft.additionalWeaponTypes.join(', '),
            ),
            onChanged: (value) {
              final types = value
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .take(2)
                  .toList();
              onChanged(draft.copyWith(additionalWeaponTypes: types));
            },
          ),
          const SizedBox(height: 12),

          // Stil und Lehrmeister
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: styleNameController,
                  decoration: const InputDecoration(
                    labelText: 'Stilname (optional)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    onChanged(draft.copyWith(styleName: value));
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: masterNameController,
                  decoration: const InputDecoration(
                    labelText: 'Lehrmeister (optional)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    onChanged(draft.copyWith(masterName: value));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Eigenschafts-Anforderungen
          Text(
            'Eigenschafts-Anforderungen (Summe 32, GE mind. 13)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: draft.requiredAttribute1,
                  decoration: const InputDecoration(
                    labelText: 'Eigenschaft 1',
                    border: OutlineInputBorder(),
                  ),
                  items: _attributeOptions.map((attr) {
                    return DropdownMenuItem(value: attr, child: Text(attr));
                  }).toList(growable: false),
                  onChanged: (value) {
                    onChanged(draft.copyWith(
                      requiredAttribute1: value ?? 'GE',
                    ));
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: attr1ValueController,
                  decoration: const InputDecoration(
                    labelText: 'Wert',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final parsed = int.tryParse(value) ?? 13;
                    onChanged(draft.copyWith(
                      requiredAttribute1Value: parsed,
                    ));
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: draft.requiredAttribute2,
                  decoration: const InputDecoration(
                    labelText: 'Eigenschaft 2',
                    border: OutlineInputBorder(),
                  ),
                  items: _attributeOptions.map((attr) {
                    return DropdownMenuItem(value: attr, child: Text(attr));
                  }).toList(growable: false),
                  onChanged: (value) {
                    onChanged(draft.copyWith(
                      requiredAttribute2: value ?? 'KK',
                    ));
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: attr2ValueController,
                  decoration: const InputDecoration(
                    labelText: 'Wert',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final parsed = int.tryParse(value) ?? 13;
                    onChanged(draft.copyWith(
                      requiredAttribute2Value: parsed,
                    ));
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Ermittelt die Waffenarten aus dem Katalog fuer ein Talent.
  List<String> _weaponTypesForTalent(String talentId) {
    if (talentId.isEmpty) return const [];
    final talentDef = combatTalents.where((t) => t.id == talentId).firstOrNull;
    if (talentDef == null) return const [];
    // Waffenkategorien aus dem Talent parsen
    final categories = talentDef.weaponCategory
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && !s.startsWith('improvisiert'))
        .toList();
    if (categories.isNotEmpty) return categories;
    // Fallback: Waffennamen aus dem Katalog
    return catalog.weapons
        .where((w) => w.combatSkill == talentDef.name)
        .map((w) => w.name)
        .toList();
  }
}
