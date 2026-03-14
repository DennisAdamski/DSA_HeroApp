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
    final effektiveKomplexitaet = effectiveTalentLernkomplexitaet(
      basisKomplexitaet: talent.steigerung,
      gifted: entry.gifted,
    );
    final learnCost = learnCostFromKomplexitaet(effektiveKomplexitaet);
    if (learnCost == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unbekannte Lernkomplexität für ${talent.name}: $effektiveKomplexitaet',
          ),
        ),
      );
      return;
    }

    final result = await showSteigerungsDialog(
      context: context,
      bezeichnung: talent.name,
      aktuellerWert: entry.talentValue ?? -1,
      effektiveKomplexitaet: learnCost,
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
