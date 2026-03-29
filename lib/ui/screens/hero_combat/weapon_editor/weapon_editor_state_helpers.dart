part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat/weapon_editor_screen.dart';

extension _WeaponEditorStateHelpers on WeaponEditorScreenState {
  /// Fragt den Nutzer bei ungespeicherten Aenderungen vor dem Schliessen.
  Future<bool> _requestClose() async {
    if (!_hasUnsavedChanges) {
      _closeWithoutSaving();
      return true;
    }

    final result = await showWorkspaceDiscardDialog(context);
    if (!mounted || result == AdaptiveConfirmResult.cancel) {
      return false;
    }
    if (result == AdaptiveConfirmResult.save) {
      return _save();
    }
    _closeWithoutSaving();
    return true;
  }

  int _readInt(TextEditingController controller, int fallback) {
    return int.tryParse(controller.text.trim()) ?? fallback;
  }

  RangedWeaponProfile _rangedProfileFromControllers() {
    final fallback = _draftWeapon.rangedProfile.copyWith().distanceBands;
    return _draftWeapon.rangedProfile.copyWith(
      reloadTime: _readInt(
        _reloadTimeController,
        _draftWeapon.rangedProfile.reloadTime,
      ),
      distanceBands: <RangedDistanceBand>[
        for (var i = 0; i < 5; i++)
          RangedDistanceBand(
            label: _distanceLabelControllers[i].text.trim().isEmpty
                ? fallback[i].label
                : _distanceLabelControllers[i].text.trim(),
            tpMod: _readInt(_distanceTpModControllers[i], fallback[i].tpMod),
          ),
      ],
    );
  }

  Future<void> _openProjectileEditor({int? projectileIndex}) async {
    final projectiles = _draftWeapon.rangedProfile.projectiles;
    final source = projectileIndex == null
        ? const RangedProjectile()
        : projectiles[projectileIndex];
    final result = await showAdaptiveDetailSheet<RangedProjectile>(
      context: context,
      builder: (context) => RangedProjectileEditorDialog(
        initialProjectile: source,
        isNew: projectileIndex == null,
      ),
    );
    if (result == null) {
      return;
    }
    final updated = List<RangedProjectile>.from(projectiles);
    if (projectileIndex == null) {
      updated.add(result);
    } else {
      updated[projectileIndex] = result;
    }
    _setDraftWeapon(
      _draftWeapon.copyWith(
        rangedProfile: _rangedProfileFromControllers().copyWith(
          projectiles: updated,
          selectedProjectileIndex: updated.isEmpty
              ? -1
              : (projectileIndex ?? updated.length - 1),
        ),
      ),
    );
  }

  void _removeProjectile(int index) {
    final updated = List<RangedProjectile>.from(
      _draftWeapon.rangedProfile.projectiles,
    );
    if (index < 0 || index >= updated.length) {
      return;
    }
    updated.removeAt(index);
    _setDraftWeapon(
      _draftWeapon.copyWith(
        rangedProfile: _rangedProfileFromControllers().copyWith(
          projectiles: updated,
          selectedProjectileIndex: updated.isEmpty ? -1 : 0,
        ),
      ),
    );
  }

  MainWeaponSlot _normalizedWeapon() {
    final weaponType = _draftWeapon.weaponType.trim();
    final normalizedTalentId =
        isTalentValidForWeaponType(
          talentId: _draftWeapon.talentId,
          weaponType: weaponType,
          draftWeapon: _draftWeapon,
          combatTalents: widget.combatTalents,
          catalogWeapons: widget.catalogWeapons,
        )
        ? _draftWeapon.talentId.trim()
        : '';
    return _draftWeapon.copyWith(
      name: _nameController.text.trim(),
      weaponType: weaponType,
      talentId: normalizedTalentId,
      distanceClass: _distanceClassController.text.trim(),
      breakFactor: _readInt(
        _breakFactorController,
        _draftWeapon.breakFactor,
      ).clamp(0, 9999),
      kkBase: _readInt(_kkBaseController, _draftWeapon.kkBase),
      kkThreshold: _readInt(_kkThresholdController, _draftWeapon.kkThreshold),
      iniMod: _readInt(_iniModController, _draftWeapon.iniMod),
      wmAt: _readInt(_wmAtController, _draftWeapon.wmAt),
      wmPa: _readInt(_wmPaController, _draftWeapon.wmPa),
      beTalentMod: _readInt(_beTalentModController, _draftWeapon.beTalentMod),
      tpDiceCount:
          _readInt(_tpDiceCountController, _draftWeapon.tpDiceCount) < 1
          ? 1
          : _readInt(_tpDiceCountController, _draftWeapon.tpDiceCount),
      tpFlat: _readInt(_tpFlatController, _draftWeapon.tpFlat),
      artifactDescription: _artifactDescriptionController.text.trim(),
      rangedProfile: _rangedProfileFromControllers(),
    );
  }

  Future<bool> _save() async {
    final normalized = _normalizedWeapon();
    final errors = validateWeaponSlot(normalized);
    if (errors.isNotEmpty) {
      _setValidationErrors(errors);
      return false;
    }
    if (widget.onSaved != null) {
      widget.onSaved!(normalized);
    } else if (mounted) {
      Navigator.of(context).pop(normalized);
    }
    _hasUnsavedChanges = false;
    return true;
  }

  void _closeWithoutSaving() {
    if (widget.onCancel != null) {
      widget.onCancel!();
      return;
    }
    Navigator.of(context).pop();
  }
}
