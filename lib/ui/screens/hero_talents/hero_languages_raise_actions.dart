part of 'package:dsa_heldenverwaltung/ui/screens/hero_talents_tab.dart';

extension _HeroLanguagesRaiseActions on _HeroTalentTableTabState {
  bool get _canUseLanguageSteigerungsDialog {
    return _editController.isEditing && !_editController.isDirty;
  }

  SpracheDef? _findSpracheDef(String id, List<SpracheDef> alleSprachen) {
    for (final def in alleSprachen) {
      if (def.id == id) {
        return def;
      }
    }
    return null;
  }

  SchriftDef? _findSchriftDef(String id, List<SchriftDef> alleSchriften) {
    for (final def in alleSchriften) {
      if (def.id == id) {
        return def;
      }
    }
    return null;
  }

  Future<void> _steigereSprache(
    String id,
    List<SpracheDef> alleSprachen,
  ) async {
    final hero = _latestHero;
    if (hero == null || !_canUseLanguageSteigerungsDialog) {
      return;
    }
    final def = _findSpracheDef(id, alleSprachen);
    if (def == null) {
      return;
    }
    final kompl = _computeSprachKomplexitaet(
      def: def,
      muttersprache: _draftMuttersprache,
      alleSprachen: alleSprachen,
    );
    final learnCost = learnCostFromKomplexitaet(kompl);
    if (learnCost == null) {
      return;
    }
    final entry = _draftSprachen[id] ?? const HeroLanguageEntry();
    final result = await showSteigerungsDialog(
      context: context,
      bezeichnung: def.name,
      aktuellerWert: entry.wert ?? -1,
      maxWert: def.maxWert,
      effektiveKomplexitaet: learnCost,
      verfuegbareAp: hero.apAvailable,
      episch: hero.isEpisch,
    );
    if (result == null) {
      return;
    }
    final updatedSprachen = Map<String, HeroLanguageEntry>.from(
      _draftSprachen,
    )..[id] = entry.copyWith(wert: result.neuerWert);
    final updatedHero = hero.copyWith(
      sprachen: updatedSprachen,
      apSpent: hero.apSpent + result.apKosten,
    );
    await ref.read(heroActionsProvider).saveHero(updatedHero);
    _latestHero = updatedHero;
    _draftSprachen = updatedSprachen;
    if (!mounted) {
      return;
    }
    _tableRevision.value++;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${def.name} gesteigert')));
  }

  Future<void> _steigereSchrift(
    String id,
    List<SchriftDef> alleSchriften,
  ) async {
    final hero = _latestHero;
    if (hero == null || !_canUseLanguageSteigerungsDialog) {
      return;
    }
    final def = _findSchriftDef(id, alleSchriften);
    if (def == null) {
      return;
    }
    final learnCost = learnCostFromKomplexitaet(def.steigerung);
    if (learnCost == null) {
      return;
    }
    final entry = _draftSchriften[id] ?? const HeroScriptEntry();
    final result = await showSteigerungsDialog(
      context: context,
      bezeichnung: def.name,
      aktuellerWert: entry.wert ?? -1,
      maxWert: def.maxWert,
      effektiveKomplexitaet: learnCost,
      verfuegbareAp: hero.apAvailable,
      episch: hero.isEpisch,
    );
    if (result == null) {
      return;
    }
    final updatedSchriften = Map<String, HeroScriptEntry>.from(
      _draftSchriften,
    )..[id] = entry.copyWith(wert: result.neuerWert);
    final updatedHero = hero.copyWith(
      schriften: updatedSchriften,
      apSpent: hero.apSpent + result.apKosten,
    );
    await ref.read(heroActionsProvider).saveHero(updatedHero);
    _latestHero = updatedHero;
    _draftSchriften = updatedSchriften;
    if (!mounted) {
      return;
    }
    _tableRevision.value++;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${def.name} gesteigert')));
  }
}
