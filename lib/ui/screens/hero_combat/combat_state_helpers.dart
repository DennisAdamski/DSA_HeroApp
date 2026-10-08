part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

/// Entkoppelt Draft-State, Persistenz und Validierung vom Tab-Root.
extension _CombatStateHelpers on _HeroCombatTabState {
  /// Einziger Schreibweg der Bedienelemente im Kampf-Tab.
  ///
  /// Im Bearbeitungsmodus ändert [aenderung] nur den Entwurf; gespeichert
  /// wird mit „Speichern“. Sonst trifft sie frisch die **gespeicherte**
  /// Kampfkonfiguration (ARCH-05): Ein beim Rendern erfasster Stand wird nie
  /// zurückgeschrieben, Änderungen desselben Helden laufen nacheinander, und
  /// die Anzeige folgt dem gespeicherten Wert. Die Slotprüfung
  /// (`neuerKampfSlotFehler`) weist nur Fehler ab, die die Änderung neu
  /// einführt. Fehler erscheinen als „[was] nicht gespeichert“;
  /// die Bedienelemente springen dann auf den gespeicherten Stand zurück.
  /// Liefert, ob die Änderung übernommen wurde.
  Future<bool> _aendereKampf({
    required String was,
    required CombatConfig Function(CombatConfig aktuell) aenderung,
    required RulesCatalog catalog,
  }) {
    return _aendereKampfUndInventar(
      was: was,
      aenderung: (held) => mitKampfAenderung(held, aenderung),
      catalog: catalog,
    );
  }

  /// Wie [_aendereKampf], für Änderungen, die Kampf **und** Inventar
  /// treffen, etwa das Ablegen eines Gegenstands (ARCH-03).
  ///
  /// Im Bearbeitungsmodus wirkt [aenderung] auf den Entwurf: die
  /// Kampfkonfiguration und, falls sie sich ändern, die Inventareinträge
  /// ([_draftInventar]); „Speichern“ übernimmt beide gemeinsam.
  Future<bool> _aendereKampfUndInventar({
    required String was,
    required HeroSheet Function(HeroSheet aktuell) aenderung,
    required RulesCatalog catalog,
  }) async {
    if (_editController.isEditing) {
      return _aendereKampfEntwurf(was: was, aenderung: aenderung);
    }
    final gespeichert = await aendereHeldMitMeldung(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      was: was,
      aenderung: (held) {
        final neu = aenderung(held);
        if (identical(neu, held)) {
          return held;
        }
        // Nur neue Fehler sperren: Eine schon gespeicherte ungültige
        // Konfiguration darf die übrige Bedienung nicht blockieren.
        final fehler = neuerKampfSlotFehler(
          vorher: held.combatConfig,
          nachher: neu.combatConfig,
          catalog: catalog,
        );
        if (fehler != null) {
          throw StateError(fehler.meldung);
        }
        return neu;
      },
    );
    if (gespeichert == null && mounted) {
      _steuerRevision++;
      _viewRevision.value++;
    }
    return gespeichert != null;
  }

  // Wendet [aenderung] im Bearbeitungsmodus auf den Entwurf an.
  bool _aendereKampfEntwurf({
    required String was,
    required HeroSheet Function(HeroSheet aktuell) aenderung,
  }) {
    final basis = _entwurfBasis;
    if (basis == null) {
      return false;
    }
    final inventar = _draftInventar ?? basis.inventoryEntries;
    final entwurf = basis.copyWith(
      combatConfig: _draftCombatConfig,
      inventoryEntries: inventar,
    );
    final HeroSheet neu;
    try {
      neu = aenderung(entwurf);
    } on StateError catch (fehler) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('$was nicht übernommen: ${fehler.message}')),
      );
      return false;
    }
    _draftCombatConfig = neu.combatConfig;
    if (!identical(neu.inventoryEntries, inventar)) {
      _draftInventar = neu.inventoryEntries;
    }
    _markFieldChanged();
    return true;
  }

  Future<void> _startEdit() async {
    final darfBearbeiten = await bestaetigeBearbeitungBeiPlanung(
      context: context,
      heroId: widget.heroId,
    );
    if (!darfBearbeiten || !mounted) {
      return;
    }
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
    final basis = _entwurfBasis;
    if (basis == null) {
      return;
    }

    final catalog = await ref.read(rulesCatalogProvider.future);
    final weaponValidation = pruefeKampfSlots(
      config: _draftCombatConfig,
      catalog: catalog,
    ).firstOrNull?.meldung;
    if (weaponValidation != null) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(weaponValidation)));
      }
      return;
    }
    final issues = validateCombatTalentDistribution(
      talents: catalog.talents,
      talentEntries: _draftTalents,
      filter: isCombatTalentDef,
    );
    if (issues.isNotEmpty) {
      if (mounted) {
        _setInvalidCombatTalentIds(
          issues.map((entry) => entry.talentId).toSet(),
        );
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(issues.first.message)));
      }
      return;
    }

    final entwurf = basis.copyWith(
      talents: Map<String, HeroTalentEntry>.from(_draftTalents),
      combatConfig: _draftCombatConfig,
      inventoryEntries: _draftInventar ?? basis.inventoryEntries,
      apSpent: basis.apSpent + _draftApSpentDelta,
    );
    if (!mounted) {
      return;
    }
    final gespeichert = await speichereEditorEntwurf(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      abgleich: (aktuell, erzwungen) => uebernimmEditorEntwurf(
        basis: basis,
        entwurf: entwurf,
        aktuell: aktuell,
        erzwungen: erzwungen,
        neueId: neueEditorSlotId,
      ),
    );
    if (!gespeichert) {
      return;
    }
    _draftApSpentDelta = 0;
    _draftInventar = null;
    if (!mounted) {
      return;
    }
    _invalidCombatTalentIds = <String>{};
    _editController.markSaved();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Kampfwerte gespeichert')));
  }

  Future<void> _cancelChanges() async {
    await _discardChanges();
  }

  Future<void> _discardChanges() async {
    _temporaryIniRoll = null;
    final hero = _latestHero;
    if (hero != null) {
      _editController.clearSyncSignature();
      _syncDraftFromHero(hero, force: true);
    }
    _invalidCombatTalentIds = <String>{};
    _editController.markDiscarded();
  }

  HeroTalentEntry _entryForTalent(String talentId) {
    return _draftTalents[talentId] ?? const HeroTalentEntry();
  }

  TextEditingController _controllerFor(String key, String initialValue) {
    return _controllers.putIfAbsent(
      key,
      () => TextEditingController(text: initialValue),
    );
  }

  int _maxIniRollForConfig(CombatConfig config) {
    return config.specialRules.klingentaenzer ? 12 : 6;
  }

  int _effectiveIniRollForConfig(CombatConfig config) {
    final maxRoll = _maxIniRollForConfig(config);
    if (config.specialRules.aufmerksamkeit) {
      return maxRoll;
    }
    final raw = _temporaryIniRoll ?? 0;
    if (raw < 0) {
      return 0;
    }
    if (raw > maxRoll) {
      return maxRoll;
    }
    return raw;
  }

  void _setTemporaryIniRoll(int value) {
    final maxRoll = _maxIniRollForConfig(_draftCombatConfig);
    final clamped = value < 0 ? 0 : (value > maxRoll ? maxRoll : value);
    _temporaryIniRoll = clamped;
    if (mounted) {
      _viewRevision.value++;
    }
  }

  void _updateIntField(String talentId, String field, String raw) {
    final parsed = int.tryParse(raw.trim()) ?? 0;
    final current = _entryForTalent(talentId);
    final updated = switch (field) {
      'talentValue' => current.copyWith(talentValue: parsed),
      'atValue' => current.copyWith(atValue: parsed),
      'paValue' => current.copyWith(paValue: parsed),
      _ => current,
    };
    _draftTalents[talentId] = updated;
    _invalidCombatTalentIds.remove(talentId);
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

  /// Noch verfuegbare AP unter Beruecksichtigung der im Draft vorgemerkten,
  /// aber noch nicht gespeicherten Erwerbskosten.
  int _verfuegbareApImDraft(HeroSheet hero) {
    final rest = hero.apAvailable - _draftApSpentDelta;
    return rest < 0 ? 0 : rest;
  }

  void _markFieldChanged() {
    if (!mounted) {
      return;
    }
    _viewRevision.value++;
    _editController.markFieldChanged();
  }

  String _fallback(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '-';
    }
    return trimmed;
  }

  List<String> _splitSpecializationTokens(String raw) {
    return _normalizeStringList(raw.split(RegExp(r'[\n,;]+')));
  }

  List<String> _weaponCategoryOptions(TalentDef talent) {
    return _normalizeStringList(
      talent.weaponCategory.split(RegExp(r'[\n,;]+')),
    );
  }

  List<String> _normalizeStringList(Iterable<dynamic> values) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final value in values) {
      final trimmed = value.toString().trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) {
        continue;
      }
      seen.add(trimmed);
      normalized.add(trimmed);
    }
    return List<String>.unmodifiable(normalized);
  }

  String _normalizeToken(String raw) {
    var value = raw.trim().toLowerCase();
    value = value
        .replaceAll(String.fromCharCode(228), 'ae')
        .replaceAll(String.fromCharCode(246), 'oe')
        .replaceAll(String.fromCharCode(252), 'ue')
        .replaceAll(String.fromCharCode(223), 'ss');
    return value.replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }
}
