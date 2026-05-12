// ignore_for_file: invalid_use_of_protected_member

part of 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';

extension _HeroTalentEditActions on _HeroTalentTableTabState {
  void _registerWithParent() {
    _editController.emitCurrentState();
    widget.onRegisterDiscard(_discardChanges);
    widget.onRegisterEditActions(
      WorkspaceTabEditActions(
        startEdit: _startEdit,
        save: _saveChanges,
        cancel: _cancelChanges,
        headerActions: const <WorkspaceHeaderAction>[],
      ),
    );
  }

  void _syncDraftFromHero(HeroSheet hero, {bool force = false}) {
    if (!_editController.shouldSync(hero, force: force)) {
      return;
    }
    _resetCellControllers();
    _draftMetaTalents = List<HeroMetaTalent>.from(hero.metaTalents);
    _draftTalents = activateReferencedMetaTalentComponents(
      talents: hero.talents,
      metaTalents: _draftMetaTalents,
    );
    _draftTalentSpecialAbilities = List<TalentSpecialAbility>.from(
      hero.talentSpecialAbilities,
    );
    _invalidCombatTalentIds = <String>{};
    _draftSprachen = Map<String, HeroLanguageEntry>.from(hero.sprachen);
    _draftSchriften = Map<String, HeroScriptEntry>.from(hero.schriften);
    _draftMuttersprache = hero.muttersprache;
  }

  void _resetCellControllers() {
    for (final controller in _cellControllers.values) {
      controller.dispose();
    }
    _cellControllers.clear();
  }

  TextEditingController _controllerFor(
    String talentId,
    String field,
    String initialValue,
  ) {
    final key = _controllerKey(talentId, field);
    return _cellControllers.putIfAbsent(
      key,
      () => TextEditingController(text: initialValue),
    );
  }

  String _controllerKey(String talentId, String field) {
    return '$talentId::$field';
  }

  Future<void> _startEdit() async {
    final hero = _latestHero;
    if (hero == null) {
      return;
    }
    _editController.clearSyncSignature();
    _syncDraftFromHero(hero, force: true);
    _invalidCombatTalentIds = <String>{};
    _editController.startEdit();
  }

  Future<void> _saveChanges() async {
    final hero = _latestHero;
    if (hero == null) {
      return;
    }
    if (widget.scope == _TalentTabScope.combat) {
      final catalog = await ref.read(rulesCatalogProvider.future);
      final issues = validateCombatTalentDistribution(
        talents: catalog.talents,
        talentEntries: _draftTalents,
        filter: _matchesScope,
      );
      if (issues.isNotEmpty) {
        if (mounted) {
          setState(() {
            _invalidCombatTalentIds = issues
                .map((entry) => entry.talentId)
                .toSet();
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(issues.first.message)));
        }
        return;
      }
      _invalidCombatTalentIds = <String>{};
    }
    final updatedHero = hero.copyWith(
      talents: activateReferencedMetaTalentComponents(
        talents: _draftTalents,
        metaTalents: _draftMetaTalents,
      ),
      metaTalents: List<HeroMetaTalent>.from(_draftMetaTalents),
      talentSpecialAbilities: List<TalentSpecialAbility>.from(
        _draftTalentSpecialAbilities,
      ),
      sprachen: Map<String, HeroLanguageEntry>.unmodifiable(_draftSprachen),
      schriften: Map<String, HeroScriptEntry>.unmodifiable(_draftSchriften),
      muttersprache: _draftMuttersprache,
    );
    await ref.read(heroActionsProvider).saveHero(updatedHero);
    if (!mounted) {
      return;
    }
    _editController.markSaved();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Talente gespeichert')));
  }

  Future<void> _cancelChanges() async {
    await _discardChanges();
  }

  Future<void> _discardChanges() async {
    final hero = _latestHero;
    if (hero != null) {
      _editController.clearSyncSignature();
      _syncDraftFromHero(hero, force: true);
    }
    _invalidCombatTalentIds = <String>{};
    _editController.markDiscarded();
  }

  void _replaceMetaTalents(List<HeroMetaTalent> metaTalents) {
    _draftMetaTalents = List<HeroMetaTalent>.unmodifiable(metaTalents);
    _draftTalents = activateReferencedMetaTalentComponents(
      talents: _draftTalents,
      metaTalents: _draftMetaTalents,
    );
    _markFieldChanged();
  }

  void _markFieldChanged() {
    if (!mounted) {
      return;
    }
    _tableRevision.value++;
    _editController.markFieldChanged();
  }

  Future<void> _ensureEditingSession() async {
    if (_editController.isEditing) {
      return;
    }
    await _startEdit();
  }

  Future<void> _openTalentCatalogAction(List<TalentDef> allTalents) async {
    await _ensureEditingSession();
    if (!mounted) {
      return;
    }
    _showTalentKatalog(context, allTalents);
  }

  Future<void> _openMetaTalentManagerAction(
    List<TalentDef> allCatalogTalents,
  ) async {
    await _ensureEditingSession();
    if (!mounted) {
      return;
    }
    await _openMetaTalentManager(allCatalogTalents);
  }

  void _showTalentKatalog(BuildContext context, List<TalentDef> allTalents) {
    final localActiveIds = _draftTalents.keys.toSet();
    final lockedTalentIds = collectMetaTalentComponentIds(_draftMetaTalents);
    final screenWidth = MediaQuery.of(context).size.width;
    final sheetWidth = _talentCatalogSheetMinWidth.clamp(0.0, screenWidth);
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
                    child: _TalentCatalogTable(
                      allTalents: allTalents,
                      activeTalentIds: localActiveIds,
                      lockedTalentIds: lockedTalentIds,
                      ruleResolver: _latestCatalogRuleResolver,
                      onToggleTalent: (id, activate) {
                        _toggleTalent(id, activate);
                        setSheetState(() {
                          if (activate) {
                            localActiveIds.add(id);
                          } else {
                            localActiveIds.remove(id);
                          }
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
