part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat_tab.dart';

/// Entkoppelt Draft-State, Persistenz und Validierung vom Tab-Root.
extension _CombatStateHelpers on _HeroCombatTabState {
  /// Einziger Schreibweg der Bedienelemente im Kampf-Tab.
  ///
  /// Im Bearbeitungsmodus ändert [aenderung] nur den Entwurf; gespeichert
  /// wird mit „Speichern“. Sonst trifft sie frisch die **gespeicherte**
  /// Kampfkonfiguration (ARCH-05): Ein beim Rendern erfasster Stand wird nie
  /// zurückgeschrieben, Änderungen desselben Helden laufen nacheinander, und
  /// die Anzeige folgt dem gespeicherten Wert. Die Slotprüfung läuft auf dem
  /// frischen Ergebnis. Fehler erscheinen als „[was] nicht gespeichert“;
  /// die Bedienelemente springen dann auf den gespeicherten Stand zurück.
  /// Liefert, ob die Änderung übernommen wurde.
  Future<bool> _aendereKampf({
    required String was,
    required CombatConfig Function(CombatConfig aktuell) aenderung,
    required RulesCatalog catalog,
  }) async {
    if (_editController.isEditing) {
      return _aendereKampfEntwurf(was: was, aenderung: aenderung);
    }
    final combatTalents = catalog.talents
        .where(isCombatTalentDef)
        .toList(growable: false);
    final gespeichert = await aendereHeldMitMeldung(
      context: context,
      ref: ref,
      heroId: widget.heroId,
      was: was,
      aenderung: (held) => mitKampfAenderung(held, (config) {
        final neu = aenderung(config);
        final fehler = _validateWeaponSlotsForConfig(
          config: neu,
          catalog: catalog,
          combatTalents: combatTalents,
        );
        if (fehler != null) {
          throw StateError(fehler);
        }
        return neu;
      }),
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
    required CombatConfig Function(CombatConfig aktuell) aenderung,
  }) {
    try {
      _draftCombatConfig = aenderung(_draftCombatConfig);
    } on StateError catch (fehler) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('$was nicht übernommen: ${fehler.message}')),
      );
      return false;
    }
    _markFieldChanged();
    return true;
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
    final basis = _entwurfBasis;
    if (basis == null) {
      return;
    }

    final catalog = await ref.read(rulesCatalogProvider.future);
    final combatTalents = sortedCombatTalents(
      catalog.talents.where(isCombatTalentDef).toList(growable: false),
    );
    final weaponValidation = _validateWeaponSlots(
      catalog: catalog,
      combatTalents: combatTalents,
    );
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

  String? _validateWeaponSlotsForConfig({
    required CombatConfig config,
    required RulesCatalog catalog,
    required List<TalentDef> combatTalents,
  }) {
    final talentById = <String, TalentDef>{
      for (final talent in combatTalents) talent.id: talent,
    };
    final slots = config.weaponSlots;
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final slotLabel = 'Waffe ${i + 1}';
      final hasAnyData =
          slot.name.trim().isNotEmpty ||
          slot.talentId.trim().isNotEmpty ||
          slot.weaponType.trim().isNotEmpty;
      if (!hasAnyData) {
        continue;
      }
      final talentId = slot.talentId.trim();
      final talent = talentId.isEmpty ? null : talentById[talentId];
      if (talentId.isNotEmpty && talent == null) {
        return '$slotLabel: Das gewählte Talent ist kein gültiges Kampftalent.';
      }
      if (talent != null && combatTypeFromTalent(talent) != slot.combatType) {
        return '$slotLabel: Talent "${talent.name}" passt nicht zum Waffenkampftyp.';
      }
      final weaponType = slot.weaponType.trim();
      if (weaponType.isNotEmpty && talent != null) {
        final allowedTypes = weaponTypeOptionsForTalent(
          talent: talent,
          catalog: catalog,
          combatType: slot.combatType,
        );
        if (!allowedTypes.contains(weaponType)) {
          return '$slotLabel: Waffenart "$weaponType" passt nicht zum Talent "${talent.name}".';
        }
      }
      if (weaponType.isNotEmpty && talent == null) {
        return '$slotLabel: Waffenart "$weaponType" benötigt ein gültiges Talent.';
      }
      if (slot.kkThreshold < 0) {
        return '$slotLabel: KK-Schwelle darf nicht negativ sein.';
      }
      if (slot.kkThreshold == 0 && slot.kkBase != 0) {
        return '$slotLabel: TP/KK darf nur als 0/0 deaktiviert werden.';
      }
      if (slot.tpDiceCount < 1) {
        return '$slotLabel: Würfelanzahl muss >= 1 sein.';
      }
      if (slot.isRanged && slot.rangedProfile.reloadTime < 0) {
        return '$slotLabel: Ladezeit darf nicht negativ sein.';
      }
      if (slot.isRanged) {
        for (final projectile in slot.rangedProfile.projectiles) {
          if (projectile.count < 0) {
            return '$slotLabel: Geschossbestände dürfen nicht negativ sein.';
          }
        }
      }
    }
    final assignment = config.offhandAssignment;
    if (assignment.weaponIndex >= 0 &&
        assignment.weaponIndex == config.selectedWeaponIndex) {
      return 'Nebenhand: Haupthand und Nebenhand dürfen nicht dieselbe Waffe nutzen.';
    }
    if (assignment.usesEquipment &&
        assignment.equipmentIndex >= 0 &&
        assignment.equipmentIndex < config.offhandEquipment.length) {
      final offhandEntry = config.offhandEquipment[assignment.equipmentIndex];
      if (offhandEntry.type == OffhandEquipmentType.parryWeapon &&
          !config.specialRules.linkhandActive) {
        return 'Nebenhand: Parierwaffen erfordern die Sonderfertigkeit Linkhand.';
      }
      if (offhandEntry.breakFactor < 0) {
        return 'Nebenhand: BF darf nicht negativ sein.';
      }
    }
    return null;
  }

  String? _validateWeaponSlots({
    required RulesCatalog catalog,
    required List<TalentDef> combatTalents,
  }) {
    return _validateWeaponSlotsForConfig(
      config: _draftCombatConfig,
      catalog: catalog,
      combatTalents: combatTalents,
    );
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
