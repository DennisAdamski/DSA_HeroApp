part of 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';

extension _HeroTalentMutations on _HeroTalentTableTabState {
  HeroTalentEntry _entryForTalent(String talentId) {
    return _draftTalents[talentId] ?? const HeroTalentEntry();
  }

  TalentComplexityResolution _resolveTalentComplexity(
    TalentDef talent,
    HeroTalentEntry entry,
  ) {
    return _latestCatalogRuleResolver.resolveTalentComplexity(
      talent: talent,
      gifted: entry.gifted,
    );
  }

  void _updateIntField(String talentId, String field, String raw) {
    final parsed = int.tryParse(raw.trim()) ?? 0;
    final current = _entryForTalent(talentId);
    final updated = switch (field) {
      'talentValue' => current.copyWith(talentValue: parsed),
      'atValue' => current.copyWith(atValue: parsed),
      'paValue' => current.copyWith(paValue: parsed),
      'specialExperiences' => current.copyWith(specialExperiences: parsed),
      _ => current,
    };
    _draftTalents[talentId] = updated;
    _invalidCombatTalentIds.remove(talentId);
    _markFieldChanged();
  }

  void _updateTalentModifiers(
    String talentId,
    List<HeroTalentModifier> talentModifiers,
  ) {
    final current = _entryForTalent(talentId);
    _draftTalents[talentId] = current.copyWith(
      modifier: 0,
      talentModifiers: talentModifiers,
    );
    _invalidCombatTalentIds.remove(talentId);
    _markFieldChanged();
  }

  void _updateSpecializations(String talentId, List<String> values) {
    final current = _entryForTalent(talentId);
    final normalized = _normalizeStringList(values);
    _draftTalents[talentId] = current.copyWith(
      combatSpecializations: normalized,
      specializations: normalized.join(', '),
    );
    _markFieldChanged();
  }

  void _updateGifted(String talentId, bool value) {
    final current = _entryForTalent(talentId);
    _draftTalents[talentId] = current.copyWith(gifted: value);
    _markFieldChanged();
  }

  void _updateCombatSpecializations(String talentId, List<String> values) {
    final current = _entryForTalent(talentId);
    final normalized = _normalizeStringList(values);
    _draftTalents[talentId] = current.copyWith(
      combatSpecializations: normalized,
      specializations: normalized.join(', '),
    );
    _markFieldChanged();
  }

  void _toggleTalent(String talentId, bool activate) {
    final lockedTalentIds = collectMetaTalentComponentIds(_draftMetaTalents);
    if (!activate && lockedTalentIds.contains(talentId)) {
      return;
    }
    if (activate) {
      _draftTalents.putIfAbsent(talentId, () => const HeroTalentEntry());
    } else {
      _draftTalents.remove(talentId);
      // Entferne zugehoerige Controller.
      _cellControllers.remove('$talentId::talentValue')?.dispose();
      _cellControllers.remove('$talentId::specialExperiences')?.dispose();
      _cellControllers.remove('$talentId::atValue')?.dispose();
      _cellControllers.remove('$talentId::paValue')?.dispose();
      _cellControllers.remove('$talentId::specializations')?.dispose();
    }
    _markFieldChanged();
  }
}
