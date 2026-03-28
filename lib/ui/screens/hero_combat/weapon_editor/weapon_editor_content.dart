part of 'package:dsa_heldenverwaltung/ui/screens/hero_combat/weapon_editor_screen.dart';

extension _WeaponEditorContent on WeaponEditorScreenState {
  Widget _buildScreen(BuildContext context) {
    final weaponTypeOptions = weaponTypeOptionsForCatalogWeapons(
      widget.catalogWeapons,
      _draftWeapon,
    );
    final currentWeaponType = _draftWeapon.weaponType.trim();
    final talentOptions = talentOptionsForWeaponType(
      weaponType: currentWeaponType,
      draftWeapon: _draftWeapon,
      combatTalents: widget.combatTalents,
      catalogWeapons: widget.catalogWeapons,
    );
    final selectedTalentId =
        isTalentValidForWeaponType(
          talentId: _draftWeapon.talentId,
          weaponType: currentWeaponType,
          draftWeapon: _draftWeapon,
          combatTalents: widget.combatTalents,
          catalogWeapons: widget.catalogWeapons,
        )
        ? _draftWeapon.talentId.trim()
        : '';
    final previewWeapon = selectedTalentId == _draftWeapon.talentId.trim()
        ? _draftWeapon.copyWith(rangedProfile: _rangedProfileFromControllers())
        : _draftWeapon.copyWith(
            talentId: '',
            rangedProfile: _rangedProfileFromControllers(),
          );
    final preview = widget.previewBuilder(previewWeapon);
    final content = Column(
      children: [
        if (!widget.showAppBar) _header(context),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_validationErrors.isNotEmpty) _errorBox(context),
                WeaponBasicInfoSection(
                  nameController: _nameController,
                  artifactDescriptionController: _artifactDescriptionController,
                  distanceClassController: _distanceClassController,
                  combatType: _draftWeapon.combatType,
                  weaponType: currentWeaponType,
                  isOneHanded: _draftWeapon.isOneHanded,
                  isArtifact: _draftWeapon.isArtifact,
                  weaponTypeOptions: weaponTypeOptions,
                  talentOptions: talentOptions,
                  selectedTalentId: selectedTalentId,
                  onNameChanged: (value) =>
                      _setDraftWeapon(_draftWeapon.copyWith(name: value)),
                  onCombatTypeChanged: (value) => _setDraftWeapon(
                    _draftWeapon.copyWith(
                      combatType: value,
                      talentId: '',
                      weaponType: '',
                    ),
                  ),
                  onWeaponTypeChanged: (value) {
                    final nextTalentId =
                        isTalentValidForWeaponType(
                          talentId: _draftWeapon.talentId,
                          weaponType: value,
                          draftWeapon: _draftWeapon,
                          combatTalents: widget.combatTalents,
                          catalogWeapons: widget.catalogWeapons,
                        )
                        ? _draftWeapon.talentId
                        : '';
                    final nextName =
                        _draftWeapon.name.trim().isEmpty && value.isNotEmpty
                        ? value
                        : _draftWeapon.name;
                    if (_draftWeapon.name.trim().isEmpty &&
                        nextName.isNotEmpty &&
                        _nameController.text.trim().isEmpty) {
                      _nameController.text = nextName;
                    }
                    _setDraftWeapon(
                      _draftWeapon.copyWith(
                        weaponType: value,
                        talentId: nextTalentId,
                        name: nextName,
                      ),
                    );
                  },
                  onDistanceClassChanged: (value) => _setDraftWeapon(
                    _draftWeapon.copyWith(distanceClass: value),
                  ),
                  onTalentChanged: (value) =>
                      _setDraftWeapon(_draftWeapon.copyWith(talentId: value)),
                  onOneHandedChanged: (value) => _setDraftWeapon(
                    _draftWeapon.copyWith(isOneHanded: value),
                  ),
                  onArtifactChanged: (value) =>
                      _setDraftWeapon(_draftWeapon.copyWith(isArtifact: value)),
                  onArtifactDescriptionChanged: (value) => _setDraftWeapon(
                    _draftWeapon.copyWith(artifactDescription: value),
                  ),
                ),
                const SizedBox(height: 12),
                WeaponDamageSection(
                  tpDiceCountController: _tpDiceCountController,
                  tpFlatController: _tpFlatController,
                  kkBaseController: _kkBaseController,
                  kkThresholdController: _kkThresholdController,
                  onTpDiceCountChanged: (value) => _setDraftWeapon(
                    _draftWeapon.copyWith(tpDiceCount: value < 1 ? 1 : value),
                  ),
                  onTpFlatChanged: (value) =>
                      _setDraftWeapon(_draftWeapon.copyWith(tpFlat: value)),
                  onKkBaseChanged: (value) =>
                      _setDraftWeapon(_draftWeapon.copyWith(kkBase: value)),
                  onKkThresholdChanged: (value) => _setDraftWeapon(
                    _draftWeapon.copyWith(kkThreshold: value < 1 ? 1 : value),
                  ),
                ),
                const SizedBox(height: 12),
                WeaponModifiersSection(
                  combatType: _draftWeapon.combatType,
                  breakFactorController: _breakFactorController,
                  iniModController: _iniModController,
                  wmAtController: _wmAtController,
                  wmPaController: _wmPaController,
                  beTalentModController: _beTalentModController,
                  onBreakFactorChanged: (value) => _setDraftWeapon(
                    _draftWeapon.copyWith(breakFactor: value < 0 ? 0 : value),
                  ),
                  onIniModChanged: (value) =>
                      _setDraftWeapon(_draftWeapon.copyWith(iniMod: value)),
                  onWmAtChanged: (value) =>
                      _setDraftWeapon(_draftWeapon.copyWith(wmAt: value)),
                  onWmPaChanged: (value) =>
                      _setDraftWeapon(_draftWeapon.copyWith(wmPa: value)),
                  onBeTalentModChanged: (value) => _setDraftWeapon(
                    _draftWeapon.copyWith(beTalentMod: value),
                  ),
                ),
                if (_draftWeapon.isRanged) ...[
                  const SizedBox(height: 12),
                  WeaponRangedSection(
                    reloadTimeController: _reloadTimeController,
                    distanceLabelControllers: _distanceLabelControllers,
                    distanceTpModControllers: _distanceTpModControllers,
                    projectiles: _draftWeapon.rangedProfile.projectiles,
                    onReloadTimeChanged: (value) => _setDraftWeapon(
                      _draftWeapon.copyWith(
                        rangedProfile: _rangedProfileFromControllers().copyWith(
                          reloadTime: value < 0 ? 0 : value,
                        ),
                      ),
                    ),
                    onDistanceChanged: () => _setDraftWeapon(
                      _draftWeapon.copyWith(
                        rangedProfile: _rangedProfileFromControllers(),
                      ),
                    ),
                    onAddProjectile: _openProjectileEditor,
                    onEditProjectile: (index) =>
                        _openProjectileEditor(projectileIndex: index),
                    onRemoveProjectile: _removeProjectile,
                  ),
                ],
                const SizedBox(height: 12),
                WeaponPreviewSection(preview: preview),
              ],
            ),
          ),
        ),
        _actions(),
      ],
    );

    if (!widget.showAppBar) {
      return Material(child: content);
    }
    return PopScope<MainWeaponSlot>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        await requestClose();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isNew ? 'Waffe hinzufügen' : 'Waffe bearbeiten'),
        ),
        body: content,
      ),
    );
  }

  Widget _header(BuildContext context) {
    final title = widget.isNew ? 'Waffe hinzufügen' : 'Waffe bearbeiten';
    final template = widget.catalogWeaponName?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                if (template.isNotEmpty)
                  Text(
                    'Vorlage: $template',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey<String>('combat-weapon-panel-close'),
            onPressed: requestClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: requestClose, child: const Text('Abbrechen')),
            const SizedBox(width: 8),
            FilledButton(
              key: const ValueKey<String>('combat-weapon-form-save'),
              onPressed: _save,
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBox(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _validationErrors
            .map(
              (error) =>
                  Text(error, style: Theme.of(context).textTheme.bodyMedium),
            )
            .toList(growable: false),
      ),
    );
  }
}
