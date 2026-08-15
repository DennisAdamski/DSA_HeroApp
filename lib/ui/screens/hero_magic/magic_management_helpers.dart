part of '../hero_magic_tab.dart';

extension _MagicManagementHelpers on _HeroMagicTabState {
  Future<SpellAvailabilityEntry?> _chooseAvailabilityEntryForSpell(
    BuildContext context,
    SpellDef spell,
  ) async {
    final options = allLearningOptionsForHero(
      spell.availability,
      _draftRepresentationen,
    );
    if (options.isEmpty) {
      return null;
    }
    if (options.length == 1) {
      return options.single;
    }
    return _showSpellRepresentationDialog(
      context: context,
      spellName: spell.name,
      entries: options,
      baseLernkomplexitaet: spell.steigerung,
      zauberMerkmale: parseSpellTraits(spell.traits),
      heldMerkmalskenntnisse: _draftMerkmalskenntnisse,
    );
  }

  Future<bool> _activateSpell(BuildContext context, SpellDef spell) async {
    final chosenEntry = await _chooseAvailabilityEntryForSpell(context, spell);
    if (chosenEntry == null) {
      return false;
    }
    final current = _draftSpells[spell.id] ?? const HeroSpellEntry();
    _draftSpells[spell.id] = current.copyWith(
      learnedRepresentation: chosenEntry.learnedRepresentation,
      learnedTradition: chosenEntry.tradition,
    );
    _markFieldChanged();
    return true;
  }

  void _deactivateSpell(String spellId) {
    _draftSpells.remove(spellId);
    _cellControllers.remove('$spellId::spellValue')?.dispose();
    _cellControllers.remove('$spellId::modifier')?.dispose();
    _markFieldChanged();
  }

  void _removeSpell(String spellId) {
    _deactivateSpell(spellId);
  }

  void _updateRepresentationen(List<String> values) {
    _draftRepresentationen = values;
    _markFieldChanged();
  }

  void _updateRepraesentationsTraditionen(Map<String, String> values) {
    _draftRepraesentationsTraditionen = values;
    _markFieldChanged();
  }

  /// Baut den Pruefkontext fuer Erwerbsvoraussetzungen aus dem Draft-Zustand.
  ///
  /// Bewusst aus dem Draft und nicht aus dem gespeicherten Helden: Wer gerade
  /// eine Repraesentation aktiviert oder eine Sonderfertigkeit erworben hat,
  /// soll die Folgen sofort in den Checklisten sehen, ohne erst zu speichern.
  HeroRequirementContext _buildRequirementContext(
    HeroSheet hero,
    RulesCatalog catalog,
  ) {
    return buildHeroRequirementContext(
      hero.copyWith(
        spells: Map<String, HeroSpellEntry>.from(_draftSpells),
        ritualCategories: List<HeroRitualCategory>.from(_draftRitualCategories),
        representationen: List<String>.from(_draftRepresentationen),
        repraesentationsTraditionen: Map<String, String>.from(
          _draftRepraesentationsTraditionen,
        ),
        merkmalskenntnisse: List<String>.from(_draftMerkmalskenntnisse),
        magicSpecialAbilities: List<MagicSpecialAbility>.from(
          _draftMagicSpecialAbilities,
        ),
        magicLeadAttribute: _draftMagicLeadAttribute,
      ),
      catalog: catalog,
    );
  }

  void _updateRitualCategories(List<HeroRitualCategory> values) {
    _draftRitualCategories = values;
    _markFieldChanged();
  }

  void _updateMerkmalskenntnisse(List<String> values) {
    _draftMerkmalskenntnisse = values;
    _markFieldChanged();
  }

  void _updateMagicSpecialAbilities(List<MagicSpecialAbility> values) {
    _draftMagicSpecialAbilities = values;
    _markFieldChanged();
  }

  void _onMagicSpecialAbilityApKosten(int apKosten) {
    if (apKosten <= 0) {
      return;
    }
    _draftApSpentDelta += apKosten;
    _markFieldChanged();
  }

  void _updateMagicLeadAttribute(String value) {
    _draftMagicLeadAttribute = value;
    _markFieldChanged();
  }

  void _showZauberKatalog(BuildContext context, List<SpellDef> allSpells) {
    final localActiveIds = _draftSpells.keys.toSet();
    final screenWidth = MediaQuery.of(context).size.width;
    final sheetWidth = _magicSpellCatalogSheetMinWidth.clamp(0.0, screenWidth);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints.tightFor(width: sheetWidth),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final screenHeight = MediaQuery.of(ctx).size.height;
            return SizedBox(
              height: screenHeight * 0.8,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _MagicSpellCatalogTable(
                      allSpells: allSpells,
                      activeSpellIds: localActiveIds,
                      heroRepresentationen: _draftRepresentationen,
                      onActivateSpell: (spell) async {
                        final activated = await _activateSpell(ctx, spell);
                        if (!activated) {
                          return false;
                        }
                        setSheetState(() {
                          localActiveIds.add(spell.id);
                        });
                        return true;
                      },
                      onDeactivateSpell: (spellId) {
                        _deactivateSpell(spellId);
                        setSheetState(() {
                          localActiveIds.remove(spellId);
                        });
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
