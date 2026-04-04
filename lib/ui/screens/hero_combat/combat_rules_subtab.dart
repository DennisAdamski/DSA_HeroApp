part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

/// Kampfregeln-Subtab mit aufgeräumten, ausklappbaren Bereichen.
extension _CombatRulesSubtab on _HeroCombatTabState {
  Widget _buildCombatRulesSubTab({
    required HeroSheet hero,
    required HeroState heroState,
    required RulesCatalog catalog,
  }) {
    final rules = _draftCombatConfig.specialRules;
    final isEditing = _editController.isEditing;
    final groupedManeuvers = _groupCatalogManeuvers(catalog);
    final activeManeuverIds = _effectiveActiveManeuverIds(catalog);
    final fkTalents = catalog.talents
        .where((t) => t.type.toLowerCase() == 'fernkampf')
        .toList();

    final maneuverIdSet = catalog.maneuvers
        .map((m) => m.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    final allgemeineSf = catalog.combatSpecialAbilities
        .where((a) => !a.isUnarmedCombatStyle)
        .where((a) {
          final dupeId = canonicalManeuverIdFromName(
            a.name,
            catalogManeuvers: catalog.maneuvers,
          );
          return !maneuverIdSet.contains(dupeId);
        })
        .toList();

    final waffenloseStile = catalog.combatSpecialAbilities
        .where((a) => a.isUnarmedCombatStyle)
        .toList();

    final nahkampfManeuver =
        groupedManeuvers['bewaffnet'] ?? const <ManeuverDef>[];
    final fernkampfManeuver = catalog.maneuvers
        .where((m) => m.gruppe == 'fernkampf')
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final waffenloseManeuver =
        groupedManeuvers['waffenlos'] ?? const <ManeuverDef>[];

    Widget buildGroup({
      required String title,
      required int count,
      required Widget content,
    }) {
      return Card(
        child: ExpansionTile(
          title: Text(
            '$title ($count)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: content,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        buildGroup(
          title: 'Allgemeine Kampf-Sonderfertigkeiten',
          count: allgemeineSf.length,
          content: _buildSfChipWrap(
            abilities: allgemeineSf,
            catalog: catalog,
            rules: rules,
            isEditing: isEditing,
          ),
        ),
        const SizedBox(height: 8),
        buildGroup(
          title: 'Nahkampf-Manöver',
          count: nahkampfManeuver.length,
          content: _buildManeuverChipWrap(
            maneuvers: nahkampfManeuver,
            rules: rules,
            activeManeuverIds: activeManeuverIds,
            isEditing: isEditing,
          ),
        ),
        const SizedBox(height: 8),
        buildGroup(
          title: 'Fernkampf-Manöver',
          count: _countFernkampfEntries(fernkampfManeuver, fkTalents),
          content: _buildFernkampfManeuverChipWrap(
            fernkampfManeuver: fernkampfManeuver,
            fkTalents: fkTalents,
            rules: rules,
            activeManeuverIds: activeManeuverIds,
            isEditing: isEditing,
          ),
        ),
        const SizedBox(height: 8),
        buildGroup(
          title: 'Waffenlose Kampfstile',
          count: waffenloseStile.length,
          content: _buildSfChipWrap(
            abilities: waffenloseStile,
            catalog: catalog,
            rules: rules,
            isEditing: isEditing,
          ),
        ),
        const SizedBox(height: 8),
        buildGroup(
          title: 'Waffenlose Manöver',
          count: waffenloseManeuver.length,
          content: _buildManeuverChipWrap(
            maneuvers: waffenloseManeuver,
            rules: rules,
            activeManeuverIds: activeManeuverIds,
            isEditing: isEditing,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ExpansionTile(
            title: Text(
              'Waffenmeister (${_draftCombatConfig.waffenmeisterschaften.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _buildWaffenmeisterSection(catalog),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWaffenmeisterSection(RulesCatalog catalog) {
    final wmList = _draftCombatConfig.waffenmeisterschaften;
    final isEditing = _editController.isEditing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Waffenmeister',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (isEditing)
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Waffenmeister hinzufügen',
                onPressed: () => _openWaffenmeisterEditor(
                  catalog: catalog,
                  index: -1,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (wmList.isEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Keine Waffenmeisterschaft konfiguriert.'),
              subtitle: const Text(
                'Voraussetzungen: TaW 18, Waffenspezialisierung, '
                '2.500 AP in Kampf-SF, Eigenschafts-Anforderungen.',
              ),
            ),
          ),
        ...List.generate(wmList.length, (index) {
          final wm = wmList[index];
          final talentDef = catalog.talents
              .where((t) => t.id == wm.talentId)
              .firstOrNull;
          final talentName = talentDef?.name ?? wm.talentId;
          final bonusCount = wm.bonuses.length;
          return Card(
            child: ListTile(
              leading: const Icon(Icons.military_tech),
              title: Text('Waffenmeister (${wm.weaponType})'),
              subtitle: Text(
                '$talentName · $bonusCount Boni'
                '${wm.styleName.isNotEmpty ? ' · ${wm.styleName}' : ''}',
              ),
              trailing: isEditing
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Bearbeiten',
                          onPressed: () => _openWaffenmeisterEditor(
                            catalog: catalog,
                            index: index,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          tooltip: 'Entfernen',
                          onPressed: () {
                            final next = List<WaffenmeisterConfig>.from(
                              wmList,
                            )..removeAt(index);
                            _draftCombatConfig =
                                _draftCombatConfig.copyWith(
                              waffenmeisterschaften: next,
                            );
                            _markFieldChanged();
                          },
                        ),
                      ],
                    )
                  : null,
            ),
          );
        }),
      ],
    );
  }

  void _openWaffenmeisterEditor({
    required RulesCatalog catalog,
    required int index,
  }) {
    final isNew = index < 0;
    final initial = isNew
        ? const WaffenmeisterConfig()
        : _draftCombatConfig.waffenmeisterschaften[index];
    final combatTalents =
        catalog.talents.where((t) => t.group == 'Kampftalent').toList();

    Navigator.of(context).push(
      MaterialPageRoute<WaffenmeisterConfig>(
        builder: (_) => WaffenmeisterEditorScreen(
          initialConfig: initial,
          isNew: isNew,
          combatTalents: combatTalents,
          catalog: catalog,
          onSaved: (result) {
            final wmList = List<WaffenmeisterConfig>.from(
              _draftCombatConfig.waffenmeisterschaften,
            );
            if (isNew) {
              wmList.add(result);
            } else {
              wmList[index] = result;
            }
            _draftCombatConfig = _draftCombatConfig.copyWith(
              waffenmeisterschaften: wmList,
            );
            _markFieldChanged();
            Navigator.of(context).pop();
          },
          onCancel: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  /// Rendert eine Gruppe von Nahkampf- oder Waffenlosen-Manövern als Chip-Wrap.
  Widget _buildManeuverChipWrap({
    required List<ManeuverDef> maneuvers,
    required CombatSpecialRules rules,
    required Set<String> activeManeuverIds,
    required bool isEditing,
  }) {
    if (maneuvers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Keine Einträge vorhanden.'),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: maneuvers.map((maneuver) {
        final isActive = activeManeuverIds.contains(maneuver.id);
        final typStr = maneuver.typ.trim();
        final erschStr = maneuver.erschwernis.trim();
        final beschreibung = [typStr, erschStr]
            .where((s) => s.isNotEmpty)
            .join(' · ');
        return ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 160, maxWidth: 260),
          child: _CombatRuleChip(
            name: maneuver.name,
            beschreibung: beschreibung,
            isActive: isActive,
            isEditing: isEditing,
            onToggle: (value) {
              final active = List<String>.from(rules.activeManeuvers);
              if (value) {
                active.add(maneuver.id);
              } else {
                active.removeWhere((e) => e == maneuver.id);
              }
              _draftCombatConfig = _draftCombatConfig.copyWith(
                specialRules: rules.copyWith(activeManeuvers: active),
              );
              _markFieldChanged();
            },
            onNameTap: () => _showCombatManeuverDetailsDialog(
              context: context,
              maneuver: maneuver,
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Zählt die tatsächlich angezeigten FK-Chip-Einträge (per-Talent aufgespalten).
  int _countFernkampfEntries(
    List<ManeuverDef> maneuvers,
    List<TalentDef> fkTalents,
  ) {
    var count = 0;
    for (final m in maneuvers) {
      if (m.mussSeparatErlerntWerden) {
        count += m.nurFuerTalente.isEmpty
            ? fkTalents.length
            : m.nurFuerTalente
                .where((id) => fkTalents.any((t) => t.id == id))
                .length;
      } else {
        count += 1;
      }
    }
    return count;
  }

  /// Rendert Fernkampf-Manöver als Chip-Wrap.
  /// Per-Talent-Manöver (mussSeparatErlerntWerden) werden fuer jedes FK-Talent
  /// einzeln als eigener Chip angezeigt; Toggle-ID: `<id>::<talentId>`.
  Widget _buildFernkampfManeuverChipWrap({
    required List<ManeuverDef> fernkampfManeuver,
    required List<TalentDef> fkTalents,
    required CombatSpecialRules rules,
    required Set<String> activeManeuverIds,
    required bool isEditing,
  }) {
    if (fernkampfManeuver.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Keine Fernkampf-Manöver im Katalog.'),
      );
    }

    final chips = <Widget>[];

    for (final maneuver in fernkampfManeuver) {
      final typStr = maneuver.typ.trim();
      final erschStr = maneuver.erschwernis.trim();
      final beschreibung =
          [typStr, erschStr].where((s) => s.isNotEmpty).join(' · ');

      if (maneuver.mussSeparatErlerntWerden) {
        final applicableTalents = maneuver.nurFuerTalente.isEmpty
            ? fkTalents
            : fkTalents
                .where((t) => maneuver.nurFuerTalente.contains(t.id))
                .toList();
        for (final talent in applicableTalents) {
          final toggleId = '${maneuver.id}::${talent.id}';
          final isActive = activeManeuverIds.contains(toggleId);
          chips.add(
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 160, maxWidth: 260),
              child: _CombatRuleChip(
                name: '${maneuver.name} (${talent.name})',
                beschreibung: beschreibung,
                isActive: isActive,
                isEditing: isEditing,
                onToggle: (value) {
                  final active = List<String>.from(rules.activeManeuvers);
                  if (value) {
                    active.add(toggleId);
                  } else {
                    active.removeWhere((e) => e == toggleId);
                  }
                  _draftCombatConfig = _draftCombatConfig.copyWith(
                    specialRules: rules.copyWith(activeManeuvers: active),
                  );
                  _markFieldChanged();
                },
                onNameTap: () => _showCombatManeuverDetailsDialog(
                  context: context,
                  maneuver: maneuver,
                ),
              ),
            ),
          );
        }
      } else {
        final isActive = activeManeuverIds.contains(maneuver.id);
        chips.add(
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 160, maxWidth: 260),
            child: _CombatRuleChip(
              name: maneuver.name,
              beschreibung: beschreibung,
              isActive: isActive,
              isEditing: isEditing,
              onToggle: (value) {
                final active = List<String>.from(rules.activeManeuvers);
                if (value) {
                  active.add(maneuver.id);
                } else {
                  active.removeWhere((e) => e == maneuver.id);
                }
                _draftCombatConfig = _draftCombatConfig.copyWith(
                  specialRules: rules.copyWith(activeManeuvers: active),
                );
                _markFieldChanged();
              },
              onNameTap: () => _showCombatManeuverDetailsDialog(
                context: context,
                maneuver: maneuver,
              ),
            ),
          ),
        );
      }
    }

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}
