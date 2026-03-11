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
                child: _buildSpecialRulesSection(hero, heroState),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildCombatMasteriesSection(
          hero: hero,
          heroState: heroState,
          catalog: catalog,
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

  Widget _buildSpecialRulesSection(HeroSheet hero, HeroState state) {
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
        _specialAbilityCard(
          title: 'Schnellladen (Bogen)',
          value: rules.schnellladenBogen,
          isEditing: isEditing,
          isActive: rules.schnellladenBogen || axxeleratusActive,
          isTemporaryFromAxx: axxeleratusActive && !rules.schnellladenBogen,
          keyName: 'combat-special-rule-schnellladen-bogen',
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(schnellladenBogen: value),
            );
            _markFieldChanged();
          },
        ),
        _specialAbilityCard(
          title: 'Schnellladen (Armbrust)',
          value: rules.schnellladenArmbrust,
          isEditing: isEditing,
          isActive: rules.schnellladenArmbrust || axxeleratusActive,
          isTemporaryFromAxx: axxeleratusActive && !rules.schnellladenArmbrust,
          keyName: 'combat-special-rule-schnellladen-armbrust',
          onChanged: (value) {
            _draftCombatConfig = _draftCombatConfig.copyWith(
              specialRules: rules.copyWith(schnellladenArmbrust: value),
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
      ],
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
          isEditing: isEditing,
          supportByManeuver: supportByManeuver,
        ),
        ..._buildManeuverGroupCards(
          title: 'Waffenlose Manöver',
          maneuvers: groupedManeuvers['waffenlos'] ?? const <ManeuverDef>[],
          rules: rules,
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
        final isActive = rules.activeManeuvers.contains(maneuver.id);
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
}
