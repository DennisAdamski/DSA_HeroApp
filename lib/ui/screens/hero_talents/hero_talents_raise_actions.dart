part of 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';

extension _HeroTalentsRaiseActions on _HeroTalentTableTabState {
  void _setCellControllerText(String talentId, String field, String value) {
    final controller = _cellControllers[_controllerKey(talentId, field)];
    if (controller == null || controller.text == value) {
      return;
    }
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  bool get _canUseSteigerungsDialog {
    return _editController.isEditing && !_editController.isDirty;
  }

  TalentDef? _findTalentDefById(String talentId) {
    for (final talent in _latestCatalogTalents) {
      if (talent.id == talentId) {
        return talent;
      }
    }
    return null;
  }

  /// Leitet den Talent-Maximalwert aus Probeigenschaften bzw. Kampftalent-Regeln ab.
  int _maxWertFuerTalent(TalentDef talent, HeroTalentEntry entry) {
    final hero = _latestHero;
    if (hero == null) {
      return entry.gifted ? 5 : 3;
    }
    final effectiveAttributes = computeEffectiveAttributes(hero);
    if (isCombatTalentDef(talent)) {
      return computeCombatTalentMaxValue(
        effectiveAttributes: effectiveAttributes,
        talentType: talent.type,
        gifted: entry.gifted,
      );
    }
    return computeTalentMaxValue(
      effectiveAttributes: effectiveAttributes,
      attributeNames: talent.attributes,
      gifted: entry.gifted,
    );
  }

  Future<void> _steigereTalent(String talentId) async {
    final hero = _latestHero;
    if (hero == null || !_canUseSteigerungsDialog) {
      return;
    }

    final talent = _findTalentDefById(talentId);
    if (talent == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Talentdefinition fehlt.')));
      return;
    }

    final entry = _entryForTalent(talentId);
    final maxWert = _maxWertFuerTalent(talent, entry);
    final complexityResolution = _resolveTalentComplexity(talent, entry);
    final learnCost = learnCostFromKomplexitaet(
      complexityResolution.effectiveKomplexitaet,
    );
    if (learnCost == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unbekannte Lernkomplexität für ${talent.name}: '
            '${complexityResolution.effectiveKomplexitaet}',
          ),
        ),
      );
      return;
    }

    final result = await showSteigerungsDialog(
      context: context,
      bezeichnung: talent.name,
      aktuellerWert: entry.talentValue ?? -1,
      maxWert: maxWert,
      effektiveKomplexitaet: learnCost,
      komplexitaetsHinweis: complexityResolution.houseRuleHint,
      verfuegbareAp: hero.apAvailable,
      seAnzahl: entry.specialExperiences,
      lehrmeisterVerfuegbar: true,
    );
    if (result == null) {
      return;
    }

    final remainingSe = entry.specialExperiences - result.seVerbraucht;
    final normalizedSe = remainingSe < 0 ? 0 : remainingSe;
    final updatedEntry = entry.copyWith(
      talentValue: result.neuerWert,
      specialExperiences: normalizedSe,
    );
    final updatedTalents = activateReferencedMetaTalentComponents(
      talents: <String, HeroTalentEntry>{
        ..._draftTalents,
        talentId: updatedEntry,
      },
      metaTalents: _draftMetaTalents,
    );
    final updatedHero = hero.copyWith(
      talents: updatedTalents,
      metaTalents: List<HeroMetaTalent>.from(_draftMetaTalents),
      apSpent: hero.apSpent + result.apKosten,
    );

    await ref.read(heroActionsProvider).saveHero(updatedHero);
    _latestHero = updatedHero;
    _draftTalents = updatedTalents;
    _setCellControllerText(
      talentId,
      'talentValue',
      result.neuerWert.toString(),
    );
    _setCellControllerText(
      talentId,
      'specialExperiences',
      normalizedSe.toString(),
    );
    if (!mounted) {
      return;
    }
    _tableRevision.value++;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${talent.name} gesteigert')));
  }
}
