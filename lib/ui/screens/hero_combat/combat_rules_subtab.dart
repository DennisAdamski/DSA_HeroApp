part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

/// Kampfregeln-Subtab: Sonderfertigkeiten und Manoever zusammengefasst.
extension _CombatRulesSubtab on _HeroCombatTabState {
  Widget _buildCombatRulesSubTab({
    required HeroSheet hero,
    required HeroState heroState,
    required RulesCatalog catalog,
  }) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Obere Sektion: Sonderfertigkeiten
        _buildSpecialRulesSection(hero, heroState),
        const Divider(height: 32),
        _buildCombatMasteriesSection(
          hero: hero,
          heroState: heroState,
          catalog: catalog,
        ),
        const Divider(height: 32),
        // Untere Sektion: Manoever
        _buildManeuversSection(catalog),
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
        Text(
          'Sonderfertigkeiten',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
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
              key: const ValueKey<String>(
                'combat-armor-global-training-level',
              ),
              initialValue: armor.globalArmorTrainingLevel,
              decoration: const InputDecoration(
                labelText: 'Ruestungsgewoehnung',
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
  // Manoever
  // ---------------------------------------------------------------------------

  Widget _buildManeuversSection(RulesCatalog catalog) {
    final rules = _draftCombatConfig.specialRules;
    final isEditing = _editController.isEditing;
    final allManeuvers = _collectCatalogManeuvers(catalog.weapons);
    final supportByManeuver = _buildManeuverSupportMap(catalog, allManeuvers);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Manöver', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (allManeuvers.isEmpty)
          const Card(
            child: ListTile(
              title: Text('Keine Manoever im Katalog gefunden.'),
            ),
          ),
        ...allManeuvers.map((maneuver) {
          final isActive = rules.activeManeuvers.contains(maneuver);
          final support =
              supportByManeuver[maneuver] ??
              _ManeuverSupportStatus.unverifiable;
          final maneuverDef = catalog.maneuverByName(maneuver);
          final erschwernis =
              maneuverDef != null && maneuverDef.erschwernis.isNotEmpty
              ? maneuverDef.erschwernis
              : null;
          final seite = maneuverDef != null && maneuverDef.seite.isNotEmpty
              ? maneuverDef.seite
              : null;
          return Card(
            child: SwitchListTile(
              title: Text(maneuver),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(isActive ? 'Aktiv' : 'Inaktiv')),
                    Chip(
                      label: Text(switch (support) {
                        _ManeuverSupportStatus.supported =>
                          'Von aktiver Waffe unterstützt',
                        _ManeuverSupportStatus.notSupported =>
                          'Nicht unterstützt',
                        _ManeuverSupportStatus.unverifiable =>
                          'Nicht verifizierbar',
                      }),
                    ),
                    if (erschwernis != null)
                      Chip(label: Text('Erschwernis: $erschwernis')),
                    if (seite != null) Chip(label: Text('S. $seite')),
                    if (support == _ManeuverSupportStatus.unverifiable)
                      const Text(
                        'Waffenabgleich nicht verifizierbar.',
                        style: TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),
              value: isActive,
              onChanged: !isEditing
                  ? null
                  : (value) {
                      final active = List<String>.from(rules.activeManeuvers);
                      if (value) {
                        active.add(maneuver);
                      } else {
                        active.removeWhere((entry) => entry == maneuver);
                      }
                      _draftCombatConfig = _draftCombatConfig.copyWith(
                        specialRules: rules.copyWith(activeManeuvers: active),
                      );
                      _markFieldChanged();
                    },
            ),
          );
        }),
      ],
    );
  }
}
