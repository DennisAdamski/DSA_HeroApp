part of 'package:dsa_heldenverwaltung/ui/screens/hero_overview_tab.dart';

extension _HeroOverviewRaiseActions on _HeroOverviewTabState {
  bool get _canUseSteigerungsDialog {
    return _editController.isEditing && !_editController.isDirty;
  }

  String _attributeLabel(AttributeCode code) {
    return switch (code) {
      AttributeCode.mu => 'Mut',
      AttributeCode.kl => 'Klugheit',
      AttributeCode.inn => 'Intuition',
      AttributeCode.ch => 'Charisma',
      AttributeCode.ff => 'Fingerfertigkeit',
      AttributeCode.ge => 'Gewandtheit',
      AttributeCode.ko => 'Konstitution',
      AttributeCode.kk => 'Körperkraft',
    };
  }

  Attributes _attributesWithRaisedValue(
    Attributes attributes,
    AttributeCode code,
    int value,
  ) {
    return switch (code) {
      AttributeCode.mu => attributes.copyWith(mu: value),
      AttributeCode.kl => attributes.copyWith(kl: value),
      AttributeCode.inn => attributes.copyWith(inn: value),
      AttributeCode.ch => attributes.copyWith(ch: value),
      AttributeCode.ff => attributes.copyWith(ff: value),
      AttributeCode.ge => attributes.copyWith(ge: value),
      AttributeCode.ko => attributes.copyWith(ko: value),
      AttributeCode.kk => attributes.copyWith(kk: value),
    };
  }

  String _grundwertLabel(String key) {
    return switch (key) {
      'lep' => 'LeP',
      'au' => 'Au',
      'asp' => 'AsP',
      'kap' => 'KaP',
      'mr' => 'MR',
      _ => key.toUpperCase(),
    };
  }

  int _grundwertValue(BoughtStats bought, String key) {
    return switch (key) {
      'lep' => bought.lep,
      'au' => bought.au,
      'asp' => bought.asp,
      'kap' => bought.kap,
      'mr' => bought.mr,
      _ => 0,
    };
  }

  BoughtStats _boughtWithRaisedValue(
    BoughtStats bought,
    String key,
    int value,
  ) {
    return switch (key) {
      'lep' => bought.copyWith(lep: value),
      'au' => bought.copyWith(au: value),
      'asp' => bought.copyWith(asp: value),
      'kap' => bought.copyWith(kap: value),
      'mr' => bought.copyWith(mr: value),
      _ => bought,
    };
  }

  int _eigenschaftMaxWert(HeroSheet hero, AttributeCode code) {
    final originModifiers = parseOriginAttributeModifiers(hero);
    final effectiveStartAttributes = computeEffectiveStartAttributes(
      hero.startAttributes,
      originModifiers,
    );
    final attributeMaximums = computeAttributeMaximums(
      effectiveStartAttributes,
    );
    return readAttributeValue(attributeMaximums, code);
  }

  int _eigenschaftSeAnzahl(HeroSheet hero, AttributeCode code) {
    return hero.attributeSePool.valueFor(code);
  }

  HeroAttributeSePool _attributeSePoolAfterConsumption({
    required HeroSheet hero,
    required AttributeCode code,
    required int usedSe,
  }) {
    if (usedSe <= 0) {
      return hero.attributeSePool;
    }
    return hero.attributeSePool.adjust(code, -usedSe);
  }

  /// Nutzt bis zu einer modellierten Fachregel die mit den aktuellen AP erreichbare Obergrenze.
  int _grundwertMaxWert({
    required int aktuellerWert,
    required LearnCost learnCost,
    required int verfuegbareAp,
  }) {
    var maxWert = aktuellerWert;
    var restAp = verfuegbareAp;
    while (true) {
      final int kostenFuerNaechstenSchritt = learnCost.costForStep(maxWert);
      if (kostenFuerNaechstenSchritt > restAp) {
        return maxWert;
      }
      restAp -= kostenFuerNaechstenSchritt;
      maxWert++;
    }
  }

  int _grundwertSeAnzahl(HeroSheet hero, String key) {
    return hero.statSePool.valueFor(key);
  }

  HeroStatSePool _statSePoolAfterConsumption({
    required HeroSheet hero,
    required String key,
    required int usedSe,
  }) {
    if (usedSe <= 0) {
      return hero.statSePool;
    }
    return hero.statSePool.adjust(key, -usedSe);
  }

  Future<void> _steigeEigenschaft(AttributeCode code) async {
    final hero = _latestHero;
    if (hero == null || !_canUseSteigerungsDialog) {
      return;
    }

    final aktuellerWert = readAttributeValue(hero.attributes, code);
    final maxWert = _eigenschaftMaxWert(hero, code);
    final result = await showSteigerungsDialog(
      context: context,
      bezeichnung: _attributeLabel(code),
      aktuellerWert: aktuellerWert,
      maxWert: maxWert,
      effektiveKomplexitaet: kEigenschaftKomplexitaet,
      verfuegbareAp: hero.apAvailable,
      seAnzahl: _eigenschaftSeAnzahl(hero, code),
    );
    if (result == null) {
      return;
    }

    final updatedHero = hero.copyWith(
      attributes: _attributesWithRaisedValue(
        hero.attributes,
        code,
        result.neuerWert,
      ),
      attributeSePool: _attributeSePoolAfterConsumption(
        hero: hero,
        code: code,
        usedSe: result.seVerbraucht,
      ),
      apSpent: hero.apSpent + result.apKosten,
    );
    await ref.read(heroActionsProvider).saveHero(updatedHero);
    _latestHero = updatedHero;
    _setFieldText(code.name, result.neuerWert.toString());
    if (!mounted) {
      return;
    }
    _viewRevision.value++;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_attributeLabel(code)} gesteigert')),
    );
  }

  Future<void> _steigeGrundwert(String key) async {
    final hero = _latestHero;
    if (hero == null || !_canUseSteigerungsDialog) {
      return;
    }

    final learnCost = kGrundwertKomplexitaeten[key];
    if (learnCost == null) {
      return;
    }
    final aktuellerWert = _grundwertValue(hero.bought, key);
    final maxWert = _grundwertMaxWert(
      aktuellerWert: aktuellerWert,
      learnCost: learnCost,
      verfuegbareAp: hero.apAvailable,
    );

    final result = await showSteigerungsDialog(
      context: context,
      bezeichnung: _grundwertLabel(key),
      aktuellerWert: aktuellerWert,
      maxWert: maxWert,
      effektiveKomplexitaet: learnCost,
      verfuegbareAp: hero.apAvailable,
      seAnzahl: _grundwertSeAnzahl(hero, key),
    );
    if (result == null) {
      return;
    }

    final updatedHero = hero.copyWith(
      bought: _boughtWithRaisedValue(hero.bought, key, result.neuerWert),
      statSePool: _statSePoolAfterConsumption(
        hero: hero,
        key: key,
        usedSe: result.seVerbraucht,
      ),
      apSpent: hero.apSpent + result.apKosten,
    );
    await ref.read(heroActionsProvider).saveHero(updatedHero);
    _latestHero = updatedHero;
    _setFieldText('b_$key', result.neuerWert.toString());
    if (!mounted) {
      return;
    }
    _viewRevision.value++;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_grundwertLabel(key)} gesteigert')),
    );
  }
}
