part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

/// Kampfregeln-Subtab mit aufgeräumten, ausklappbaren Bereichen.
extension _CombatRulesSubtab on _HeroCombatTabState {
  Widget _buildCombatRulesSubTab({
    required HeroSheet hero,
    required HeroState heroState,
    required RulesCatalog catalog,
  }) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: ExpansionTile(
            initiallyExpanded: true,
            title: Text(
              'Sonderfertigkeiten',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _buildSpecialRulesSection(
                  hero,
                  heroState,
                  catalog: catalog,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            initiallyExpanded: true,
            title: Text(
              'Waffenmeister',
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
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            initiallyExpanded: true,
            title: Text(
              'Manöver',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _buildManeuversSection(catalog),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Sonderfertigkeiten
  // ---------------------------------------------------------------------------

  Widget _buildSpecialRulesSection(
    HeroSheet hero,
    HeroState state, {
    required RulesCatalog catalog,
  }) {
    final rules = _draftCombatConfig.specialRules;
    final armor = _draftCombatConfig.armor;
    final parsed = parseModifierTextsForHero(hero);
    final axxeleratusActive = isAxxeleratusEffectActive(
      sheet: hero,
      state: state,
    );
    final hasFlinkFromVorteile = parsed.hasFlinkFromVorteile;
    final hasBehaebigFromNachteile = parsed.hasBehaebigFromNachteile;
    final isEditing = _editController.isEditing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ruleToggle(
          label: 'Kampfreflexe',
          value: rules.kampfreflexe,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(kampfreflexe: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Kampfgespür',
          value: rules.kampfgespuer,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(kampfgespuer: value),
            );
            _markFieldChanged();
          },
        ),
        _specialAbilityCard(
          title: 'Schnellziehen',
          value: rules.schnellziehen,
          isEditing: isEditing,
          isActive: rules.schnellziehen || axxeleratusActive,
          isTemporaryFromAxx: axxeleratusActive && !rules.schnellziehen,
          keyName: 'combat-special-rule-schnellziehen',
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(schnellziehen: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Ausweichen I',
          value: rules.ausweichenI,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(ausweichenI: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Ausweichen II',
          value: rules.ausweichenII,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(ausweichenII: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Ausweichen III',
          value: rules.ausweichenIII,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(ausweichenIII: value),
            );
            _markFieldChanged();
          },
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<int>(
              key: const ValueKey<String>('combat-armor-global-training-level'),
              initialValue: armor.globalArmorTrainingLevel,
              decoration: const InputDecoration(
                labelText: 'Rüstungsgewöhnung',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 0, child: SizedBox.shrink()),
                DropdownMenuItem(value: 1, child: Text('I')),
                DropdownMenuItem(value: 2, child: Text('II')),
                DropdownMenuItem(value: 3, child: Text('III')),
              ],
              onChanged: !isEditing
                  ? null
                  : (value) {
                      _draftCombatConfig = _draftCombatConfig.copyWith(
                        armor: _draftCombatConfig.armor.copyWith(
                          globalArmorTrainingLevel: value ?? 0,
                        ),
                      );
                      _markFieldChanged();
                    },
            ),
          ),
        ),
        _ruleToggle(
          label: 'Linkhand',
          value: rules.linkhandActive,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(linkhandActive: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Schildkampf I',
          value: rules.schildkampfI,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(schildkampfI: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Schildkampf II',
          value: rules.schildkampfII,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(schildkampfII: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Parierwaffen I',
          value: rules.parierwaffenI,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(parierwaffenI: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Parierwaffen II',
          value: rules.parierwaffenII,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(parierwaffenII: value),
            );
            _markFieldChanged();
          },
        ),
        Card(
          child: ListTile(
            title: const Text('Flink'),
            subtitle: Text(
              hasFlinkFromVorteile ? 'Aus Vorteile erkannt' : 'Nicht erkannt',
            ),
            trailing: Chip(
              label: Text(hasFlinkFromVorteile ? 'Aktiv' : 'Inaktiv'),
            ),
          ),
        ),
        Card(
          child: ListTile(
            title: const Text('Behäbig'),
            subtitle: Text(
              hasBehaebigFromNachteile
                  ? 'Aus Nachteile erkannt'
                  : 'Nicht erkannt',
            ),
            trailing: Chip(
              label: Text(hasBehaebigFromNachteile ? 'Aktiv' : 'Inaktiv'),
            ),
          ),
        ),
        _ruleToggle(
          label: 'Klingentänzer',
          value: rules.klingentaenzer,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(klingentaenzer: value),
            );
            _markFieldChanged();
          },
        ),
        _ruleToggle(
          label: 'Aufmerksamkeit',
          value: rules.aufmerksamkeit,
          isEditing: isEditing,
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(aufmerksamkeit: value),
            );
            _markFieldChanged();
          },
        ),
        ..._buildCatalogCombatSpecialAbilityCards(
          catalog: catalog,
          rules: rules,
          isEditing: isEditing,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Waffenmeister
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Manöver
  // ---------------------------------------------------------------------------

  Widget _buildManeuversSection(RulesCatalog catalog) {
    final rules = _draftCombatConfig.specialRules;
    final isEditing = _editController.isEditing;
    final groupedManeuvers = _groupCatalogManeuvers(catalog);
    final allManeuverIds = catalog.maneuvers
        .map((maneuver) => maneuver.id)
        .toList(growable: false);
    final supportByManeuver = _buildManeuverSupportMap(catalog, allManeuverIds);
    final activeManeuverIds = _effectiveActiveManeuverIds(catalog);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (catalog.maneuvers.isEmpty)
          const Card(
            child: ListTile(title: Text('Keine Manöver im Katalog gefunden.')),
          ),
        ..._buildManeuverGroupCards(
          title: 'Bewaffnete Manöver',
          maneuvers: groupedManeuvers['bewaffnet'] ?? const <ManeuverDef>[],
          rules: rules,
          activeManeuverIds: activeManeuverIds,
          isEditing: isEditing,
          supportByManeuver: supportByManeuver,
        ),
        ..._buildManeuverGroupCards(
          title: 'Waffenlose Manöver',
          maneuvers: groupedManeuvers['waffenlos'] ?? const <ManeuverDef>[],
          rules: rules,
          activeManeuverIds: activeManeuverIds,
          isEditing: isEditing,
          supportByManeuver: supportByManeuver,
        ),
        ..._buildFernkampfManeuverCards(
          catalog: catalog,
          rules: rules,
          activeManeuverIds: activeManeuverIds,
          isEditing: isEditing,
          supportByManeuver: supportByManeuver,
        ),
      ],
    );
  }

  /// Rendert alle Karten einer Manövergruppe.
  List<Widget> _buildManeuverGroupCards({
    required String title,
    required List<ManeuverDef> maneuvers,
    required CombatSpecialRules rules,
    required Set<String> activeManeuverIds,
    required bool isEditing,
    required Map<String, _ManeuverSupportStatus> supportByManeuver,
  }) {
    return <Widget>[
      Text(title, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      if (maneuvers.isEmpty)
        Card(
          child: ListTile(title: Text('Keine Einträge in „$title“ gefunden.')),
        ),
      ...maneuvers.map((maneuver) {
        final isActive = activeManeuverIds.contains(maneuver.id);
        final support =
            supportByManeuver[maneuver.id] ??
            _ManeuverSupportStatus.unverifiable;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(maneuver.name),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _buildManeuverMetaChips(
                          maneuverDef: maneuver,
                          isActive: isActive,
                          support: support,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Details',
                  onPressed: () => _showCombatManeuverDetailsDialog(
                    context: context,
                    maneuver: maneuver,
                  ),
                  icon: const Icon(Icons.info_outline),
                ),
                Switch(
                  value: isActive,
                  onChanged: !isEditing
                      ? null
                      : (value) {
                          final active = List<String>.from(
                            rules.activeManeuvers,
                          );
                          if (value) {
                            active.add(maneuver.id);
                          } else {
                            active.removeWhere((entry) => entry == maneuver.id);
                          }
                          _draftCombatConfig = _draftCombatConfig.copyWith(
                            specialRules: rules.copyWith(
                              activeManeuvers: active,
                            ),
                          );
                          _markFieldChanged();
                        },
                ),
              ],
            ),
          ),
        );
      }),
      const SizedBox(height: 12),
    ];
  }

  /// Rendert alle Fernkampf-Manöver. Per-Talent-Manöver (mussSeparatErlerntWerden)
  /// werden fuer jedes passende FK-Talent einzeln angezeigt.
  List<Widget> _buildFernkampfManeuverCards({
    required RulesCatalog catalog,
    required CombatSpecialRules rules,
    required Set<String> activeManeuverIds,
    required bool isEditing,
    required Map<String, _ManeuverSupportStatus> supportByManeuver,
  }) {
    final fernkampfManeuvers = catalog.maneuvers
        .where((m) => m.gruppe == 'fernkampf')
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (fernkampfManeuvers.isEmpty) return const <Widget>[];

    final fkTalents = catalog.talents
        .where((t) => t.type.toLowerCase() == 'fernkampf')
        .toList();

    final widgets = <Widget>[
      Text(
        'Fernkampf-Manöver',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 8),
    ];

    for (final maneuver in fernkampfManeuvers) {
      final support =
          supportByManeuver[maneuver.id] ?? _ManeuverSupportStatus.unverifiable;

      if (maneuver.mussSeparatErlerntWerden) {
        final applicableTalents = maneuver.nurFuerTalente.isEmpty
            ? fkTalents
            : fkTalents
                .where((t) => maneuver.nurFuerTalente.contains(t.id))
                .toList();
        for (final talent in applicableTalents) {
          final toggleId = '${maneuver.id}::${talent.id}';
          widgets.add(
            _buildFernkampfManeuverCard(
              maneuver: maneuver,
              toggleId: toggleId,
              displayName: '${maneuver.name} (${talent.name})',
              isActive: activeManeuverIds.contains(toggleId),
              support: support,
              rules: rules,
              isEditing: isEditing,
            ),
          );
        }
      } else {
        widgets.add(
          _buildFernkampfManeuverCard(
            maneuver: maneuver,
            toggleId: maneuver.id,
            displayName: maneuver.name,
            isActive: activeManeuverIds.contains(maneuver.id),
            support: support,
            rules: rules,
            isEditing: isEditing,
          ),
        );
      }
    }

    widgets.add(const SizedBox(height: 12));
    return widgets;
  }

  Widget _buildFernkampfManeuverCard({
    required ManeuverDef maneuver,
    required String toggleId,
    required String displayName,
    required bool isActive,
    required _ManeuverSupportStatus support,
    required CombatSpecialRules rules,
    required bool isEditing,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(displayName),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _buildManeuverMetaChips(
                      maneuverDef: maneuver,
                      isActive: isActive,
                      support: support,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Details',
              onPressed: () => _showCombatManeuverDetailsDialog(
                context: context,
                maneuver: maneuver,
              ),
              icon: const Icon(Icons.info_outline),
            ),
            Switch(
              value: isActive,
              onChanged: !isEditing
                  ? null
                  : (value) {
                      final active = List<String>.from(rules.activeManeuvers);
                      if (value) {
                        active.add(toggleId);
                      } else {
                        active.removeWhere((entry) => entry == toggleId);
                      }
                      _draftCombatConfig = _draftCombatConfig.copyWith(
                        specialRules: rules.copyWith(activeManeuvers: active),
                      );
                      _markFieldChanged();
                    },
            ),
          ],
        ),
      ),
    );
  }
}
