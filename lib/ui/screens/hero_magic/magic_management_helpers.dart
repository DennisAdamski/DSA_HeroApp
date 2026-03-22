part of '../hero_magic_tab.dart';

extension _MagicManagementHelpers on _HeroMagicTabState {
  Future<SpellAvailabilityEntry?> _chooseAvailabilityEntryForSpell(
    BuildContext context,
    SpellDef spell,
  ) async {
    final availableEntries = availableSpellEntriesForRepresentations(
      spell.availability,
      _draftRepresentationen,
    );
    if (availableEntries.isEmpty) {
      return null;
    }
    if (availableEntries.length == 1) {
      return availableEntries.single;
    }
    return _showSpellRepresentationDialog(
      context: context,
      spellName: spell.name,
      entries: availableEntries,
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

  void _updateMagicLeadAttribute(String value) {
    _draftMagicLeadAttribute = value;
    _markFieldChanged();
  }

  void _showZauberKatalog(BuildContext context, List<SpellDef> allSpells) {
    final localActiveIds = _draftSpells.keys.toSet();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
